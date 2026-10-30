"""Builds assets/medicines/lebanon_medicine_prices.csv from official MOPH sources.

Sources (both published by the Lebanese Ministry of Public Health):
  1. Drugs Public Price List (XLS) - code, registration, brand, strength,
     presentation, form, agent, manufacturer, country, public price.
     https://www.moph.gov.lb/en/Pages/3/3101/drugs-public-price-list
  2. Lebanon National Drug Index (LNDI) - ATC code and active ingredients,
     which the price list does not contain.
     https://www.moph.gov.lb/en/Drugs/index/3/4848/lebanon-national-drug-index-lndi-

The two are joined on (normalized brand name, public price), falling back to
(brand, strength) and then brand alone when that is unambiguous. Rows that
cannot be joined keep their price-list data with empty ingredients.

Usage:
  pip install xlrd
  python tools/build_medicine_dataset.py --xls path/to/WebMarketed.xls \
      [--cache-dir .moph_cache] [--delay 2.0]

The LNDI pages are cached in --cache-dir so re-runs do not hit the MOPH
server again. Keep --delay polite; the script fetches ~60 pages.
"""

import argparse
import csv
import datetime
import html
import os
import re
import sys
import time
import urllib.request

import xlrd

LNDI_PAGE_URL = "https://www.moph.gov.lb/en/Drugs/index/3/4848/page:{page}/limit:100"
PRICE_LIST_URL = "https://www.moph.gov.lb/en/Pages/3/3101/drugs-public-price-list"
LNDI_URL = "https://www.moph.gov.lb/en/Drugs/index/3/4848/lebanon-national-drug-index-lndi-"
OUTPUT = os.path.join(os.path.dirname(__file__), "..", "assets", "medicines", "lebanon_medicine_prices.csv")

COLUMNS = [
    "medicine_id", "registration_number", "brand_name", "generic_name",
    "active_ingredients", "atc_code", "brand_generic", "strength", "form",
    "pack", "company", "agent", "country", "official_price_lbp", "currency",
    "last_updated",
]
# "source", "source_url" and "notes" were dropped in 2026-10: they were the
# same on every row (or repeated other columns) and made up two thirds of the
# file every phone downloads. The app links to PRICE_LIST_URL itself.


def norm(value):
    value = (value or "").upper()
    return re.sub(r"[^A-Z0-9%.]+", "", value)


def fetch(url, cache_path, delay):
    if os.path.exists(cache_path):
        with open(cache_path, encoding="utf-8", errors="replace") as handle:
            return handle.read()
    request = urllib.request.Request(url, headers={"User-Agent": "PharmaLens dataset builder"})
    with urllib.request.urlopen(request, timeout=90) as response:
        body = response.read().decode("utf-8", errors="replace")
    with open(cache_path, "w", encoding="utf-8") as handle:
        handle.write(body)
    time.sleep(delay)
    return body


CELL = re.compile(r'<td[^>]*>\s*<a[^>]*class="drugLink"[^>]*>(.*?)</a>\s*</td>', re.S)
ROW = re.compile(r"<tr>(.*?)</tr>", re.S)


def parse_lndi_page(body):
    rows = []
    for row_html in ROW.findall(body):
        cells = [html.unescape(re.sub(r"<!--.*?-->|<[^>]+>", "", c)).strip() for c in CELL.findall(row_html)]
        if len(cells) != 7:
            continue
        atc, name, brand_generic, ingredients, dosage, form, price = cells
        price_digits = re.sub(r"[^0-9]", "", price)
        rows.append({
            "atc": atc,
            "name": name,
            "brand_generic": brand_generic,
            "ingredients": ingredients,
            "dosage": dosage,
            "form": form,
            "price": int(price_digits) if price_digits else None,
        })
    return rows


def last_page(body):
    pages = [int(p) for p in re.findall(r"/page:(\d+)/", body)]
    return max(pages) if pages else 1


def one_line(text):
    return " ".join((text or "").split())


def split_ingredients(text):
    """'Paracetamol - 500mg, Diphenhydramine HCl - 25mg' -> ['Paracetamol', 'Diphenhydramine HCl']"""
    names = []
    for part in re.split(r",\s*(?=[A-Za-z])", text or ""):
        name = one_line(re.split(r"\s+-\s+", part, maxsplit=1)[0]).strip(" ,;|")
        if name and name not in names:
            names.append(name)
    return names


