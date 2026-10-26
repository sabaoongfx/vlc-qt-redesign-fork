#!/usr/bin/env python3
"""Checks over a redesign test run: QML warnings, colours, geometry, hover growth. Writes report.html."""
import sys, os, re, glob, html
from collections import Counter
from PIL import Image

OUT = sys.argv[1]
ACCENT = (0xD3, 0x79, 0x18)
failures, passes = [], []


def ok(scene, what):
    passes.append((scene, what))


def fail(scene, what):
    failures.append((scene, what))


def near(a, b, tol=6):
    return all(abs(x - y) <= tol for x, y in zip(a, b))


def hexc(c):
    return '#%02X%02X%02X' % c[:3]


def img(scene, tag='a'):
    p = f'{OUT}/{scene}-{tag}.png'
    return Image.open(p).convert('RGB') if os.path.exists(p) else None


def geom(scene, tag='a'):
    p = f'{OUT}/{scene}-{tag}.geom'
    rows = {}
    if os.path.exists(p):
        for line in open(p):
            parts = line.rstrip('\n').split('\t')
            if len(parts) == 6:
                rows.setdefault(parts[0], []).append(tuple(map(int, parts[2:])))
    return rows


def pixels(im):
    # Pillow 12 deprecates getdata()
    return im.get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata()


def dominant(im, box):
    return Counter(pixels(im.crop(box))).most_common(1)[0][0]


def count_color(im, box, color, tol=12):
    return sum(1 for p in pixels(im.crop(box)) if near(p, color, tol))


# 1. QML warnings / errors in every log
for log in sorted(glob.glob(f'{OUT}/*.log')):
    scene = os.path.basename(log)[:-4]
    if scene.startswith('fixture'):
        continue
    bad = sorted({l.strip()[-160:] for l in open(log, errors='replace') if re.search(r'\.qml:\d+', l)})
    if bad:
        for b in bad[:6]:
            fail(scene, 'QML: ' + b)
    else:
        ok(scene, 'no QML warnings')

# 2. player bar: play pill colour and size, seek handle colour, seek fill colour
for scene in ('player-playing', 'player-paused', 'player-day', 'player-system'):
    im = img(scene)
    if not im:
        continue
    c = dominant(im, (70, 1042, 112, 1062))
    (ok if near(c, ACCENT, 2) else fail)(scene, f'play pill colour {hexc(c)} (want #D37918)')
    g = geom(scene).get('Play/Pause')
    if g:
        x, y, w, h = g[0]
        (ok if (w, h) == (54, 28) else fail)(scene, f'play pill size {w}x{h} (want 54x28)')
    n = count_color(im, (200, 1030, 1600, 1076), ACCENT, 4)
    (ok if 100 <= n <= 400 else fail)(scene, f'seek handle accent pixels {n} (want an 8x24 bar)')

im = img('player-paused')
if im:
    row = [im.getpixel((x, 1052)) for x in range(240, 1600)]
    fill = Counter(p for p in row if p[0] > p[2] + 20 and p[0] < 120).most_common(1)
    if fill:
        (ok if near(fill[0][0], (0x37, 0x1F, 0x06), 3) else fail)('player-paused', f'seek fill {hexc(fill[0][0])} (want #371F06)')

# 3. hover must not blow up the seek handle (the "big square" bug)
im = img('player-seekhover')
if im:
    n = count_color(im, (200, 960, 1600, 1076), ACCENT, 4)
    (ok if n <= 400 else fail)('player-seekhover', f'accent pixels around the seek bar while hovering: {n} (want <= 400)')

# 4. right panel: Figma colours
im = img('panel-tabs', 'subs')
if im:
    W = im.size[0]
    c = dominant(im, (W - 300, 60, W - 120, 70))
    (ok if near(c, (0x09, 0x09, 0x09), 3) else fail)('panel-tabs', f'tab bar {hexc(c)} (want #090909)')
    c = dominant(im, (W - 380, 1010, W - 40, 1020))
    (ok if near(c, (0x09, 0x09, 0x09), 3) else fail)('panel-tabs', f'footer {hexc(c)} (want #090909)')

# 5. idle mini player / library after the end of playback: no loading animation, no placeholders
im = img('lib-after-end')
if im:
    n = count_color(im, (200, 1030, 1900, 1080), ACCENT, 4)
    (ok if n < 2000 else fail)('lib-after-end', f'accent pixels in the bottom row after the end: {n}')

# 6. the resume prompt must not replace the top bar
g = geom('resume-prompt', 'b')
if g:
    crumb = [k for k in g if k.startswith('Back to ')]
    (ok if crumb else fail)('resume-prompt', 'folder crumb visible while the resume prompt is shown')
    (ok if 'Continue' in g else fail)('resume-prompt', 'resume prompt shown')

