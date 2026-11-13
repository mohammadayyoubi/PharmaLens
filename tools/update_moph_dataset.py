"""Checks the MOPH website for a newer Drugs Public Price List and rebuilds the
app's medicine CSV when there is one.

Run by .github/workflows/update-moph-prices.yml every 6 hours; it can also be
run by hand:

  pip install xlrd openpyxl
  python tools/update_moph_dataset.py                       # only rebuilds when the sheet changed
  python tools/update_moph_dataset.py --force               # rebuild anyway
  python tools/update_moph_dataset.py --allow-price-jumps   # accept a large repricing

Writes, next to the CSV, lebanon_medicine_prices.json: a small manifest the app
downloads first to find out whether the CSV changed. The CSV is only replaced
when the new build passes sanity checks, so a broken MOPH file can never reach
users.

MOPH names its files by hand, so nothing here depends on one naming pattern:
  - The price sheet is recognized by its file name ("...Marketed...") or by its
    link text ("Drugs Public Price List"), never "Non Marketed".
  - Its date is the newest date found anywhere in its path, in any common
    format (20261111, 11-11-2026, 2026-11-11, 11.11.2026, ...). A sheet whose
    path has no date is dated by the server's Last-Modified header.
  - Whether it changed is decided by its content (SHA-256 of the file), so a
    corrected sheet re-uploaded under the same name is picked up too.
  - If the page announces a newer release (an "Exchange Rate Issued on" heading
    or a dated folder) than the sheet that was found, or has a spreadsheet it
    cannot classify that may be newer, the run fails instead of reporting "up
    to date", so GitHub notifies the maintainer.

The manifest always moves forward for the app: a rebuilt list gets a
`published` date no older than the current one and a new `version`, which is
all that installed apps compare (MophDatasetManifest.isNewerThan).
"""

import argparse
import csv
import datetime
import email.utils
import hashlib
import html
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

# Every spreadsheet link on the page, with its text.
SPREADSHEET_LINK = re.compile(
    r'<a\b[^>]*?\bhref="(?P<href>[^"]+?\.xlsx?(?:\?[^"]*)?)"[^>]*>(?P<text>.*?)</a>',
    re.I | re.S,
)
# Section headings: "Drugs Prices According to the Exchange Rate Issued on 11/11/2026"
RELEASE_HEADING = re.compile(
    r"Exchange\s+Rate\s+Issued\s+on\s+(?P<d>\d{1,2})\s*[/.-]\s*(?P<m>\d{1,2})\s*[/.-]\s*(?P<y>\d{4})",
    re.I,
)
# Each release gets its own folder, e.g. .../DrugsPublicPriceList/11-11-2026/
RELEASE_FOLDER = re.compile(
    r"DrugsPublicPriceList/(?P<d>\d{1,2})[-._](?P<m>\d{1,2})[-._](?P<y>\d{4})/", re.I
)
# Dates in a file path, in the orders MOPH has used or plausibly could.
PATH_DATES = (
    re.compile(r"(?<!\d)(?P<y>20\d{2})(?P<m>\d{2})(?P<d>\d{2})(?!\d)"),                     # 20261111
    re.compile(r"(?<!\d)(?P<y>20\d{2})[-._ ](?P<m>\d{1,2})[-._ ](?P<d>\d{1,2})(?!\d)"),      # 2026-11-11
    re.compile(r"(?<!\d)(?P<d>\d{1,2})[-._ ](?P<m>\d{1,2})[-._ ](?P<y>20\d{2})(?!\d)"),      # 11-11-2026
)
OLDEST_PLAUSIBLE = datetime.date(2015, 1, 1)
EPOCH = datetime.datetime(1970, 1, 1, tzinfo=datetime.timezone.utc)


def http_get(url, timeout=120):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def http_head(url):
    """Upload time and size the server reports for a file; empty when unknown."""
    request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            modified = response.headers.get("Last-Modified")
            size = response.headers.get("Content-Length")
    except Exception as error:  # a HEAD failure only loses a hint
        print(f"HEAD {url} failed: {error}", file=sys.stderr)
        return {}
    info = {}
    try:
        if modified:
            info["last_modified"] = email.utils.parsedate_to_datetime(modified).astimezone(datetime.timezone.utc)
    except (TypeError, ValueError):
        pass
    if size and size.isdigit():
        info["size"] = int(size)
    return info


def make_date(match, today):
    try:
        date = datetime.date(int(match["y"]), int(match["m"]), int(match["d"]))
    except ValueError:
        return None
    return date if OLDEST_PLAUSIBLE <= date <= today + datetime.timedelta(days=1) else None


def path_dates(url, today):
    path = urllib.parse.unquote(urllib.parse.urlparse(url).path)
    dates = set()
    for pattern in PATH_DATES:
        for match in pattern.finditer(path):
            date = make_date(match, today)
            if date:
                dates.add(date)
    return dates


def link_text(raw):
    text = html.unescape(re.sub(r"<[^>]+>", " ", raw)).replace("​", "")
    return " ".join(text.split()).lower()


