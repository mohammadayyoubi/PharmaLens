"""Builds the PharmaLens pages for techwraplb.com into docs/web/pharmalens/:

  index.html            https://techwraplb.com/pharmalens
  privacy-policy.html   https://techwraplb.com/pharmalens/privacy-policy
  icon.png              the app icon the pages show

The privacy policy is generated from assets/legal/privacy_policy_{en,ar}.md,
the same text the app shows offline, so the two never drift apart. Run after
editing either file, then upload the folder (see docs/play-store/README.md):

  python tools/build_privacy_page.py

The pages are plain HTML that read without JavaScript (Google Play's review
must be able to open the policy). They use the TechWrap site's fonts, colors
and logo (/assets/img/ on the server) and follow the system light/dark mode.

Only the Markdown the policy uses is supported: # headings, - bullets (two
levels), **bold**, [links](https://...) and paragraphs.
"""

import html
import os
import re
import shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(ROOT, "docs", "web", "pharmalens")
PLAY_URL = "https://play.google.com/store/apps/details?id=com.techwraplb.pharmalens"
WHATSAPP = "https://wa.me/96170080214"
INSTAGRAM = "https://www.instagram.com/techwrap.lb/"


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    return re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", r'<a href="\2" rel="noopener">\1</a>', text)


def to_html(markdown):
    # Each list item stays open until the next item at its level (or a
    # shallower one) so a nested list can go inside it.
    out, depth = [], 0

    def close_to(level):
        nonlocal depth
        while depth > level:
            out.append("</li></ul>")
            depth -= 1

    for raw in markdown.splitlines():
        line = raw.rstrip()
        bullet = re.match(r"^( *)- (.*)$", line)
        if bullet:
            level = 1 + len(bullet.group(1)) // 2
            if level > depth:
                while depth < level:
                    out.append("<ul>")
                    depth += 1
            else:
                close_to(level)
                out.append("</li>")
            out.append(f"<li>{inline(bullet.group(2))}")
            continue
        close_to(0)
        heading = re.match(r"^(#{1,6}) (.*)$", line)
        if heading:
            n = len(heading.group(1))
            out.append(f"<h{n}>{inline(heading.group(2))}</h{n}>")
        elif line:
            out.append(f"<p>{inline(line)}</p>")
    close_to(0)
    return "\n".join(out)


