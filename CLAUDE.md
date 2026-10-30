# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PharmaLens (`pharmalens` package) is a Flutter app that reads prescriptions and acts as a medicine safety assistant for Lebanon. It targets Android, iOS, web and desktop, and supports English and Arabic (RTL). Made by TechWrap LB.

## Commands

```bash
flutter pub get
flutter run                                    # dev; see "Secrets" for keys
flutter run --dart-define=GEMINI_API_KEY=...  # instead of lib/private/api_keys.dart
flutter analyze                                # flutter_lints is enabled; keep it at "No issues found"
flutter test
flutter test test/safety_logic_test.dart --plain-name "1000mg written matches a 1g product"
flutter gen-l10n                               # after editing lib/l10n/*.arb
python tools/update_moph_dataset.py           # fetch the newest MOPH sheet and rebuild the CSV if it changed (needs `pip install xlrd`)
python tools/generate_brand_assets.py         # redraw the logo, every app icon and the in-app illustrations (needs Pillow)
```

- **Android:** Gradle 8.14 does not run on Java 25. Point Flutter at JDK 17 (`flutter config --jdk-dir=...`), or run `android/gradlew` with `JAVA_HOME` set to JDK 17.
- **Release signing:** `android/key.properties` (git-ignored) with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Without it, release builds use the debug key, which Google Play rejects.
- **R8:** release builds shrink code and resources. Plugins bring their own keep rules; [proguard-rules.pro](android/app/proguard-rules.pro) silences ML Kit's optional scripts; resources referenced only by name from Dart (notification icon `@mipmap/ic_launcher_monochrome`, `@raw/pharmalens_alarm`) must be listed in [keep.xml](android/app/src/main/res/raw/keep.xml) or they are stripped.
- **Windows desktop:** builds need Windows Developer Mode, for plugin symlinks.
- **Web links:** `/?tab=doctors` opens a section, and `/?tab=medicines&medicine=<MOPH code>` opens a medicine page. Both are handy for headless screenshots of `build/web`.

## Secrets

`lib/private/*.dart` is git-ignored. Copy the committed `*.example.dart` templates. Run `git config core.hooksPath .githooks` once per clone: the pre-commit hook blocks any staged Google/Gemini key (the repo is public, and keys from early commits are still in its history, so any key that was ever committed must be rotated, not just removed). For CI or Play Store builds on another machine, pass keys with `--dart-define=GEMINI_API_KEY=...` instead of the file. Keys needed: Gemini (`api_keys.dart`) and Google Places (`google_maps_private_config.dart`, nearby places and hospital contacts). The keys ship inside the app, so restrict each in Google Cloud (API restriction plus a quota cap). No Maps SDK key: the map does not use Google. Never print key values or commit them.

## Safety-critical code

Changes to these files need a test in [test/safety_logic_test.dart](test/safety_logic_test.dart) (or next to it), using the real bundled catalog where possible:
[medicine_equivalence.dart](lib/utils/medicine_equivalence.dart), [medicine_verification_service.dart](lib/services/medicine_verification_service.dart), [medication_safety_service.dart](lib/services/medication_safety_service.dart), [medical_domain_guard_service.dart](lib/services/medical_domain_guard_service.dart), [reminder_service.dart](lib/services/reminder_service.dart) and [medicine_reminder.dart](lib/models/medicine_reminder.dart).

## Architecture

**Shell ([lib/app/app_shell.dart](lib/app/app_shell.dart)):** a bottom `NavigationBar` below 720 px, a `NavigationRail` up to 1100 px, and a sidebar above that. Breakpoints live in [lib/widgets/responsive.dart](lib/widgets/responsive.dart), alongside `PageFrame`, `AdaptiveGrid`, `SurfaceCard`, `AdaptiveBackButton`, `PressableScale` and `FadeSlideIn`.
- Each tab has its own `Navigator`, and tabs are built lazily on first visit. Pushed pages (analysis, medicine details) stay beside the sidebar on desktop.
- Switch sections through `AppShellScope.maybeOf(context)?.selectTab(...)`.
- On phones, Settings is pushed rather than shown as a tab.
- Screens must work both as a tab root (no back button) and as a pushed page. Use `AdaptiveBackButton` or `Navigator.canPop`.
- The shell listens to `ReminderService().pendingDose` and opens the dose screen over everything; it also reports MOPH price changes for the user's own medicines.

