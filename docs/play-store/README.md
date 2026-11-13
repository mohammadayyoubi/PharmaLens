# Publishing PharmaLens on Google Play

Everything the Play Console asks for, in the order it asks. Package name:
`com.techwraplb.pharmalens`. Version: 1.2.0 (build 3).

## 1. Build the upload file

```bash
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab`. It is signed with
the upload key in `android/key.properties`, which points to
`C:\Users\moham\keystores\pharmalens-upload.jks`.

**Back up both files** (the keystore and `android/key.properties`) somewhere
safe, such as a password manager. When creating the app, keep **Play App
Signing** on (the default). Google then keeps the real signing key, and a lost
upload key can be reset through Play support.

Upload key fingerprints (for Google Cloud and Play Console):
- SHA-1: `EC:26:86:63:A0:99:9B:EC:36:9D:64:9A:4D:DB:76:CF:EA:99:07:BB`
- SHA-256: `AD:0F:D8:70:CB:D8:1E:73:85:FF:01:BE:88:71:68:32:22:C8:8A:DC:83:CE:08:F6:22:E6:11:47:10:7D:06:2B`

For every new upload, raise `version:` in `pubspec.yaml` (for example
`1.2.1+4`) and `_appVersion` in `lib/screens/settings_screen.dart`.

## 2. Privacy policy and app page (already online)

Both pages are live on the TechWrap server (`/var/www/techwrap/pharmalens/`):

- Privacy policy: **https://techwraplb.com/pharmalens/privacy-policy**: enter
  it in Play Console > Policy > App content > Privacy policy.
- App page: **https://techwraplb.com/pharmalens**: enter it as the website
  in the store listing.

They are plain HTML (no JavaScript), in English and Arabic, styled like the
TechWrap site. After editing `assets/legal/privacy_policy_*.md`, run
`python tools/build_privacy_page.py` and upload the three files in
`docs/web/pharmalens/` to `/var/www/techwrap/pharmalens/` again (owner
`www-data`). No nginx change is needed: the site serves `/x` from `x.html`.

## 3. Lock the API keys to the app (Google Cloud > Credentials)

The app sends its package name and signing certificate with every Google
call, so each key can be restricted to this app:

1. **Gemini key**: Application restrictions > Android apps > add
   `com.techwraplb.pharmalens` with the **app signing** SHA-1 (Play Console >
   Test and release > App integrity > App signing), and the upload key SHA-1
   above for your own release builds. API restrictions > Generative Language
   API only. Set a daily quota.
2. **Places key**: the same Android restriction. API restrictions > Places
   API (New) only. Set a daily quota.
3. Use separate, unrestricted keys for development (debug builds, web,
   desktop), and never commit them. Replace any key that was ever pushed to
   the public repository.
4. **Free or paid Gemini key.** The app works with a free key, with two
   limits:
   - Quota: free limits are per Google Cloud project (extra keys in the same
     project add nothing) and Google no longer publishes them; check yours
     at aistudio.google.com/rate-limit. Developers measured about 20
     requests a day on Gemini 3.5 Flash and about 500 on Flash-Lite in late
     2026. The app tries `gemini-3.5-flash` first and falls back to the
     Flash-Lite models when it gets HTTP 429 (quota used up).
   - Terms: Google's terms for unpaid use say "Do not submit sensitive,
     confidential, or personal information", and human reviewers may read
     free-tier requests. Prescription photos and health questions are
     exactly that, so a public health app should use a **paid
     (billing-enabled)** key. The privacy policy already describes both
     cases.
5. **Places key**: Google Maps Platform needs a billing account even for
   free use. Each Places request type has a free monthly allowance (about
   1,000 to 5,000 requests per type since March 2025); set a daily quota
   so you are never charged by surprise.

## 4. App content (Policy > App content)

| Form | Answer |
|---|---|
| Privacy policy | https://techwraplb.com/pharmalens/privacy-policy |
| App access | All functionality is available without special access (no login). |
| Ads | No ads. |
| Content rating | Category: Reference / Health. No violence, sexual content, gambling or user-to-user interaction. Answer **Yes** to AI-generated content if asked. |
| Target audience | 18 and over. Not designed for children. |
| News app | No. |
| Health apps | Categories: **Medication and treatment management**, and **Medical reference and education**. Not a medical device; it does not diagnose or treat. |
| Government apps | Not a government app (see the listing disclaimer below). |
| Financial features | None. |
| Full-screen intent | Use: **Alarms**. "Medicine alarms the user sets ring at the dose time and open a Taken / Snooze screen, also over the lock screen." |

### Data safety