STYLE = """
:root {
  color-scheme: light dark;
  --bg: #ffffff; --surface: #f6f8fc; --card: #ffffff; --border: #e2e7f0;
  --fg: #011132; --muted: #5b6475; --accent: #0153f0; --accent-soft: rgb(1 83 240 / 0.08);
  --teal: #168f88; --warn-bg: #fff8ec; --warn-border: #f2c47a;
  --shadow: 0 1px 2px rgb(1 17 50 / 0.04), 0 8px 24px -12px rgb(1 17 50 / 0.12);
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #060b1c; --surface: #0c1430; --card: #121c3d; --border: #1e2a4f;
    --fg: #eaf0ff; --muted: #9aa6c0; --accent: #5b93ff; --accent-soft: rgb(91 147 255 / 0.12);
    --teal: #6bdad3; --warn-bg: #2a2110; --warn-border: #7a5a1e;
    --shadow: 0 1px 2px rgb(0 0 0 / 0.3), 0 12px 32px -16px rgb(0 0 0 / 0.6);
  }
}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; }
body { margin: 0; background: var(--bg); color: var(--fg); overflow-wrap: break-word;
  font: 16px/1.65 "Inter", "IBM Plex Sans Arabic", system-ui, -apple-system, "Segoe UI", sans-serif; }
[lang="ar"] { font-family: "IBM Plex Sans Arabic", system-ui, sans-serif; }
a { color: var(--accent); }
header.site { position: sticky; top: 0; z-index: 2; background: color-mix(in srgb, var(--bg) 82%, transparent);
  backdrop-filter: blur(10px); border-bottom: 1px solid var(--border); }
header.site .in { max-width: 960px; margin: 0 auto; padding: 10px 16px; display: flex; flex-wrap: wrap;
  align-items: center; gap: 8px 16px; }
/* One logo per theme: logo-light.png has dark text (for light backgrounds). */
header.site img.logo { height: 28px; width: auto; display: block; }
header.site img.logo-for-dark { display: none; }
@media (prefers-color-scheme: dark) {
  header.site img.logo-for-light { display: none; }
  header.site img.logo-for-dark { display: block; }
}
header.site nav { margin-inline-start: auto; display: flex; flex-wrap: wrap; gap: 4px 14px; font-weight: 600; font-size: 14px; }
header.site nav a { text-decoration: none; }
main, .card, .hero .txt { min-width: 0; }
main { max-width: 960px; margin: 0 auto; padding: 24px 16px 56px; }
h1, h2, .display { font-family: "Space Grotesk", "IBM Plex Sans Arabic", system-ui, sans-serif; letter-spacing: -0.01em; }
[lang="ar"] h1, [lang="ar"] h2, [lang="ar"] .display { font-family: "IBM Plex Sans Arabic", system-ui, sans-serif; letter-spacing: 0; }
h1 { font-size: clamp(1.7rem, 4vw, 2.3rem); line-height: 1.2; margin: 0.4em 0; }
h2 { font-size: 1.2rem; margin: 1.8em 0 0.5em; }
.card { background: var(--card); border: 1px solid var(--border); border-radius: 24px; padding: 8px 24px 24px;
  box-shadow: var(--shadow); margin-bottom: 24px; }
.hero { display: flex; gap: 20px; align-items: center; flex-wrap: wrap; padding: 24px; }
.hero img { width: 96px; height: 96px; border-radius: 24px; box-shadow: var(--shadow); }
.hero .txt { flex: 1 1 240px; }
@media (max-width: 480px) { .card { padding: 4px 16px 18px; } .hero { padding: 18px; } }
.tag { display: inline-block; background: var(--accent-soft); color: var(--accent); border-radius: 999px;
  padding: 4px 12px; font-size: 13px; font-weight: 700; }
.btn { display: inline-flex; align-items: center; gap: 8px; background: var(--fg); color: var(--bg); text-decoration: none;
  padding: 12px 18px; border-radius: 14px; font-weight: 700; margin: 6px 8px 0 0; }
.btn.alt { background: var(--accent-soft); color: var(--accent); }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; padding: 0; list-style: none; }
.grid li { background: var(--surface); border: 1px solid var(--border); border-radius: 16px; padding: 14px 16px; margin: 0; }
.grid b { display: block; margin-bottom: 2px; }
.notice { background: var(--warn-bg); border: 1px solid var(--warn-border); border-radius: 16px; padding: 4px 18px; }
.langs { display: flex; gap: 10px; margin: 8px 0 16px; }
li { margin: 4px 0; }
footer.site { border-top: 1px solid var(--border); color: var(--muted); font-size: 14px; }
footer.site .in { max-width: 960px; margin: 0 auto; padding: 20px 16px 32px; display: flex; flex-wrap: wrap; gap: 8px 20px; }
footer.site a { color: var(--muted); }
"""


def page(title, description, body):
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(description)}">
<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#060b1c" media="(prefers-color-scheme: dark)">
<link rel="icon" type="image/png" href="/pharmalens/icon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;600;700&family=Inter:wght@400;600;700&family=Space+Grotesk:wght@600;700&display=swap">
<style>{STYLE}</style>
</head>
<body>
<header class="site"><div class="in">
  <a href="/" aria-label="TechWrap home">
    <img class="logo logo-for-light" src="/assets/img/logo-light.png" alt="TechWrap" width="113" height="28">
    <img class="logo logo-for-dark" src="/assets/img/logo-dark.png" alt="TechWrap" width="113" height="28">
  </a>
  <nav><a href="/pharmalens">PharmaLens</a><a href="/pharmalens/privacy-policy">Privacy</a><a href="/contact">Contact</a></nav>