def classify(file_name, text):
    """marketed (the price list), non_marketed, primary or unknown."""
    name = file_name.lower()
    if re.search(r"non[\s_-]*marketed", name) or re.search(r"\bnon[\s_-]*marketed", text):
        return "non_marketed"
    if "marketed" in name or "drugs public price list" in text:
        return "marketed"
    if "primary" in name or "primary registration" in text:
        return "primary"
    return "unknown"


def find_sheet(page, head=http_head, today=None):
    """Newest marketed-drugs price sheet linked from the MOPH page."""
    today = today or datetime.date.today()
    links, seen = [], set()
    for order, match in enumerate(SPREADSHEET_LINK.finditer(page)):
        url = urllib.parse.urljoin(PRICE_LIST_URL, html.unescape(match["href"]))
        if url in seen:
            continue
        seen.add(url)
        file_name = urllib.parse.unquote(urllib.parse.urlparse(url).path.rsplit("/", 1)[-1])
        links.append({
            "url": url,
            "file": file_name,
            "kind": classify(file_name, link_text(match["text"])),
            "dates": path_dates(url, today),
            "order": order,
        })

    heads = {}

    def server_info(link):
        if link["url"] not in heads:
            heads[link["url"]] = head(link["url"])
        return heads[link["url"]]

    def release_date(link):
        if link["dates"]:
            return max(link["dates"])
        modified = server_info(link).get("last_modified")
        return modified.date() if modified else None

    sheets = [link for link in links if link["kind"] == "marketed"]
    for sheet in sheets:
        sheet["release"] = release_date(sheet)
    dated = [sheet for sheet in sheets if sheet["release"]]
    if not dated:
        raise SystemExit(
            "No Drugs Public Price List sheet found on the MOPH page "
            f"({len(links)} spreadsheet links). The page layout may have changed: {PRICE_LIST_URL}"
        )

    newest = max(sheet["release"] for sheet in dated)
    tied = [sheet for sheet in dated if sheet["release"] == newest]
    # Same date (e.g. a corrected copy without a revision date in its name):
    # the later upload wins, then the one listed first (the page is newest first).
    tied.sort(key=lambda s: (-(server_info(s).get("last_modified") or EPOCH).timestamp(), s["order"]))
    chosen = tied[0]
    info = server_info(chosen)
    modified = info.get("last_modified")
    seen_on = max(chosen["release"], modified.date()) if modified else chosen["release"]

    # The page says a newer release exists than the sheet we found: the sheet
    # is probably named or labeled in a way this script does not recognize.
    announced = [
        date
        for pattern in (RELEASE_HEADING, RELEASE_FOLDER)
        for date in (make_date(m, today) for m in pattern.finditer(page))
        if date
    ]
    if announced and max(announced) > chosen["release"]:
        raise SystemExit(
            f"The MOPH page announces a release dated {max(announced).isoformat()}, but the newest "
            f"price sheet found is {chosen['file']} ({chosen['release'].isoformat()}). The new sheet is probably "
            "named or labeled differently (or not uploaded yet); check the page and update "
            f"classify() in tools/update_moph_dataset.py if needed: {PRICE_LIST_URL}"
        )

    # A spreadsheet we cannot classify that may be newer than our pick.
    suspicious = []
    for link in links:
        if link["kind"] != "unknown":
            continue
        date = release_date(link)
        if date is None or date > chosen["release"]:
            suspicious.append(f"{link['file']} ({date.isoformat() if date else 'no date'})")
    if suspicious:
        raise SystemExit(
            "The MOPH page has spreadsheets this script cannot classify that may be newer than "
            f"{chosen['file']} ({chosen['release'].isoformat()}): {', '.join(suspicious)}. "
            "Check which one is the Drugs Public Price List and update classify() if needed."
        )

    all_dates = chosen["dates"] or {chosen["release"]}
    return {
        "url": chosen["url"],
        "file": chosen["file"],
        "list_date": min(all_dates).isoformat(),
        "published": seen_on.isoformat(),
        "last_modified": modified.isoformat() if modified else "",
        "size": info.get("size", 0),
    }


def latest_sheet():
    page = http_get(PRICE_LIST_URL).decode("utf-8", errors="replace")
    return find_sheet(page)


