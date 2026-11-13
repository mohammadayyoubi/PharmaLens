"""Offline tests for how update_moph_dataset.py finds the newest MOPH sheet.

  python tools/test_update_moph_dataset.py

MOPH names its files by hand; every case below is a naming it has used or
plausibly could. The workflow runs these before each update.
"""

import datetime
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import update_moph_dataset as updater  # noqa: E402

TODAY = datetime.date(2026, 12, 20)
BASE = "/userfiles/files/HealthCareSystem/Pharmaceuticals/DrugsPublicPriceList"
UTC = datetime.timezone.utc


def link(path, text="Drugs Public Price List"):
    return f'<li><a href="{BASE}/{path}" target="_blank">{text}</a> according to decision no. 119/1 issued on 30/01/2020</li>\n'


def heading(date):
    return f'<div class="panel_heading">Drugs Prices According to the Exchange Rate Issued on {date}</div>\n'


OCTOBER = (
    heading("5/10/2026")
    + link("5-10-2026/WebMarketed20261005-19-10-2026.xls")
    + link("5-10-2026/web%20primary%20registered%20drugs%20-%2020261005.xlsx",
           "List of drugs according to decision 1489/1 dated 17/12/2021 (primary registration)")
    + link("5-10-2026/WebMarketed20261005.xls")
    + link("5-10-2026/WebNonMarketed20261005.xls", "Non Marketed Drugs Public Price List")
)


def find(page, uploads=None):
    """find_sheet with HEAD answered from `uploads` ({file name: datetime})."""
    uploads = uploads or {}
    asked = []

    def head(url):
        asked.append(url)
        for name, modified in uploads.items():
            if url.endswith(name):
                return {"last_modified": modified, "size": 3_000_000}
        return {}

    sheet = updater.find_sheet(page, head=head, today=TODAY)
    sheet["asked"] = asked
    return sheet