# 7. mini player card: the video corners are rounded (covered in the card colour)
im, g = img('lib-mini-video'), geom('lib-mini-video')
if im and g.get('video content') and g.get('Mini player'):
    x, y, w, h = g['video content'][0]
    card = im.getpixel((g['Mini player'][0][0] + 4, y + h // 2))
    corners = [im.getpixel(p) for p in ((x, y), (x + w - 1, y), (x, y + h - 1), (x + w - 1, y + h - 1))]
    (ok if all(near(c, card, 8) for c in corners) else fail)('lib-mini-video', f'video corners {[hexc(c) for c in corners]} (want the card colour {hexc(card)})')

# 8. Customize Player: Figma header band and body colours (dark)
im = img('customize')
if im:
    c = dominant(im, (300, 5, 700, 15))
    (ok if near(c, (0x09, 0x09, 0x09), 3) else fail)('customize', f'header {hexc(c)} (want #090909)')
    c = dominant(im, (300, 580, 700, 600))
    (ok if near(c, (0x0E, 0x0E, 0x0E), 3) else fail)('customize', f'body {hexc(c)} (want #0F0F0F)')

# 9. browse folder header like the library header: back/forward, path crumbs, item count, + button
g = geom('browse-folder', 'deep')
if g:
    for name in ('Back', 'Forward', 'The Wand', 'S01', '12 items'):
        (ok if name in g else fail)('browse-folder', f'header shows "{name}"')
    b = g.get('Add to medialibrary') or g.get('Remove from medialibrary')
    (ok if b and b[0][2] <= 40 else fail)('browse-folder', f'media library button is an icon ({b[0][2] if b else "missing"} px wide)')

# 10. saving after visiting the new settings pages changes no option
saved = glob.glob(f'{OUT}/profiles/prefs-save.*/config/vlc/vlcrc')
if saved:
    fixture = os.path.join(os.environ.get('FIX', os.path.join(os.path.dirname(OUT), 'fixtures')), 'profile/config/vlc/vlcrc')
    def options(p):
        return {l.strip() for l in open(p, errors='replace') if l.strip() and not l.startswith(('#', '['))}
    (ok if os.path.getmtime(saved[0]) != os.path.getmtime(fixture) else fail)('prefs-save', 'Save wrote the configuration')
    added, removed = options(saved[0]) - options(fixture), options(fixture) - options(saved[0])
    (ok if not added and not removed else fail)('prefs-save', f'options unchanged after Save (added {sorted(added)[:6]}, removed {sorted(removed)[:6]})')

# 11. settings search: "cach" leaves the Network page with its buffering rows
g = geom('prefs-search')
if g:
    (ok if 'Local files' in g and 'Network' in g else fail)('prefs-search', 'search finds the buffering rows')
    (ok if 'General' not in g and 'Interface' not in g else fail)('prefs-search', 'categories without a match are hidden')

# 12. player bars measured on the Figma Player frame: 40px top bar, 55px bottom bar at y 1025,
#     28px controls centred in it, #1B1B1B bars
g, im = geom('player-playing'), img('player-playing')
if g and im:
    bar = g.get('Player controls')
    (ok if bar and abs(bar[0][1] - 1025) <= 1 and abs(bar[0][3] - 55) <= 1 else fail)('player-playing', f'bottom bar {bar[0][1:4:2] if bar else None} (want y 1025, 55 tall)')
    pill = g.get('Play/Pause')
    (ok if pill and abs(pill[0][1] - 1039) <= 1 else fail)('player-playing', f'play pill y {pill[0][1] if pill else None} (want 1039)')
    top = next((y for y in range(0, 80) if im.getpixel((40, y)) != im.getpixel((40, 0))), None)
    (ok if top is not None and abs(top - 40) <= 1 else fail)('player-playing', f'video starts at y {top} (want 40)')
    c = im.getpixel((600, 1075))
    (ok if near(c, (0x1B, 0x1B, 0x1B), 2) else fail)('player-playing', f'bar colour {hexc(c)} (want #1B1B1B)')

# 13. every scene produced its screenshots
for at in sorted(glob.glob(f'{OUT}/*.at')):
    scene = os.path.basename(at)[:-3]
    for line in open(at):
        if line.startswith('no match') or line.startswith('no action'):
            fail(scene, 'AT-SPI: ' + line.strip())

# report
rows = []
for scene in sorted({os.path.basename(p).rsplit('-', 1)[0] for p in glob.glob(f'{OUT}/*.png')} | {s for s, _ in failures}):
    shots = sorted(glob.glob(f'{OUT}/{scene}-*.png'))
    f = [w for s, w in failures if s == scene]
    p = [w for s, w in passes if s == scene]
    rows.append(f"<h2 class={'bad' if f else 'good'}>{html.escape(scene)}</h2>"
                + ''.join(f"<div class=bad>✗ {html.escape(x)}</div>" for x in f)
                + ''.join(f"<div class=good>✓ {html.escape(x)}</div>" for x in p)
                + ''.join(f"<a href='{os.path.basename(s)}'><img src='{os.path.basename(s)}'></a>" for s in shots))
open(f'{OUT}/report.html', 'w').write(
    "<!doctype html><meta charset=utf-8><title>Redesign test report</title><style>body{background:#111;color:#ddd;"
    "font:14px sans-serif;margin:24px}img{width:480px;margin:4px;border:1px solid #333}.bad{color:#f66}.good{color:#7c7}</style>"
    f"<h1>{len(failures)} failures, {len(passes)} passes</h1>" + ''.join(rows))
print(f'{len(failures)} failures, {len(passes)} passes')
for s, w in failures:
    print(f'FAIL {s}: {w}')
sys.exit(1 if failures else 0)
