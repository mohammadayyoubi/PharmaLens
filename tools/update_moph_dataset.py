"""Checks the MOPH website for a newer Drugs Public Price List and rebuilds the
app's medicine CSV when there is one.

Run by .github/workflows/update-moph-prices.yml every 6 hours; it can also be
run by hand:

  pip install xlrd
  python tools/update_moph_dataset.py           # only rebuilds when MOPH has a newer sheet
  python tools/update_moph_dataset.py --force   # rebuild anyway

Writes, next to the CSV, lebanon_medicine_prices.json: a small manifest the app
downloads first to find out whether the CSV changed. The CSV is only replaced
when the new build passes sanity checks, so a broken MOPH file can never reach
users.
"""

import argparse
import csv
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CSV_PATH = os.path.join(ROOT, "assets", "medicines", "lebanon_medicine_prices.csv")
MANIFEST_PATH = os.path.join(ROOT, "assets", "medicines", "lebanon_medicine_prices.json")
PRICE_LIST_URL = "https://www.moph.gov.lb/en/Pages/3/3101/drugs-public-price-list"
USER_AGENT = "Mozilla/5.0 (PharmaLens price list updater)"

# e.g. .../5-10-2026/WebMarketed20261005-19-10-2026.xls
#      list date 2026-10-05, revised on 19-10-2026
SHEET_LINK = re.compile(
    r'href="(?P<href>[^"]*?WebMarketed(?P<list>\d{8})(?:-(?P<d>\d{1,2})-(?P<m>\d{1,2})-(?P<y>\d{4}))?\.xlsx?)"',
    re.I,
)


def http_get(url, timeout=120):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def latest_sheet():
    """Newest 'marketed drugs' sheet linked from the MOPH price list page."""
    page = http_get(PRICE_LIST_URL).decode("utf-8", errors="replace")
    sheets = []
    for match in SHEET_LINK.finditer(page):
        listed = datetime.datetime.strptime(match["list"], "%Y%m%d").date()
        revised = (
            datetime.date(int(match["y"]), int(match["m"]), int(match["d"]))
            if match["y"]
            else listed
        )
        href = match["href"]
        sheets.append({
            "url": urllib.parse.urljoin(PRICE_LIST_URL, href),
            "file": urllib.parse.unquote(href.rsplit("/", 1)[-1]),
            "list_date": listed.isoformat(),
            "published": max(listed, revised).isoformat(),
        })
    if not sheets:
        raise SystemExit("No WebMarketed sheet found on the MOPH page; the page layout may have changed.")
    return max(sheets, key=lambda s: (s["published"], s["list_date"], s["file"]))


def read_manifest():
    try:
        with open(MANIFEST_PATH, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def summarize(csv_path):
    with open(csv_path, encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    # The app keeps one product per MOPH code; count the same way so it can
    # verify a download against "rows".
    unique = {}
    for index, row in enumerate(rows):
        unique.setdefault(row.get("medicine_id") or f"row{index}", row)
    rows = list(unique.values())
    with_ingredients = sum(1 for row in rows if row.get("active_ingredients"))
    dates = [row["last_updated"] for row in rows if row.get("last_updated")]
    list_date = max(set(dates), key=dates.count) if dates else ""
    return len(rows), with_ingredients, list_date


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def set_output(**values):
    """Passes results to later GitHub Actions steps."""
    target = os.environ.get("GITHUB_OUTPUT")
    for key, value in values.items():
        print(f"{key}={value}")
        if target:
            with open(target, "a", encoding="utf-8") as handle:
                handle.write(f"{key}={value}\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="rebuild even if the sheet did not change")
    parser.add_argument("--delay", type=float, default=1.0, help="seconds between LNDI page requests")
    args = parser.parse_args()

    sheet = latest_sheet()
    current = read_manifest()
    print(f"Newest MOPH sheet: {sheet['file']} (published {sheet['published']})", file=sys.stderr)

    if not args.force and current.get("source_file") == sheet["file"]:
        print("Already up to date.", file=sys.stderr)
        set_output(changed="false", version=current.get("version", ""))
        return

    if not args.force and current.get("published", "") > sheet["published"]:
        print("The app already has a newer list than the MOPH page offers; nothing to do.", file=sys.stderr)
        set_output(changed="false", version=current.get("version", ""))
        return

    work = tempfile.mkdtemp(prefix="moph_")
    try:
        xls_path = os.path.join(work, sheet["file"])
        with open(xls_path, "wb") as handle:
            handle.write(http_get(sheet["url"], timeout=300))

        new_csv = os.path.join(work, "lebanon_medicine_prices.csv")
        # A fresh LNDI cache: the drug index changes too (new registrations).
        subprocess.run(
            [sys.executable, os.path.join(ROOT, "tools", "build_medicine_dataset.py"),
             "--xls", xls_path, "--cache-dir", os.path.join(work, "lndi"),
             "--delay", str(args.delay), "--output", new_csv],
            check=True,
        )

        rows, with_ingredients, list_date = summarize(new_csv)
        previous_rows = int(current.get("rows") or 0)

        # Refuse obviously broken builds rather than shipping them to users.
        problems = []
        if rows < 1000:
            problems.append(f"only {rows} medicines")
        if previous_rows and rows < previous_rows * 0.8:
            problems.append(f"{rows} medicines, down from {previous_rows}")
        if rows and with_ingredients / rows < 0.9:
            problems.append(f"only {with_ingredients}/{rows} medicines have ingredients")
        if problems:
            raise SystemExit("New list rejected: " + "; ".join(problems))

        shutil.copyfile(new_csv, CSV_PATH)
    finally:
        shutil.rmtree(work, ignore_errors=True)

    manifest = {
        "version": f"{sheet['published']}_{os.path.splitext(sheet['file'])[0]}",
        "list_date": list_date or sheet["list_date"],
        "published": sheet["published"],
        "source_file": sheet["file"],
        "source_url": sheet["url"],
        "rows": rows,
        "with_ingredients": with_ingredients,
        "sha256": sha256(CSV_PATH),
        "generated_at": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")

    print(f"Updated to {manifest['version']}: {rows} medicines, {with_ingredients} with ingredients.", file=sys.stderr)
    set_output(changed="true", version=manifest["version"])


if __name__ == "__main__":
    main()
