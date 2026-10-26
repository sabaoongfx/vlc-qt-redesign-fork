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
    (ok if near(c, (0x0E, 0x0E, 0x0E), 3) else fail)('panel-tabs', f'footer {hexc(c)} (want #0E0E0E)')
    c = dominant(im, (W - 380, 700, W - 40, 720))
    (ok if near(c, (0x0E, 0x0E, 0x0E), 3) else fail)('panel-tabs', f'panel below the sections {hexc(c)} (want #0E0E0E)')

# 4b. right panel measured on the Figma Subtitles SVGs (panel-relative x, the panel top is y 40)
def accent_span(im, y, x0, x1):
    xs = [x for x in range(x0, x1) if near(im.getpixel((x, y)), ACCENT, 30)]
    return (min(xs), max(xs) + 1) if xs else None

def brightest(im, box):
    return max(pixels(im.crop(box)), key=sum)

g = geom('panel-tabs', 'subs')
combo = (g.get('Track 1 - [English]') or [None])[0]
if im and combo:
    px, py = combo[0] - 160, 40
    (ok if combo[2:] == (220, 48) else fail)('panel-tabs', f'dropdown {combo[2]}x{combo[3]} (want 220x48)')
    c = im.getpixel((combo[0] + 1, combo[1] + 24))
    (ok if near(c, (0x09, 0x09, 0x09), 3) else fail)('panel-tabs', f'dropdown ring {hexc(c)} (want #090909)')
    c = brightest(im, (combo[0] + 18, combo[1] + 14, combo[0] + 120, combo[1] + 34))
    (ok if near(c, (0x8F, 0x8F, 0x8F), 8) else fail)('panel-tabs', f'dropdown text {hexc(c)} (want #8F8F8F)')
    c = brightest(im, (px + 24, combo[1] + 14, px + 120, combo[1] + 34))
    (ok if near(c, (0x6B, 0x6B, 0x6B), 8) else fail)('panel-tabs', f'row label {hexc(c)} (want #6B6B6B)')
    span = accent_span(im, py + 49, px, px + 400)
    want = (294, 386)
    (ok if span and all(abs(a - px - b) <= 2 for a, b in zip(span, want)) else fail)(
        'panel-tabs', f'Subtitles underline x {span and (span[0] - px, span[1] - px)} (want {want})')
    for tag, want in (('video', (122, 192)), ('play', (14, 105))):
        t = img('panel-tabs', tag)
        span = t and accent_span(t, py + 49, px, px + 400)
        # the Playback label renders ~3px wider than in Figma
        (ok if span and all(abs(a - px - b) <= 3 for a, b in zip(span, want)) else fail)(
            'panel-tabs', f'{tag} underline x {span and (span[0] - px, span[1] - px)} (want {want})')
    t = img('panel-tabs', 'video')
    if t:
        # first dropdown row of the Video tab: chevron drawn at x 348-359
        xs = [x for x in range(px + 300, px + 400) for y in range(py + 110, py + 150) if sum(t.getpixel((x, y))) > 200]
        span = xs and (min(xs) - px, max(xs) - px + 1)
        (ok if span and abs(span[0] - 348) <= 1 and abs(span[1] - 360) <= 1 else fail)(
            'panel-tabs', f'dropdown chevron x {span} (want (348, 360))')

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