</div></header>
<main>
{body}
</main>
<footer class="site"><div class="in">
  <span>© 2026 TechWrap LB · Beirut, Lebanon</span>
  <a href="/pharmalens/privacy-policy">Privacy policy · سياسة الخصوصية</a>
  <a href="{WHATSAPP}" rel="noopener">WhatsApp +961 70 080 214</a>
  <a href="{INSTAGRAM}" rel="noopener">Instagram @techwrap.lb</a>
</div></footer>
</body>
</html>
"""


def read(lang):
    with open(os.path.join(ROOT, "assets", "legal", f"privacy_policy_{lang}.md"), encoding="utf-8") as handle:
        return handle.read()


def privacy_page():
    body = f"""<nav class="langs"><a class="btn alt" href="#en">English</a><a class="btn alt" href="#ar">العربية</a></nav>
<article class="card" id="en" lang="en" dir="ltr">
{to_html(read("en"))}
</article>
<article class="card" id="ar" lang="ar" dir="rtl">
{to_html(read("ar"))}
</article>"""
    return page("PharmaLens privacy policy | TechWrap",
                "What PharmaLens keeps on your phone, what it sends to Google and other services, and how to delete your data.",
                body)


def landing_page():
    en = f"""<section class="card hero" lang="en" dir="ltr" id="en">
  <img src="/pharmalens/icon.png" alt="PharmaLens icon" width="112" height="112">
  <div class="txt">
    <span class="tag">By TechWrap LB · Lebanon</span>
    <h1>PharmaLens</h1>
    <p>Read prescriptions with AI, check official MOPH medicine prices, and never miss a dose. In English and Arabic.</p>
    <a class="btn" href="{PLAY_URL}" rel="noopener">Get it on Google Play</a>
    <a class="btn alt" href="#ar">العربية</a>
  </div>
</section>
<section class="card" lang="en" dir="ltr">
  <h2>What it does</h2>
  <ul class="grid">
    <li><b>Read a prescription</b>Take a photo; the medicines and the doctor's directions are read and checked against the official MOPH list.</li>
    <li><b>Official prices</b>The MOPH public price of every registered medicine, and cheaper products with the same ingredient, strength and form.</li>
    <li><b>Safety checks</b>Alerts for allergies, the same ingredient twice, and medicines that may affect health conditions such as asthma or kidney disease.</li>
    <li><b>Family</b>Allergies, conditions, prescriptions and reminders for each family member.</li>
    <li><b>Reminders and alarms</b>Notifications or alarms that say the medicine's name, with refill estimates.</li>
    <li><b>Doctors and pharmacies</b>The Lebanese Order of Physicians list, nearby pharmacies, and emergency numbers.</li>
  </ul>
  <h2>Important</h2>
  <div class="notice">
    <p>PharmaLens is an individual initiative. It is <strong>not the Ministry of Public Health app</strong>, is not affiliated with the Ministry and does not replace any official MOPH platform. Medicine prices come from the official list published on the <a href="https://www.moph.gov.lb" rel="noopener">MOPH website</a>.</p>
    <p>AI can make mistakes. PharmaLens does not replace your doctor or pharmacist; always check medicines and doses with them.</p>
  </div>
  <h2>Your data</h2>
  <p>There is no account and no ads. Health profiles, prescriptions and reminders stay on your phone. Prescription photos and assistant questions are sent to Google's Gemini AI to be read; your location is sent to Google Places to find pharmacies. Read the full <a href="/pharmalens/privacy-policy">privacy policy</a>.</p>
  <p><strong>Delete your data:</strong> in the app, open Settings › Delete all my data, or uninstall the app. Nothing is stored on our side.</p>
  <h2>Help</h2>
  <p>WhatsApp <a href="{WHATSAPP}" rel="noopener">+961 70 080 214</a> · Instagram <a href="{INSTAGRAM}" rel="noopener">@techwrap.lb</a>. To report a wrong AI answer, tap the flag under the answer in the app.</p>