- Collected: yes. Shared with third parties: **no** (Google and the FDA process requests on the app's behalf as service providers).
- Encrypted in transit: **yes**.
- Users can delete their data: **yes**, in the app (Settings > Delete all my data). No account exists.

| Data type | Collected | Why | Optional |
|---|---|---|---|
| Location: approximate and precise | Yes, sent to Google Places for nearby pharmacies | App functionality | Yes |
| Personal info: name (family member names) | Yes, when the assistant looks up the selected person | App functionality | Yes |
| Health and fitness: health info (allergies, conditions, medicines) | Yes, sent to Gemini when scanning or asking the assistant | App functionality | Yes |
| Photos | Yes, prescription photos sent to Gemini | App functionality | Yes |
| Messages: other in-app messages (assistant chat) | Yes, sent to Gemini | App functionality | Yes |
| App activity: in-app search history (map search) | Yes, sent to Google Places | App functionality | Yes |

Everything else (profiles, scans, reminders, dose history) stays on the phone
and is not "collected".

## 5. Store listing

**App name** (30 max): `PharmaLens: Prescription Help`

**Short description** (80 max)

- EN: `Read prescriptions with AI, check official MOPH prices and get dose reminders.`
- AR: `اقرأ وصفتك بالذكاء الاصطناعي، وتحقق من أسعار وزارة الصحة، مع تذكيرات الجرعات.`

**Full description, English**

```
PharmaLens helps you understand your prescriptions and medicines in Lebanon.

• Read a prescription: take a photo and PharmaLens reads the medicines and the doctor's directions, then checks each one against the official MOPH list.
• Official prices: see the MOPH public price of every registered medicine and cheaper products with the same ingredient, strength and form.
• Safety checks: alerts for allergies, the same ingredient twice, and medicine groups that may affect your health conditions (asthma, kidney disease, pregnancy...).
• Family: keep allergies, conditions and prescriptions for each family member.
• Reminders and alarms: never miss a dose; alarms can ring and say the medicine's name.
• Doctors and pharmacies: search the Lebanese Order of Physicians list and find pharmacies near you.
• Assistant: ask questions about your medicines in Arabic or English.
• Emergency numbers one tap away.

Your health data stays on your phone. There is no account and no ads.

IMPORTANT
PharmaLens is an individual initiative by TechWrap LB. It is not the Ministry of Public Health app, is not affiliated with the Ministry and does not replace any official MOPH platform. Medicine prices come from the official price list published on the MOPH website: https://www.moph.gov.lb
AI can make mistakes. PharmaLens does not replace your doctor or pharmacist; always check medicines and doses with them.
```

**Full description, Arabic**

```
يساعدك فارما لينس على فهم وصفاتك الطبية وأدويتك في لبنان.

• قراءة الوصفة: التقط صورة فيقرأ فارما لينس الأدوية وتعليمات الطبيب، ثم يتحقق من كل دواء في لائحة وزارة الصحة الرسمية.
• الأسعار الرسمية: سعر كل دواء مسجّل في وزارة الصحة، وبدائل أرخص بنفس المادة الفعالة والتركيز والشكل.
• فحوص السلامة: تنبيهات للحساسية، وللمادة الفعالة المكررة، وللأدوية التي قد تؤثر على حالتك الصحية (الربو، أمراض الكلى، الحمل...).
• العائلة: احفظ الحساسية والحالات الصحية والوصفات لكل فرد من العائلة.
• التذكيرات والمنبهات: لا تفوّت أي جرعة، ويمكن للمنبه أن يرن ويقول اسم الدواء.
• الأطباء والصيدليات: ابحث في لائحة نقابة الأطباء في لبنان وجد الصيدليات القريبة منك.
• المساعد: اسأل عن أدويتك بالعربية أو الإنجليزية.
• أرقام الطوارئ بلمسة واحدة.

بياناتك الصحية تبقى على هاتفك. لا يوجد حساب ولا إعلانات.

تنبيه مهم
فارما لينس مبادرة فردية من TechWrap LB. ليس تطبيق وزارة الصحة العامة، ولا يتبع للوزارة، ولا يحلّ محلّ أي منصة رسمية لها. أسعار الأدوية مأخوذة من اللائحة الرسمية المنشورة على موقع وزارة الصحة العامة: https://www.moph.gov.lb
قد يخطئ الذكاء الاصطناعي. فارما لينس لا يحلّ محلّ الطبيب أو الصيدلي؛ تحقق دائمًا معهما من الأدوية والجرعات.
```

**Graphics** (this folder)
- App icon: `icon-512.png` (512 × 512)
- Feature graphic: `feature-graphic-1024x500.png`
- Phone screenshots: take 4 to 8 on a phone (home, scan result, medicine page with prices, My Health, reminders, pharmacies map). PNG or JPEG, 16:9 or 9:16.

**Category**: Medical. **Contact**: the website and WhatsApp in `lib/app/app_info.dart`, plus an email address for Play.

## 6. Testing before production

A **personal** developer account created after November 2023 must first run
a **closed test** with at least 12 testers for 14 days in a row before it can
publish to production. An **organization** account (TechWrap LB, needs a
D-U-N-S number) skips this.

## 7. Before each release

```bash
flutter analyze
flutter test
flutter build appbundle --release
```