**Startup ([lib/main.dart](lib/main.dart)):** there is no backend. `runApp` comes first; nothing heavy is awaited before the first frame. A branded startup screen matches the native splash, then first-run onboarding (privacy notice, reminder setup) or the shell.
- `MophMedicineService` parses its bundled CSV in a background isolate (`compute`) after the first frame. It never throws (see `loadError`). UI that shows counts or dates listens to `MophMedicineService().changes` (first load plus newer lists); code that needs the data awaits `initialize()`.
- `DoctorsService` (18,000 rows) is parsed five seconds after launch; the Doctors tab and the assistant await it.
- Connectivity, history, profiles then reminders, and the dose log load in the background.
- Flutter runs Dart on Android's UI thread, so main-isolate work and plugin calls before the first frame delay the app opening. Keep heavy work in isolates or after the first screen (the reminder schedule rebuild is deferred and skipped when unchanged; see Reminders). Home shows `MophSyncChip` at the top while the list loads or checks.

**Data: official sources only, never invented.**
- **Medicines:** `assets/medicines/lebanon_medicine_prices.csv` is generated by [tools/build_medicine_dataset.py](tools/build_medicine_dataset.py) from the MOPH Drugs Public Price List (XLS) joined with the Lebanon National Drug Index (ingredients, ATC).
  - Rows are keyed by MOPH code (`medicine_id`). List fields use `|`, and fields contain no newlines, because the CSV is parsed line by line. The `source`, `source_url` and `notes` columns were dropped (2026-10); the app fills the source link with `MophMedicineService.mophPublicUrl`.
  - `MophMedicineService` dedupes by code, so it keeps every strength and pack of a brand. It indexes products by code (`findById`) and normalizes search names once per product.
  - Search: scored on normalized brand, generic and ingredients; the last ranking is cached so paging does not re-score, and `countMatches` gives the total for labels. Text in Arabic letters ("بنادول") is matched by consonant skeleton ([phonetic_skeleton.dart](lib/utils/phonetic_skeleton.dart)).
  - **Automatic updates:** [.github/workflows/update-moph-prices.yml](.github/workflows/update-moph-prices.yml) runs [tools/update_moph_dataset.py](tools/update_moph_dataset.py) every 6 hours. It finds the newest `WebMarketed*.xls` on the MOPH page (re-issues carry a second date, e.g. `WebMarketed20261005-19-10-2026.xls`), rebuilds the CSV, rejects suspicious builds (row drop, missing ingredients, or more than 15% of prices changing threefold), and commits the CSV with `lebanon_medicine_prices.json` (version, `published`, row count, `sha256`).
  - The app downloads from `MophMedicineService.dataBaseUrl` (raw GitHub by default; `--dart-define=MOPH_DATA_BASE_URL=`). `startAutoUpdates()` checks the manifest on every launch, then at most hourly on reconnect and app resume, and on Sync; the CSV is fetched only when the manifest is newer and must match its `sha256` and row count. Downloaded lists are saved to a file (browser storage on web), `datasetRevision` notifies the UI, and `lastPriceChanges` lists what changed. `progress` (stage plus 0..1) drives [sync_progress.dart](lib/widgets/sync_progress.dart): the home card, Settings and Medicines show "Checking for new data… 42%", and `MophSyncButton` can't be pressed again until `isSyncing` ends.
  - The app's base URL must be publicly readable. If the repo is private, set the workflow's `DATA_REPO` variable and `DATA_REPO_TOKEN` secret to mirror the files to a public repo, and point `MOPH_DATA_BASE_URL` there.
- **Equivalence:** [lib/utils/medicine_equivalence.dart](lib/utils/medicine_equivalence.dart) is the canonical definition of "same ingredient / strength / form" and of price per tablet, ml or g. Alternatives, the cheapest-equivalent list, verification and safety checks all build on it; `MedicineNormalizer` is for search text only.
  - Form families check the route first (eye, ear, nasal, inhalation, vaginal, rectal, injection) so a vaginal tablet never equals an oral one. Modified release is matched on whole words.
  - `strengthKey` turns g and mcg into mg; `packQuantity` reads "10x1ml" as 10 ml.