class FindSheetTest(unittest.TestCase):
    def test_revised_sheet_beats_the_original(self):
        sheet = find(OCTOBER)
        self.assertEqual(sheet["file"], "WebMarketed20261005-19-10-2026.xls")
        self.assertEqual(sheet["list_date"], "2026-10-05")
        self.assertEqual(sheet["published"], "2026-10-19")

    def test_stray_hyphen_after_the_date(self):
        # The November 2026 sheet that the old pattern missed.
        page = heading("11/11/2026") + link("11-11-2026/WebMarketed20261111-.xls") + OCTOBER
        sheet = find(page)
        self.assertEqual(sheet["file"], "WebMarketed20261111-.xls")
        self.assertEqual(sheet["published"], "2026-11-11")

    def test_odd_suffixes(self):
        for name in ("WebMarketed20261111 (1).xls", "WebMarketed20261111_final.xls",
                     "WebMarketed20261111-updated.xls", "WEBMARKETED20261111.XLS"):
            with self.subTest(name=name):
                page = heading("11/11/2026") + link(f"11-11-2026/{name}") + OCTOBER
                self.assertEqual(find(page)["file"], name)

    def test_other_date_formats(self):
        for name, expected in (("WebMarketed-11-11-2026.xls", "2026-11-11"),
                               ("WebMarketed_2026-11-11.xlsx", "2026-11-11"),
                               ("WebMarketed 11.11.2026.xls", "2026-11-11")):
            with self.subTest(name=name):
                page = link(f"prices/{name}") + OCTOBER
                sheet = find(page)
                self.assertEqual(sheet["file"], name)
                self.assertEqual(sheet["published"], expected)

    def test_no_date_in_name_uses_the_folder(self):
        page = heading("12/12/2026") + link("12-12-2026/WebMarketed.xls") + OCTOBER
        sheet = find(page)
        self.assertEqual(sheet["file"], "WebMarketed.xls")
        self.assertEqual(sheet["published"], "2026-12-12")

    def test_no_date_anywhere_uses_the_upload_time(self):
        page = link("WebMarketed.xls") + OCTOBER
        sheet = find(page, {"/WebMarketed.xls": datetime.datetime(2026, 12, 3, 9, 0, tzinfo=UTC)})
        self.assertEqual(sheet["file"], "WebMarketed.xls")
        self.assertEqual(sheet["published"], "2026-12-03")

    def test_renamed_file_found_by_its_link_text(self):
        page = heading("12/12/2026") + link("12-12-2026/Prices%20December.xls") + OCTOBER
        self.assertEqual(find(page)["file"], "Prices December.xls")

    def test_same_date_twice_takes_the_later_upload(self):
        page = (heading("12/12/2026")
                + link("12-12-2026/WebMarketed20261212.xls")
                + link("12-12-2026/WebMarketed20261212%20corrected.xls") + OCTOBER)
        sheet = find(page, {
            "/WebMarketed20261212.xls": datetime.datetime(2026, 12, 12, 8, 0, tzinfo=UTC),
            "/WebMarketed20261212%20corrected.xls": datetime.datetime(2026, 12, 14, 8, 0, tzinfo=UTC),
        })
        self.assertEqual(sheet["file"], "WebMarketed20261212 corrected.xls")
        self.assertEqual(sheet["published"], "2026-12-14")

    def test_reupload_under_the_same_name_moves_published(self):
        sheet = find(OCTOBER, {"/WebMarketed20261005-19-10-2026.xls": datetime.datetime(2026, 11, 2, 7, 0, tzinfo=UTC)})
        self.assertEqual(sheet["file"], "WebMarketed20261005-19-10-2026.xls")
        self.assertEqual(sheet["list_date"], "2026-10-05")
        self.assertEqual(sheet["published"], "2026-11-02")
        self.assertEqual(sheet["last_modified"], "2026-11-02T07:00:00+00:00")

    def test_non_marketed_and_primary_lists_are_never_chosen(self):
        page = (link("12-12-2026/WebNonMarketed20261212.xls", "Non Marketed Drugs Public Price List")
                + link("12-12-2026/web%20primary%20registered%20drugs%20-%2020261212.xlsx",
                       "List of drugs (primary registration)")
                + OCTOBER)
        with self.assertRaises(SystemExit):  # the 12-12 folder has no price list
            find(page)

    def test_impossible_and_future_dates_are_ignored(self):
        page = link("WebMarketed20991231.xls") + link("WebMarketed20261345.xls") + OCTOBER
        self.assertEqual(find(page)["file"], "WebMarketed20261005-19-10-2026.xls")

    def test_announced_release_without_a_recognized_sheet_fails(self):
        page = heading("12/12/2026") + link("12-12-2026/Liste.xls", "Liste des prix") + OCTOBER
        with self.assertRaises(SystemExit) as raised:
            find(page)
        self.assertIn("2026-12-12", str(raised.exception))

    def test_heading_alone_announces_a_release(self):
        page = heading("12/12/2026") + OCTOBER
        with self.assertRaises(SystemExit):
            find(page)

    def test_unknown_undated_spreadsheet_fails(self):
        page = link("Liste.xls", "Liste des prix") + OCTOBER
        with self.assertRaises(SystemExit):
            find(page)

    def test_old_unknown_spreadsheet_is_ignored(self):
        page = OCTOBER + link("1-1-2025/Archive.xls", "Archive")
        self.assertEqual(find(page)["file"], "WebMarketed20261005-19-10-2026.xls")

    def test_page_without_any_price_list_fails(self):
        with self.assertRaises(SystemExit):
            find("<html><body>Maintenance</body></html>")

    def test_dated_links_need_no_head_request_except_the_chosen_one(self):
        sheet = find(OCTOBER)
        self.assertEqual(len(sheet["asked"]), 1)


if __name__ == "__main__":
    unittest.main(verbosity=1)