def load_lndi(cache_dir, delay):
    os.makedirs(cache_dir, exist_ok=True)
    first = fetch(LNDI_PAGE_URL.format(page=1), os.path.join(cache_dir, "lndi_1.html"), delay)
    total = last_page(first)
    rows = parse_lndi_page(first)
    for page in range(2, total + 1):
        body = fetch(LNDI_PAGE_URL.format(page=page), os.path.join(cache_dir, f"lndi_{page}.html"), delay)
        rows.extend(parse_lndi_page(body))
        print(f"LNDI page {page}/{total}: {len(rows)} rows", file=sys.stderr)
    return rows


def excel_date(value, datemode):
    try:
        return datetime.datetime(*xlrd.xldate_as_tuple(float(value), datemode)).date().isoformat()
    except Exception:
        return ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--xls", required=True)
    parser.add_argument("--cache-dir", default=".moph_cache")
    parser.add_argument("--delay", type=float, default=2.0)
    parser.add_argument("--output", default=OUTPUT)
    args = parser.parse_args()

    book = xlrd.open_workbook(args.xls)
    sheet = book.sheet_by_index(0)
    header = [str(h).strip() for h in sheet.row_values(0)]
    col = {name: index for index, name in enumerate(header)}

    lndi = load_lndi(args.cache_dir, args.delay)
    by_price, by_strength, by_brand = {}, {}, {}
    for row in lndi:
        brand = norm(row["name"])
        by_price.setdefault((brand, row["price"]), []).append(row)
        by_strength.setdefault((brand, norm(row["dosage"])), []).append(row)
        by_brand.setdefault(brand, []).append(row)

    def pick(candidates):
        if not candidates:
            return None
        ingredient_sets = {tuple(split_ingredients(c["ingredients"])) for c in candidates}
        return candidates[0] if len(ingredient_sets) == 1 else None

    output_rows, joined = [], 0
    for r in range(1, sheet.nrows):
        values = sheet.row_values(r)

        def get(name):
            value = values[col[name]] if name in col else ""
            if isinstance(value, float) and value.is_integer():
                value = int(value)
            # The app reads the CSV line by line, so fields must not contain
            # line breaks (a few MOPH cells do).
            return " ".join(str(value).split())

        brand = get("Brand name")
        if not brand:
            continue
        price_raw = values[col["Public Price LL"]]
        price = int(round(float(price_raw))) if str(price_raw).strip() else None
        key = norm(brand)

        match = pick(by_price.get((key, price), []))
        if match is None:
            match = pick(by_strength.get((key, norm(get("Strength"))), []))
        if match is None:
            match = pick(by_brand.get(key, []))
        if match is not None:
            joined += 1

        ingredients = split_ingredients(match["ingredients"]) if match else []
        updated = excel_date(values[col["Exch_Dates"]], book.datemode) if "Exch_Dates" in col else ""
        form = get("Form") or (match["form"] if match else "")

        output_rows.append({
            "medicine_id": get("Code"),
            "registration_number": get("Registration number"),
            "brand_name": brand,
            "generic_name": " + ".join(ingredients),
            # The app splits list fields on "|" (commas appear inside names).
            "active_ingredients": " | ".join(ingredients),
            "atc_code": match["atc"] if match else "",
            "brand_generic": match["brand_generic"] if match else "",
            "strength": get("Strength"),
            "form": form,
            "pack": get("Presentation"),
            "company": get("Manufacturer"),
            "agent": get("Agent"),
            "country": get("Country"),
            "official_price_lbp": price if price is not None else "",
            "currency": "LBP",
            "last_updated": updated,
        })

    dates = [row["last_updated"] for row in output_rows if row["last_updated"]]
    if dates:
        list_date = max(set(dates), key=dates.count)
        for row in output_rows:
            row["last_updated"] = row["last_updated"] or list_date

    with open(args.output, "w", encoding="utf-8", newline="") as handle:
        # "\n" on every OS: the default "\r\n" made a rebuild on Linux (GitHub
        # Actions) look like every line changed.
        writer = csv.DictWriter(handle, fieldnames=COLUMNS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(output_rows)

    print(f"Wrote {len(output_rows)} medicines ({joined} with ingredients) to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