- **Doctors:** `assets/doctors/lebanon_doctors.csv` comes from the Lebanese Order of Physicians list. It has name, code, specialty and hospital only: no gender, phone or address.
  - Gender is estimated from the Arabic first name by [lib/utils/doctor_gender_resolver.dart](lib/utils/doctor_gender_resolver.dart), and `Doctor.genderEstimated` is set. Unisex names stay unknown.
  - Hospital phone and location are looked up at runtime through Google Places (`HospitalContactService`) and cached for 30 days.
- **Patient information** (uses, how to take, side effects, warnings): the MOPH list has none, so [lib/services/medicine_info_service.dart](lib/services/medicine_info_service.dart) builds it at runtime.
  - It takes the openFDA drug label with the same ingredients, route, form and (preferably) strength, maps INN names to US ones (`paracetamol` → `acetaminophen`), and has Gemini summarize it in English and Arabic. With no matching label, Gemini writes it from general knowledge.
  - The page always labels the origin (`MedicineInfoOrigin`): AI summary of an FDA label, raw FDA label (no Gemini key), or AI-written. Keep that label; never present this text as reviewed or official.
  - Doses are only stated for the product's own strength. Results are cached in SharedPreferences per ingredients + form family + strength.
  - On a scanned medicine, "How to use" shows the doctor's written directions first; without them it says they could not be read and to ask, then the usual use. The scan prompt's DIRECTIONS section and schema descriptions make Gemini copy directions (often Arabic, on the line under the name) into `writtenInstructions`, dose, frequency and duration; without them it left these empty.
  - `ForYouCard` quotes the label lines that match the selected person's allergies and conditions, and their age (under 12 counts as "child"; 65 and over always gets a check-with-your-doctor note), weight (weight-based dosing, under 40 kg) and BMI (weight-loss medicines, ATC A08, with a normal BMI). It never says a medicine is safe. `LabelInteractionService` (on request, from the scan results) finds where one prescribed medicine's label names another.
  - **Alternatives** is one card: "Same dose" (`isEquivalent`: same ingredients, strength and form, i.e. the same medicine at another price, with the saving) and "Other strengths & forms", cheapest first. Detail cards are `_ExpandableCard`s with a `PageStorageKey`: the phone layout is a lazy `ListView`, and without the key a card the user closed reopened when scrolled back into view.

**Prescription pipeline ([lib/screens/analysis_screen.dart](lib/screens/analysis_screen.dart)):**
1. OCR runs (ML Kit; skipped on web).
2. `AiHandwritingService` transcribes the image through `GeminiClient.generateJson` within a 100 s total budget (35 s per request), with a shorter recovery prompt when the first finds no lines.
3. `MedicineVerificationService` matches the transcription to MOPH products. The strength comes from the product text, never the directions ("5 ml three times daily" is a dose). Forms are compared by family, and the route is implied by the MOPH form (the list has no route column).
4. `MedicationSafetyService` flags allergies (ingredient, ATC class, Arabic names, related chemical class), duplicate ingredients and same-class pairs. Possible matches get allergy alerts worded "If this line is ...".
5. The scan is saved on the device by `PrescriptionHistoryService`, under the selected person.

A "possible" line opens a quick picker of the closest products before full search.

The design rule is that **Gemini only transcribes**. Identity, prices and safety come from registry data.

**Gemini ([lib/services/gemini_client.dart](lib/services/gemini_client.dart)):** the one place for keys, model order, `generationConfig` and the model/key fallback loop (`send`, with a total time budget). Every Gemini call goes through it: `generateJson` (scan, medicine info) or `chatWithTools` (assistant). Errors arrive as `GeminiException` with a `GeminiErrorKind`. Gemini 3 models get `thinkingLevel: low` and no temperature: their default high thinking, or a temperature below 1.0, made scans slow or cut off (thinking tokens count toward `maxOutputTokens`). In a tool conversation the model's turns are sent back verbatim (Gemini 3 thought signatures) and later rounds stay on the model that answered first.