</section>"""
    ar = f"""<section class="card" lang="ar" dir="rtl" id="ar">
  <h1>فارما لينس</h1>
  <p>اقرأ وصفتك الطبية بالذكاء الاصطناعي، وتحقق من أسعار الأدوية الرسمية لوزارة الصحة، ولا تفوّت أي جرعة. بالعربية والإنجليزية.</p>
  <a class="btn" href="{PLAY_URL}" rel="noopener">حمّله من Google Play</a>
  <h2>ماذا يفعل</h2>
  <ul class="grid">
    <li><b>قراءة الوصفة</b>التقط صورة فتُقرأ الأدوية وتعليمات الطبيب ويُتحقق منها في لائحة وزارة الصحة الرسمية.</li>
    <li><b>الأسعار الرسمية</b>سعر كل دواء مسجّل في وزارة الصحة، وبدائل أرخص بنفس المادة الفعالة والتركيز والشكل.</li>
    <li><b>فحوص السلامة</b>تنبيهات للحساسية وللمادة الفعالة المكررة وللأدوية التي قد تؤثر على حالات مثل الربو أو أمراض الكلى.</li>
    <li><b>العائلة</b>الحساسية والحالات الصحية والوصفات والتذكيرات لكل فرد من العائلة.</li>
    <li><b>التذكيرات والمنبهات</b>إشعارات أو منبهات تقول اسم الدواء، مع تقدير موعد إعادة الشراء.</li>
    <li><b>الأطباء والصيدليات</b>لائحة نقابة الأطباء في لبنان، والصيدليات القريبة، وأرقام الطوارئ.</li>
  </ul>
  <h2>تنبيه مهم</h2>
  <div class="notice">
    <p>فارما لينس مبادرة فردية. هو <strong>ليس تطبيق وزارة الصحة العامة</strong>، ولا يتبع للوزارة، ولا يحلّ محلّ أي منصة رسمية لها. أسعار الأدوية مأخوذة من اللائحة الرسمية المنشورة على <a href="https://www.moph.gov.lb" rel="noopener">موقع وزارة الصحة</a>.</p>
    <p>قد يخطئ الذكاء الاصطناعي. فارما لينس لا يحلّ محلّ الطبيب أو الصيدلي؛ تحقق دائمًا معهما من الأدوية والجرعات.</p>
  </div>
  <h2>بياناتك</h2>
  <p>لا يوجد حساب ولا إعلانات. الملفات الصحية والوصفات والتذكيرات تبقى على هاتفك. تُرسل صور الوصفات وأسئلة المساعد إلى الذكاء الاصطناعي Gemini من Google لقراءتها، ويُرسل موقعك إلى Google Places للعثور على الصيدليات. اقرأ <a href="/pharmalens/privacy-policy#ar">سياسة الخصوصية</a> كاملة.</p>
  <p><strong>حذف بياناتك:</strong> في التطبيق افتح الإعدادات › حذف جميع بياناتي، أو أزل التطبيق. لا يُحفظ أي شيء لدينا.</p>
  <h2>المساعدة</h2>
  <p>واتساب <a href="{WHATSAPP}" rel="noopener">‎+961 70 080 214</a> · إنستغرام <a href="{INSTAGRAM}" rel="noopener">@techwrap.lb</a>. للإبلاغ عن إجابة خاطئة من الذكاء الاصطناعي، اضغط على العلم تحت الإجابة في التطبيق.</p>
</section>"""
    return page("PharmaLens: prescriptions, MOPH prices and reminders | TechWrap",
                "PharmaLens reads prescriptions with AI, shows official MOPH medicine prices and reminds you of every dose. An individual initiative by TechWrap LB.",
                en + "\n" + ar)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, content in (("privacy-policy.html", privacy_page()), ("index.html", landing_page())):
        with open(os.path.join(OUT_DIR, name), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
    shutil.copyfile(os.path.join(ROOT, "docs", "play-store", "icon-512.png"), os.path.join(OUT_DIR, "icon.png"))
    print(f"Wrote {OUT_DIR}: index.html, privacy-policy.html, icon.png")


if __name__ == "__main__":
    main()
