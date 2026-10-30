"""Draws the PharmaLens logo (a pharmacy cross with the bowl of Hygieia,
framed by camera scan corners with AI sparkles) and writes every app icon,
splash image and in-app illustration from it.

    pip install pillow
    python tools/generate_brand_assets.py

Re-run after changing the colors or shapes below; all outputs are
overwritten. Everything is drawn at 4x and scaled down for smooth edges.
"""

import math
import os
import struct
from io import BytesIO

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Brand colors (match lib/theme/pharmalens_theme.dart).
DEEP = (6, 43, 58)          # #062B3A
NAVY = (11, 79, 99)         # #0B4F63
CYAN = (18, 167, 162)       # #12A7A2
BRIGHT = (107, 218, 211)    # #6BDAD3
WHITE = (255, 255, 255)
CORAL = (255, 122, 107)     # capsule half (illustrations)
GREEN = (20, 150, 96)       # pharmacy green (snake)
GOLD = (255, 205, 96)       # AI sparkle

SS = 4  # supersampling factor


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, top, bottom, diagonal=True):
    img = Image.new('RGB', (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = ((x + y) / (2 * size)) if diagonal else y / size
            px[x, y] = lerp(top, bottom, t)
    return img


def gradient_fast(size, top, bottom):
    # Diagonal gradient built from a small image, then resized: fast at 4K.
    small = gradient(64, top, bottom)
    return small.resize((size, size), Image.BICUBIC)


def rounded_mask(size, radius):
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def _star(d, x, y, r, fill):
    """Four-point sparkle (the AI cue)."""
    k = 0.26
    d.polygon([(x, y - r), (x + r * k, y - r * k), (x + r, y), (x + r * k, y + r * k),
               (x, y + r), (x - r * k, y + r * k), (x - r, y), (x - r * k, y - r * k)], fill=fill)


def _emblem(d, s, outline, bowl, snake):
    """Bowl of Hygieia (the pharmacy symbol) drawn over the cross: a goblet
    with a snake coiled up its stem and its head over the bowl."""
    u = lambda v: v * s
    # Goblet: bowl (lower half-ellipse with a rim), stem and foot.
    bx0, bx1, rim, depth = u(0.335), u(0.665), u(0.43), u(0.12)
    d.pieslice((bx0, rim - depth, bx1, rim + depth), 0, 180, fill=bowl)
    d.rounded_rectangle((bx0 - u(0.012), rim - u(0.018), bx1 + u(0.012), rim + u(0.012)), radius=u(0.012), fill=bowl)
    d.rectangle((u(0.482), rim + depth * 0.9, u(0.518), u(0.705)), fill=bowl)
    d.rounded_rectangle((u(0.415), u(0.695), u(0.585), u(0.735)), radius=u(0.02), fill=bowl)

    # Snake: winds around the stem, rises past the rim, head over the bowl.
    pts = []
    for i in range(41):
        t = i / 40
        y = 0.715 - t * 0.255
        x = 0.5 + 0.06 * math.sin(t * math.pi * 3.5) * (1 - 0.25 * t)
        pts.append((u(x), u(y)))
    for (x, y) in [(0.455, 0.405), (0.455, 0.355), (0.48, 0.315), (0.525, 0.300), (0.565, 0.315)]:
        pts.append((u(x), u(y)))
    for width, fill in ((u(0.056), outline), (u(0.033), snake)):
        d.line(pts, fill=fill, width=int(width), joint='curve')
        for (x, y) in (pts[0], pts[-1]):
            r = width / 2
            d.ellipse((x - r, y - r, x + r, y + r), fill=fill)
    # Head and tongue.
    hx, hy = u(0.585), u(0.33)
    for r, fill in ((u(0.040), outline), (u(0.028), snake)):
        d.ellipse((hx - r, hy - r * 0.85, hx + r, hy + r * 0.85), fill=fill)
    d.line((hx + u(0.022), hy + u(0.012), hx + u(0.05), hy + u(0.03)), fill=snake, width=max(2, int(u(0.009))))


def draw_mark(size, ring=WHITE, glass_alpha=46, monochrome=False):
    """The mark on a transparent square of [size] px: a pharmacy cross with
    the bowl of Hygieia, framed by camera scan corners with a scan beam, and
    AI sparkles. [ring] and [glass_alpha] are kept for older callers."""
    s = size * SS
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    u = lambda v: v * s
    fg = WHITE + (255,)

    # Scan beam across the middle, behind the cross.
    if not monochrome:
        glow = Image.new('RGBA', (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(glow).rectangle((u(0.16), u(0.47), u(0.84), u(0.53)), fill=BRIGHT + (120,))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(u(0.02))))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((u(0.16), u(0.492), u(0.84), u(0.508)), radius=u(0.008), fill=(BRIGHT if not monochrome else WHITE) + (255,))

    # Camera viewfinder corners.
    inset, length, stroke = u(0.13), u(0.15), u(0.045)
    for (x, y, dx, dy) in [(inset, inset, 1, 1), (s - inset, inset, -1, 1), (inset, s - inset, 1, -1), (s - inset, s - inset, -1, -1)]:
        d.line((x, y, x + length * dx, y), fill=fg, width=int(stroke))
        d.line((x, y, x, y + length * dy), fill=fg, width=int(stroke))
        r = stroke / 2
        for (ex, ey) in ((x, y), (x + length * dx, y), (x, y + length * dy)):
            d.ellipse((ex - r, ey - r, ex + r, ey + r), fill=fg)

    # Pharmacy cross with the bowl of Hygieia on it.
    lo, hi, a0, a1, rad = u(0.215), u(0.785), u(0.385), u(0.615), u(0.05)
    if monochrome:
        # One color: the cross is solid and the emblem is cut out of it.
        cross = Image.new('L', (s, s), 0)
        cd = ImageDraw.Draw(cross)
        cd.rounded_rectangle((a0, lo, a1, hi), radius=rad, fill=255)
        cd.rounded_rectangle((lo, a0, hi, a1), radius=rad, fill=255)
        _emblem(cd, s, outline=255, bowl=0, snake=0)
        solid = Image.new('RGBA', (s, s), fg)
        img.paste(solid, (0, 0), cross)
    else:
        shadow = Image.new('RGBA', (s, s), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.rounded_rectangle((a0, lo + u(0.015), a1, hi + u(0.015)), radius=rad, fill=DEEP + (90,))
        sd.rounded_rectangle((lo, a0 + u(0.015), hi, a1 + u(0.015)), radius=rad, fill=DEEP + (90,))
        img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(u(0.015))))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((a0, lo, a1, hi), radius=rad, fill=fg)
        d.rounded_rectangle((lo, a0, hi, a1), radius=rad, fill=fg)
        _emblem(d, s, outline=fg, bowl=DEEP + (255,), snake=GREEN + (255,))

    # AI sparkles.
    d = ImageDraw.Draw(img)
    _star(d, u(0.79), u(0.25), u(0.075), (WHITE if monochrome else GOLD) + (255,))
    _star(d, u(0.685), u(0.175), u(0.035), fg)

    return img.resize((size, size), Image.LANCZOS)


def app_icon(size, rounded=True, padding=0.0):
    """Full icon: gradient tile + mark. [padding] shrinks the mark (maskable)."""
    s = size * SS
    tile = gradient_fast(s, NAVY, CYAN).convert('RGBA')
    # Soft glow behind the mark.
    glow = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((s * 0.12, s * 0.1, s * 0.78, s * 0.76), fill=BRIGHT + (60,))
    tile.alpha_composite(glow.filter(ImageFilter.GaussianBlur(s * 0.08)))
    mark_size = int(s * (1 - padding))
    mark = draw_mark(mark_size // SS).resize((mark_size, mark_size), Image.LANCZOS)
    offset = (s - mark_size) // 2
    tile.alpha_composite(mark, (offset, offset))
    if rounded:
        out = Image.new('RGBA', (s, s), (0, 0, 0, 0))
        out.paste(tile, (0, 0), rounded_mask(s, int(s * 0.225)))
        tile = out
    return tile.resize((size, size), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    return path


def write_ico(images, path):
    """Writes a Windows .ico with PNG-compressed entries."""
    entries, blobs = [], []
    for img in images:
        buf = BytesIO()
        img.save(buf, format='PNG')
        blobs.append(buf.getvalue())
        entries.append(img.size[0])
    header = struct.pack('<HHH', 0, 1, len(images))
    offset = 6 + 16 * len(images)
    directory = b''
    for size, blob in zip(entries, blobs):
        directory += struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    with open(path, 'wb') as f:
        f.write(header + directory + b''.join(blobs))


def illustration_scan(w, h):
    """Phone scanning a prescription, for the home screen and onboarding."""
    s = SS
    img = Image.new('RGBA', (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, H = w * s, h * s
    # Paper.
    px0, py0, px1, py1 = W * 0.18, H * 0.14, W * 0.62, H * 0.86
    d.rounded_rectangle((px0 + W * 0.02, py0 + H * 0.03, px1 + W * 0.02, py1 + H * 0.03), radius=W * 0.04, fill=(0, 0, 0, 40))
    d.rounded_rectangle((px0, py0, px1, py1), radius=W * 0.04, fill=WHITE + (255,))
    d.text((px0 + W * 0.04, py0 + H * 0.04), '', fill=NAVY)
    # Rx mark.
    d.rounded_rectangle((px0 + W * 0.04, py0 + H * 0.05, px0 + W * 0.13, py0 + H * 0.14), radius=W * 0.015, fill=CYAN + (255,))
    # Lines of handwriting.
    for i in range(6):
        y = py0 + H * (0.22 + i * 0.09)
        length = [0.30, 0.24, 0.33, 0.20, 0.28, 0.16][i]
        d.rounded_rectangle((px0 + W * 0.04, y, px0 + W * (0.04 + length), y + H * 0.025), radius=H * 0.012,
                            fill=(lerp(NAVY, WHITE, 0.55) + (255,)) if i % 2 else (NAVY + (200,)))
    # Phone.
    fx0, fy0, fx1, fy1 = W * 0.48, H * 0.26, W * 0.84, H * 0.94
    d.rounded_rectangle((fx0 + W * 0.015, fy0 + H * 0.02, fx1 + W * 0.015, fy1 + H * 0.02), radius=W * 0.06, fill=(0, 0, 0, 60))
    d.rounded_rectangle((fx0, fy0, fx1, fy1), radius=W * 0.06, fill=DEEP + (255,))
    d.rounded_rectangle((fx0 + W * 0.02, fy0 + H * 0.03, fx1 - W * 0.02, fy1 - H * 0.03), radius=W * 0.045, fill=NAVY + (255,))
    # Scan frame corners.
    c = W * 0.05
    sx0, sy0, sx1, sy1 = fx0 + W * 0.05, fy0 + H * 0.1, fx1 - W * 0.05, fy1 - H * 0.22
    lw = int(W * 0.012)
    for (x, y, dx, dy) in [(sx0, sy0, 1, 1), (sx1, sy0, -1, 1), (sx0, sy1, 1, -1), (sx1, sy1, -1, -1)]:
        d.line((x, y, x + c * dx, y), fill=BRIGHT + (255,), width=lw)
        d.line((x, y, x, y + c * dy), fill=BRIGHT + (255,), width=lw)
    # Scan beam.
    by = (sy0 + sy1) / 2
    d.rounded_rectangle((sx0, by - H * 0.006, sx1, by + H * 0.006), radius=H * 0.006, fill=BRIGHT + (255,))
    beam = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(beam).rectangle((sx0, by - H * 0.05, sx1, by + H * 0.05), fill=BRIGHT + (70,))
    img.alpha_composite(beam.filter(ImageFilter.GaussianBlur(W * 0.02)))
    # Check badge.
    bx, byy, br = fx1 - W * 0.02, fy1 - H * 0.12, W * 0.08
    d = ImageDraw.Draw(img)
    d.ellipse((bx - br, byy - br, bx + br, byy + br), fill=(22, 138, 103, 255))
    d.line((bx - br * 0.45, byy, bx - br * 0.1, byy + br * 0.35, bx + br * 0.5, byy - br * 0.35), fill=WHITE + (255,),
           width=int(br * 0.22), joint='curve')
    # Floating pills.
    for (x, y, rr, col) in [(0.10, 0.22, 0.035, CORAL), (0.90, 0.18, 0.03, BRIGHT), (0.08, 0.78, 0.025, BRIGHT)]:
        d.ellipse((W * x - W * rr, H * y - W * rr, W * x + W * rr, H * y + W * rr), fill=col + (230,))
    return img.resize((w, h), Image.LANCZOS)


def illustration_reminder(w, h):
    """Alarm clock with a capsule, for reminders."""
    s = SS
    W, H = w * s, h * s
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, r = W * 0.5, H * 0.54, min(W, H) * 0.32
    # Bells.
    for sgn in (-1, 1):
        bx = cx + sgn * r * 0.72
        d.ellipse((bx - r * 0.32, cy - r * 1.12, bx + r * 0.32, cy - r * 0.5), fill=CYAN + (255,))
    d.ellipse((cx - r * 1.04, cy - r * 1.04 + H * 0.02, cx + r * 1.04, cy + r * 1.04 + H * 0.02), fill=(0, 0, 0, 50))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=WHITE + (255,), outline=NAVY + (255,), width=int(r * 0.12))
    # Hands.
    d.line((cx, cy, cx, cy - r * 0.55), fill=NAVY + (255,), width=int(r * 0.09))
    d.line((cx, cy, cx + r * 0.42, cy + r * 0.1), fill=CYAN + (255,), width=int(r * 0.09))
    d.ellipse((cx - r * 0.08, cy - r * 0.08, cx + r * 0.08, cy + r * 0.08), fill=NAVY + (255,))
    # Capsule badge.
    cap = Image.new('RGBA', (int(r * 0.9), int(r * 0.38)), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cap)
    cd.rounded_rectangle((0, 0, cap.width - 1, cap.height - 1), radius=cap.height / 2, fill=CORAL + (255,))
    cd.rounded_rectangle((0, 0, cap.width / 2, cap.height - 1), radius=cap.height / 2, fill=WHITE + (255,))
    cd.rectangle((cap.width / 4, 0, cap.width / 2, cap.height - 1), fill=WHITE + (255,))
    cd.rounded_rectangle((0, 0, cap.width - 1, cap.height - 1), radius=cap.height / 2, outline=NAVY + (255,), width=int(r * 0.04))
    cap = cap.rotate(-30, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(cap, (int(cx + r * 0.35), int(cy + r * 0.35)))
    return img.resize((w, h), Image.LANCZOS)


def main():
    res = os.path.join('android', 'app', 'src', 'main', 'res')

    # In-app copies.
    save(app_icon(1024), 'assets', 'branding', 'app_icon.png')
    save(draw_mark(512), 'assets', 'branding', 'logo_mark.png')
    save(illustration_scan(720, 560), 'assets', 'images', 'scan_illustration.png')
    save(illustration_reminder(480, 480), 'assets', 'images', 'reminder_illustration.png')

    # Android legacy icons (rounded square).
    for folder, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        save(app_icon(size), res, f'mipmap-{folder}', 'ic_launcher.png')
        # Adaptive icon foreground (108dp canvas, mark inside the 66dp safe zone).
        fg_size = size * 108 // 48
        canvas = Image.new('RGBA', (fg_size, fg_size), (0, 0, 0, 0))
        mark = draw_mark(int(fg_size * 0.62))
        canvas.alpha_composite(mark, ((fg_size - mark.width) // 2, (fg_size - mark.height) // 2))
        save(canvas, res, f'mipmap-{folder}', 'ic_launcher_foreground.png')
        mono = Image.new('RGBA', (fg_size, fg_size), (0, 0, 0, 0))
        mmark = draw_mark(int(fg_size * 0.62), monochrome=True)
        mono.alpha_composite(mmark, ((fg_size - mmark.width) // 2, (fg_size - mmark.height) // 2))
        save(mono, res, f'mipmap-{folder}', 'ic_launcher_monochrome.png')
        # Splash logo (Android 11 and older draw it from launch_background).
        save(app_icon(size * 2), res, f'drawable-{folder}', 'splash_logo.png')

    # iOS (no transparency allowed).
    ios = os.path.join('ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    for name, size, scale in [('20x20@1x', 20, 1), ('20x20@2x', 20, 2), ('20x20@3x', 20, 3), ('29x29@1x', 29, 1),
                              ('29x29@2x', 29, 2), ('29x29@3x', 29, 3), ('40x40@1x', 40, 1), ('40x40@2x', 40, 2),
                              ('40x40@3x', 40, 3), ('60x60@2x', 60, 2), ('60x60@3x', 60, 3), ('76x76@1x', 76, 1),
                              ('76x76@2x', 76, 2), ('83.5x83.5@2x', 83.5, 2), ('1024x1024@1x', 1024, 1)]:
        px = int(round(size * scale))
        save(app_icon(px, rounded=False).convert('RGB'), ios, f'Icon-App-{name}.png')
    launch = os.path.join('ios', 'Runner', 'Assets.xcassets', 'LaunchImage.imageset')
    if os.path.isdir(os.path.join(ROOT, launch)):
        for name, px in [('LaunchImage.png', 120), ('LaunchImage@2x.png', 240), ('LaunchImage@3x.png', 360)]:
            save(app_icon(px), launch, name)

    # macOS.
    mac = os.path.join('macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    for px in (16, 32, 64, 128, 256, 512, 1024):
        save(app_icon(px), mac, f'app_icon_{px}.png')

    # Web.
    save(app_icon(192), 'web', 'icons', 'Icon-192.png')
    save(app_icon(512), 'web', 'icons', 'Icon-512.png')
    save(app_icon(192, rounded=False, padding=0.2), 'web', 'icons', 'Icon-maskable-192.png')
    save(app_icon(512, rounded=False, padding=0.2), 'web', 'icons', 'Icon-maskable-512.png')
    save(app_icon(64), 'web', 'favicon.png')

    # Windows.
    write_ico([app_icon(px) for px in (16, 24, 32, 48, 64, 128, 256)],
              os.path.join(ROOT, 'windows', 'runner', 'resources', 'app_icon.ico'))

    print('Brand assets written.')


if __name__ == '__main__':
    main()