def read_manifest():
    try:
        with open(MANIFEST_PATH, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def write_manifest(manifest):
    with open(MANIFEST_PATH, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")


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


def price_problems(old_path, new_path):
    """A column shift or a broken sheet shows up as many prices changing by a
    large factor at once. Real repricings move a minority of products."""
    def prices(path):
        try:
            with open(path, encoding="utf-8", newline="") as handle:
                return {
                    row["medicine_id"]: float(row["official_price_lbp"])
                    for row in csv.DictReader(handle)
                    if row.get("medicine_id") and (row.get("official_price_lbp") or "").replace(".", "", 1).isdigit()
                }
        except OSError:
            return {}

    old, new = prices(old_path), prices(new_path)
    common = [code for code in new if code in old and old[code] > 0 and new[code] > 0]
    if len(common) < 500:
        return []
    jumps = sum(1 for code in common if not (1 / 3 <= new[code] / old[code] <= 3))
    if jumps / len(common) > 0.15:
        return [f"{jumps} of {len(common)} prices changed more than threefold "
                "(if MOPH really repriced, rerun with --allow-price-jumps)"]
    return []


def read_normalized(path):
    """File text with line endings unified, or None if it does not exist."""
    try:
        with open(path, encoding="utf-8", newline="") as handle:
            return handle.read().replace("\r\n", "\n")
    except OSError:
        return None


def sha256_file(path):
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


def unchanged(current, message):
    print(message, file=sys.stderr)
    set_output(changed="false", version=current.get("version", ""), message="")


def source_fields(sheet, source_sha256):
    return {
        "source_file": sheet["file"],
        "source_url": sheet["url"],
        "source_sha256": source_sha256,
        "source_last_modified": sheet["last_modified"],
        "source_size": sheet["size"],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="rebuild even if the sheet did not change")
    parser.add_argument("--allow-price-jumps", action="store_true",
                        help="accept a list where many prices changed more than threefold")
    parser.add_argument("--delay", type=float, default=1.0, help="seconds between LNDI page requests")
    args = parser.parse_args()

    sheet = latest_sheet()
    current = read_manifest()
    print(f"Newest MOPH sheet: {sheet['file']} (published {sheet['published']}, "
          f"uploaded {sheet['last_modified'] or 'unknown'})", file=sys.stderr)

    if not args.force and sheet["published"] < current.get("published", ""):
        # e.g. MOPH withdrew its newest sheet. Never move users back silently.
        print(f"::warning::The newest sheet on the MOPH page ({sheet['file']}, {sheet['published']}) is older "
              f"than the app's list ({current.get('version')}); nothing was changed.", file=sys.stderr)
        set_output(changed="false", version=current.get("version", ""), message="")
        return

    # Cheap check first: the same file at the same upload time and size.
    if (not args.force and current.get("source_sha256") and current.get("source_url") == sheet["url"]
            and sheet["last_modified"] and current.get("source_last_modified") == sheet["last_modified"]
            and sheet["size"] and current.get("source_size") == sheet["size"]):
        unchanged(current, "Already up to date (same file, upload time and size).")
        return

    work = tempfile.mkdtemp(prefix="moph_")
    try:
        sheet_path = os.path.join(work, re.sub(r"[^\w.-]+", "_", sheet["file"]) or "sheet.xls")
        with open(sheet_path, "wb") as handle:
            handle.write(http_get(sheet["url"], timeout=300))
        source_sha256 = sha256_file(sheet_path)

        if not args.force and current.get("source_sha256") == source_sha256:
            unchanged(current, "Already up to date (the sheet's content has not changed).")
            return

        new_csv = os.path.join(work, "lebanon_medicine_prices.csv")
        # A fresh LNDI cache: the drug index changes too (new registrations).
        subprocess.run(
            [sys.executable, os.path.join(ROOT, "tools", "build_medicine_dataset.py"),
             "--xls", sheet_path, "--cache-dir", os.path.join(work, "lndi"),
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
        if not args.allow_price_jumps:
            problems += price_problems(CSV_PATH, new_csv)
        if problems:
            raise SystemExit("New list rejected: " + "; ".join(problems))

        if read_normalized(new_csv) == read_normalized(CSV_PATH):
            # Same prices (e.g. a re-upload of an identical sheet). Phones have
            # nothing to download; only remember the file so it is not rebuilt
            # on every run. version/published stay, so apps ignore the change.
            if current.get("source_sha256") == source_sha256:
                unchanged(current, "The rebuilt list is identical to the current one; nothing to commit.")
                return
            current.update(source_fields(sheet, source_sha256))
            write_manifest(current)
            print("The rebuilt list is identical; recorded the sheet's fingerprint only.", file=sys.stderr)
            set_output(changed="true", version=current.get("version", ""),
                       message=f"data: record MOPH sheet fingerprint ({sheet['file']})")
            return

        shutil.copyfile(new_csv, CSV_PATH)
    finally:
        shutil.rmtree(work, ignore_errors=True)

    csv_sha256 = sha256_file(CSV_PATH)
    # Installed apps take a manifest when its `published` is later, or equal
    # with a different version and a later generated_at. Never go backwards,
    # and make the version unique to this content.
    published = max(sheet["published"], current.get("published", ""))
    stem = re.sub(r"[^A-Za-z0-9._-]+", "_", os.path.splitext(sheet["file"])[0]).strip("_-.") or "sheet"
    manifest = {
        "version": f"{published}_{stem}_{csv_sha256[:8]}",
        "list_date": list_date or sheet["list_date"],
        "published": published,
        "rows": rows,
        "with_ingredients": with_ingredients,
        "sha256": csv_sha256,
        "generated_at": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
        **source_fields(sheet, source_sha256),
    }
    write_manifest(manifest)

    print(f"Updated to {manifest['version']}: {rows} medicines, {with_ingredients} with ingredients.", file=sys.stderr)
    set_output(changed="true", version=manifest["version"], message=f"data: MOPH price list {manifest['version']}")


if __name__ == "__main__":
    main()