**Assistant ([lib/services/chatbot_service.dart](lib/services/chatbot_service.dart)):**
- Its instructions are [assets/chatbot/knowledge_notes.md](assets/chatbot/knowledge_notes.md), sent as `systemInstruction` with every message; edit them to change its behavior.
- Facts come from [ChatbotTools](lib/services/chatbot_tools.dart) (MOPH search, details, alternatives, safety check, the selected person's data, patient information, doctors, nearby pharmacies, dataset info). Prices only in LBP, as the tools return them; never from model memory.
- A photo goes through `AiHandwritingService` and `MedicineVerificationService` first; the model sees only the verified result.
- `MedicalDomainGuardService` runs first: crisis messages get Embrace 1564 and Red Cross 140, follow-ups in a health conversation are allowed.
- Answers are Markdown rendered by [MarkdownText](lib/widgets/markdown_text.dart) (no raw `**`), with an AI notice under each answer and pinned at the top.

**Reminders ([lib/services/reminder_service.dart](lib/services/reminder_service.dart)):**
- Modes: notification, or alarm (repeats until answered, full-screen intent). Android fixes a channel's sound at creation, so each alarm sound has its own channel: `medicine_alarms_v1` for the PharmaLens tone (`res/raw/pharmalens_alarm.wav`), `medicine_alarms_<md5>` for a chosen one; the old channel is deleted when the sound changes.
- **Alarm sound** ([AlarmSoundService](lib/services/alarm_sound_service.dart), [AlarmSound.kt](android/app/src/main/kotlin/com/codepeakstudio/pharmalens/AlarmSound.kt), `AlarmSoundTile` in the reminder editor and setup sheet; Android only): the phone's alarm-tone picker, or any audio file, which is copied into the shared `Alarms/PharmaLens` folder (Android 10+) because the notification system cannot read a file granted only to the app. The dose screen plays it natively (looping; it pauses for the spoken name) and falls back to the PharmaLens tone if the file is gone.
- An end date less than 14 days away gets one notification per dose, so reminders stop exactly; longer courses repeat daily and switch as the end nears. Ids are `reminder.id * 1000 + offset`; payloads are `dose:<id>:<minutes>[:<date>]`.
- Each add, edit or answer reschedules its own reminder. The full rebuild (`_rescheduleIfNeeded`) runs 3 s after launch and on resume, only when `_scheduleSignature` changed (reminders, language, alarm channel, exact-alarm permission, time zone, day): every notification is a call on Android's UI thread, and rebuilding on every open froze the first screen. The time-zone database loads on first scheduling, not at launch.
- Taken / Snooze buttons work from the notification (`reminderBackgroundResponse`, a background isolate) and are logged by `DoseLogService` (adherence, home progress). A tap, an alarm, or a due alarm while the app is open sets `pendingDose`, and the shell opens [DoseScreen](lib/screens/dose_screen.dart) (tone plus spoken name via `flutter_tts`).
- Only a `dose:` launch may show the app over the lock screen ([MainActivity.kt](android/app/src/main/kotlin/com/codepeakstudio/pharmalens/MainActivity.kt)); the dose screen turns it off on close.
- Permissions: [ReminderPermissions](lib/services/reminder_permissions.dart) and `showReminderSetupSheet` (notifications, exact alarms, full-screen, battery). Shown in onboarding, offered again by `ensureReminderSetup` whenever a reminder is saved without what it needs. "Display over other apps" is not used.
- The course length is read from the directions (`courseDaysFrom`); refill dates come from `packUnits`, `unitsPerDose` and the times.

**On-device user data:** `PrescriptionHistoryService` (up to 200 scans; photos are copied to app storage and decoded at display size), `ReminderService`, `DoseLogService` and `HealthProfileService`. The last holds family profiles: each person's allergies, conditions, and age (stored as a birth year), sex, height and weight; `allergies` and `conditions` are the selected person's. My Health lists prescriptions and reminders a page at a time (`_Paged`), and `MyHealthScreen.requestedTab` opens a tab (Home's "Show all"). Dialogs with a text field own their controller in a `State` (`_NameDialog`): disposing it right after `showDialog` returns crashes while the dialog fades out. Reminders and prescriptions carry a `profileId` ("me" for the owner). These are `ChangeNotifier` singletons that the UI listens to with `ListenableBuilder`. `SpeechService` is one too: read aloud toggles play/pause, and resumes from the last word the engine reported. `MedicationListService` shares a person's list as text.

**Map ([lib/widgets/universal_map_view.dart](lib/widgets/universal_map_view.dart)):** one OpenStreetMap view on every platform (touch pan/pinch/double-tap, buttons, markers), no key or billing. `google_maps_flutter` was removed. Its blank map with only a "Google" logo was the key, not the code: checked on 2026-10-30, Google answered `API_KEY_ANDROID_APP_BLOCKED` for `com.codepeakstudio.pharmalens`, because the key's Android restriction didn't list this package and signing certificate (that key was also in public history). A blank map like that now means an old build is installed. CARTO's keyless tiles return a watermark; OSM's tile policy fits light use, so switch to a tile provider before heavy traffic.

**Brand:** [tools/generate_brand_assets.py](tools/generate_brand_assets.py) draws the logo (a pharmacy cross with the bowl of Hygieia, framed by camera scan corners, with AI sparkles) and writes every launcher icon (Android adaptive and themed, iOS, macOS, web, Windows), the splash logo and `assets/images/*` illustrations. Edit colors there, not in the PNGs. iOS alarms play `ios/Runner/pharmalens_alarm.wav` (a copy of the Android raw tone, listed in the Xcode project's resources).

## Localization

ARB files live in `lib/l10n/` with `app_en.arb` as the template; run `flutter gen-l10n` after editing them. The generated files are committed. Add every new string to both ARB files and read it with `context.l10n.<key>`, or with `appText(isArabic).<key>` ([app_text.dart](lib/l10n/app_text.dart)) where code has a language flag but no context (services, models, notifications). Values go in as placeholders (`"{count} medicines"`). Don't add new inline `isArabic ? 'ar' : 'en'` pairs. The few left are deliberate: English and Arabic take different values, or the text is a name rather than a translation. [test/sync_and_l10n_test.dart](test/sync_and_l10n_test.dart) checks that both files have the same keys and placeholders.

## Theming

Use `PharmaLensTheme.paletteOf(context)`, `PharmaLensColors`, `PharmaLensDecorations` and the shared widgets in `responsive.dart`, not raw colors. Colors used outside the theme have names there too (`brandGradient`, the `accent*` feature colors, map colors, other brands' marks); add new ones there rather than writing `Color(0x...)` in a screen. Every screen must work in light and dark mode, in RTL, at phone, tablet and desktop widths, and with text up to 1.6× (the app's cap). [test/app_shell_test.dart](test/app_shell_test.dart) and [test/new_screens_test.dart](test/new_screens_test.dart) fail on layout overflow. Avoid endless animations on pages tests pump to settle.

## Conventions

- Older files use a very vertical formatting style that does not match `dart format`. Match the style of the file you're editing and don't reformat whole files. New files use normal Dart formatting.
- Log errors through a local `_debugLog` or `debugPrint`, and show users friendly messages only.
- `showGeneralDialog` adds no `Material` ancestor (bottom sheets do): wrap its content in `Material(type: MaterialType.transparency)`. The same applies to an `ExpansionTile`/`ListTile` placed directly on a colored box.
- The pubspec SDK floor is `>=3.0.0`, so wildcard `_` parameters can't be repeated. Name them (`context, error, stackTrace`).
- Regex word boundaries are `\b` in a raw string. A literal backspace character (U+0008) in its place once silently broke two regexes; editing through shell heredocs can produce one.
- A `Flexible`/`Expanded` inside a vertical scroll view has no height to share and renders nothing in release builds; use a plain `Column` there.
- [medicine_details_screen.dart](lib/screens/medicine_details_screen.dart) holds the screen and its state; its cards live in `part` files under [lib/screens/medicine_details/](lib/screens/medicine_details/) (overview, prices and sources, shared building blocks, text helpers). Imports go in the main file only.
- Scripts that rewrite Dart files must keep each file's line endings (most are CRLF); open them in binary or with `newline=''`.