# 7. mini player card (Figma "Miniplayer"): the video corners are rounded into its 2px dark frame,
#    the card is 391x338 in the secondary window colour
im, g = img('lib-mini-video'), geom('lib-mini-video')
if im and g.get('video content') and g.get('Mini player'):
    x, y, w, h = g['video content'][0]
    frame = im.getpixel((x - 1, y + h // 2))
    corners = [im.getpixel(p) for p in ((x, y), (x + w - 1, y), (x, y + h - 1), (x + w - 1, y + h - 1))]
    (ok if near(frame, (0x09, 0x09, 0x09), 3) and all(near(c, frame, 8) for c in corners) else fail)(
        'lib-mini-video', f'video corners {[hexc(c) for c in corners]} in the frame {hexc(frame)} (want #090909)')
    cx, cy, cw, ch = g['Mini player'][0]
    (ok if abs(cw - 391) <= 2 and abs(ch - 338) <= 2 else fail)('lib-mini-video', f'card {cw}x{ch} (want 391x338)')
    c = im.getpixel((cx + 4, cy + ch - 20))
    (ok if near(c, (0x1B, 0x1B, 0x1B), 2) else fail)('lib-mini-video', f'card colour {hexc(c)} (want #1B1B1B)')

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

# 13. library grid measured on the Figma Player-4 frame: sidebar card x 8-208, 16:9 covers from x 237
#     20px apart, header separator at y 110, search field y 60-93, first covers at y 131
im = img('video-grid')
if im:
    bg = im.getpixel((1000, 1060))
    differs = lambda p, t=30: sum(abs(a - b) for a, b in zip(p, bg)) > t
    card = [x for x in range(0, 240) if im.getpixel((x, 600)) == im.getpixel((100, 600))]
    (ok if card and abs(card[0] - 8) <= 1 and abs(card[-1] - 208) <= 1 else fail)('video-grid', f'sidebar card x {card[0] if card else None}-{card[-1] if card else None} (want 8-208)')
    xs = [x for x in range(212, 1920) if differs(im.getpixel((x, 250)))]
    runs, s, p = [], None, None
    for x in xs:
        if s is None: s = p = x
        elif x - p > 3: runs.append((s, p)); s = x
        p = x
    if s is not None: runs.append((s, p))
    if len(runs) >= 2:
        w, gap = runs[0][1] - runs[0][0] + 1, runs[1][0] - runs[0][1] - 1
        (ok if abs(runs[0][0] - 237) <= 2 and abs(gap - 20) <= 2 else fail)('video-grid', f'first cover x {runs[0][0]}, gap {gap} (want 237, 20)')
        col = [y for y in range(100, 400) if differs(im.getpixel((runs[0][0] + w // 2, y)))]
        segs, s, p = [], None, None
        for y in col:
            if s is None: s = p = y
            elif y - p > 2: segs.append((s, p)); s = y
            p = y
        if s is not None: segs.append((s, p))
        cover = max(segs, key=lambda a: a[1] - a[0])
        h = cover[1] - cover[0] + 1
        (ok if abs(h - round(w * 9 / 16)) <= 2 else fail)('video-grid', f'cover {w}x{h} (want 16:9)')
        (ok if abs(cover[0] - 131) <= 2 else fail)('video-grid', f'first cover y {cover[0]} (want 131)')
    line = next((y for y in range(55, 125) if differs(im.getpixel((1000, y)), 6)), None)
    (ok if line is not None and abs(line - 110) <= 1 else fail)('video-grid', f'header separator y {line} (want 110)')

# 13b. menus measured on the Figma "menu" and "right-click menu" frames (card-relative x; RedesignMenuStyle)
def card_run(im, y, color, x0=0, x1=None, tol=2):
    """longest run of the card colour on row y"""
    best, start = (0, 0), None
    for x in range(x0, x1 or im.width):
        if near(im.getpixel((x, y)), color, tol):
            start = x if start is None else start
            if x - start + 1 > best[1] - best[0]: best = (start, x + 1)
        else:
            start = None
    return best

def ink_x(im, box, bg, tol=40):
    xs = [x for x in range(box[0], box[2]) for y in range(box[1], box[3])
          if sum(abs(a - b) for a, b in zip(im.getpixel((x, y)), bg)) > tol]
    return (min(xs), max(xs)) if xs else None

for scene, bg, label, shortcut in (('main-menu', (0x18, 0x18, 0x18), (0x8F, 0x8F, 0x8F), (0x6B, 0x6B, 0x6B)),
                                   ('main-menu-day', (0xE6, 0xE6, 0xE5), (0x6C, 0x6C, 0x6B), (0x90, 0x90, 0x90))):
    im = img(scene)
    if not im: continue
    # the menu opens under the top bar's menu button; its first row (Open File(s)) is centred 28px below the card top
    # between two rows; the Night card touches the sidebar card (same colour): anchor on the right edge,
    # the card-relative columns below then catch a wrong width. Day has a 1px border.
    L, R = card_run(im, 322, bg, 30, 600)
    if bg[0] >= 128:
        L, R = L - 1, R + 1
        (ok if R - L == 375 else fail)(scene, f'menu card width {R - L} (want 375)')
    (ok if R == 423 else fail)(scene, f'menu card right edge {R} (want 423, {hexc(bg)})')
    L = R - 375
    # the top bar fades into the Night card colour: the card starts where 8 rows match exactly
    T = next((y for y in range(10, 120) if all(im.getpixel((L + 200, y + i)) == bg for i in range(8))), None)
    if T is None:
        fail(scene, 'menu card top not found'); continue
    for k, name in ((0, 'Open File(s)'), (5, 'Convert')):
        cy = T + 28 + 48 * k
        ink = ink_x(im, (L + 46, cy - 12, L + 250, cy + 12), bg)
        (ok if ink and abs(ink[0] - L - 52) <= 1 else fail)(scene, f'{name} label x {ink and ink[0] - L} (want 52)')
        ink = ink_x(im, (L + 10, cy - 12, L + 46, cy + 12), bg)
        (ok if ink and 19 <= ink[0] - L <= 22 else fail)(scene, f'{name} icon x {ink and ink[0] - L} (want 19-22)')
        c = brightest(im, (L + 46, cy - 12, L + 250, cy + 12)) if bg[0] < 128 else min(pixels(im.crop((L + 46, cy - 12, L + 250, cy + 12))), key=sum)
        (ok if near(c, label, 6) else fail)(scene, f'{name} label {hexc(c)} (want {hexc(label)})')
        ink = ink_x(im, (R - 130, cy - 12, R - 4, cy + 12), bg)
        (ok if ink and abs(R - 1 - ink[1] - 18) <= 1 else fail)(scene, f'{name} shortcut right inset {ink and R - 1 - ink[1]} (want 18)')
        box = (R - 130, cy - 12, R - 4, cy + 12)
        c = brightest(im, box) if bg[0] < 128 else min(pixels(im.crop(box)), key=sum)
        (ok if near(c, shortcut, 6) else fail)(scene, f'{name} shortcut {hexc(c)} (want {hexc(shortcut)})')

im = img('rclick-menu')
if im:
    L, R = card_run(im, 500, (0x18, 0x18, 0x18), 900, 1400)
    (ok if R - L == 292 else fail)('rclick-menu', f'right-click card width {R - L} (want 292)')

# 14. every scene produced its screenshots
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
