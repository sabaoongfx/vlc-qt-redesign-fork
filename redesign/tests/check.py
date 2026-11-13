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

# 2. player bar: play pill colour and size (Figma "play": orange for play, grey #6B6B6B while it shows pause),
#    seek handle colour, seek fill colour
for scene in ('player-playing', 'player-paused', 'player-day', 'player-system'):
    im = img(scene)
    if not im:
        continue
    c = dominant(im, (70, 1042, 112, 1062))
    want = ACCENT if scene == 'player-paused' else (0x6B, 0x6B, 0x6B)
    (ok if near(c, want, 2) else fail)(scene, f'play pill colour {hexc(c)} (want {hexc(want)})')
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

# 4a. the play queue and the tracks panel are solid cards inside the stage: a gap under the top bar
# and right of them, the card colour inside (the queue was 80% opaque and touched the top bar)
for scene, tag, inside in (('queue-open', 'a', (0x0E, 0x0E, 0x0E)), ('panel-tabs', 'subs', (0x09, 0x09, 0x09))):
    t = img(scene, tag)
    if t:
        W = t.size[0]
        c = t.getpixel((W - 200, 44))
        (ok if not near(c, inside, 3) else fail)(scene, f'panel colour {hexc(c)} right under the top bar (want a gap)')
        # the stage is flush with the window: the card keeps an 8px gap to the window edge
        c = t.getpixel((W - 4, 500))
        (ok if not near(c, inside, 3) else fail)(scene, f'panel colour {hexc(c)} at the window edge (want a gap)')
        c = t.getpixel((W - 200, 60))
        (ok if near(c, inside, 3) else fail)(scene, f'panel {hexc(c)} (want solid {hexc(inside)})')

# 4b. right panel measured on the Figma Subtitles SVGs (panel-relative x and y; the panel top is the tab row's)
def accent_span(im, y, x0, x1):
    xs = [x for x in range(x0, x1) if near(im.getpixel((x, y)), ACCENT, 30)]
    return (min(xs), max(xs) + 1) if xs else None

def brightest(im, box):
    return max(pixels(im.crop(box)), key=sum)

g = geom('panel-tabs', 'subs')
combo = (g.get('Track 1 - [English]') or [None])[0]
if im and combo:
    tab = (g.get('Playback') or [None])[0]
    px, py = combo[0] - 160, tab[1] if tab else 40
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
    # the player resumes by itself (restore-playback-pos defaults to "always") and says so
    (ok if 'Start over' in g else fail)('resume-prompt', 'resumed notice with Start over shown')

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

# 9b. Videos is a folder tree: the first level lists the added folders, every level has the address
#     line (Videos > Shows > The Wand > S01) with back / forward, the season holds its 12 episodes
for shot, crumbs in (('root', ('Videos',)), ('videos', ('Videos',)), ('shows', ('Videos', 'Shows')),
                     ('season', ('Videos', 'Shows', 'The Wand', 'S01'))):
    g = geom('folder-tree', shot)
    if g:
        for name in ('Back', 'Forward') + crumbs:
            (ok if name in g else fail)('folder-tree', f'{shot}: header shows "{name}"')
g = geom('folder-tree', 'season')
if g:
    (ok if '12 items' in g else fail)('folder-tree', 'season: 12 items')

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

# 11b. switching to Day inside Settings restyles the open window completely: it matches a window
# opened in Day (stylesheets, sidebar icons and title colours were left in the old theme)
a, b = img('prefs-live-day', 'general'), img('prefs-day', 'general')
if a and b:
    from PIL import ImageChops
    n = sum(1 for p in ImageChops.difference(a.convert('RGB'), b.convert('RGB')).get_flattened_data() if max(p) > 24) \
        if a.size == b.size else -1
    (ok if n == 0 else fail)('prefs-live-day', f'{n} pixels differ from Settings opened in Day (want 0)')

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

def text_ink(im, box, bg):
    """the strongest text colour in box: the brightest on a dark background, the darkest on a light one"""
    return brightest(im, box) if bg[0] < 128 else min(pixels(im.crop(box)), key=sum)

# the main menu opens under the top bar's menu button: card x 48-423 (375 wide)
MAIN_MENU_RIGHT = 383  # under the "..." at x 19 (no cone before it since 2026-11-11)

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
    L, R = card_run(im, 322, bg, 0, 600)
    if bg[0] >= 128:
        L, R = L - 1, R + 1
        (ok if R - L == 375 else fail)(scene, f'menu card width {R - L} (want 375)')
    (ok if R == MAIN_MENU_RIGHT else fail)(scene, f'menu card right edge {R} (want {MAIN_MENU_RIGHT}, {hexc(bg)})')
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
        c = text_ink(im, (L + 46, cy - 12, L + 250, cy + 12), bg)
        (ok if near(c, label, 6) else fail)(scene, f'{name} label {hexc(c)} (want {hexc(label)})')
        ink = ink_x(im, (R - 130, cy - 12, R - 4, cy + 12), bg)
        (ok if ink and abs(R - 1 - ink[1] - 18) <= 1 else fail)(scene, f'{name} shortcut right inset {ink and R - 1 - ink[1]} (want 18)')
        c = text_ink(im, (R - 130, cy - 12, R - 4, cy + 12), bg)
        (ok if near(c, shortcut, 6) else fail)(scene, f'{name} shortcut {hexc(c)} (want {hexc(shortcut)})')

im = img('rclick-menu')
if im:
    L, R = card_run(im, 500, (0x18, 0x18, 0x18), 900, 1400)
    # 2026-11-13: a bit smaller than the 292 x 683 Figma frame (user request): 280 wide, 44px rows
    (ok if R - L == 280 else fail)('rclick-menu', f'right-click card width {R - L} (want 280)')
    # 627 tall (14 rows of 44, 4px padding, three 1px group lines #1D1D1D after Record, Hide UI and Subtitle):
    # the card is the continuous run of card pixels down from its top (the menu opens below the click now
    # that it fits; other #181818 pixels further down belong to the bottom bar)
    x = L + 150
    card_px = ((0x18, 0x18, 0x18), (0x1D, 0x1D, 0x1D))
    top = next((y for y in range(0, im.height) if im.getpixel((x, y))[:3] in card_px), None)
    col = []
    if top is not None:
        y = top
        while y < im.height and im.getpixel((x, y))[:3] in card_px:
            col.append(y); y += 1
    # the configured hotkey shown on the first row (Pause: Space), in the shortcut colour
    c = brightest(im, (R - 80, (top or 0) + 10, R - 4, (top or 0) + 38))
    (ok if near(c, (0x6B, 0x6B, 0x6B), 6) else fail)('rclick-menu', f'Pause hotkey hint {hexc(c)} (want #6B6B6B)')
    lines = [y - top for y in col if im.getpixel((x, y))[:3] == (0x1D, 0x1D, 0x1D)] if col else []
    (ok if col and max(col) - top + 1 == 627 else fail)('rclick-menu', f'right-click card height {col and max(col) - top + 1} (want 627)')
    (ok if lines == [224, 269, 446] else fail)('rclick-menu', f'right-click group lines {lines} (want [224, 269, 446])')

# 13c. settings window chrome measured on the Figma "Settings - audio" frame (window coordinates)
im = img('prefs-cats', 'audio')
if im:
    for what, xy, want in (('header band', (600, 20), (0x09, 0x09, 0x09)), ('window body', (600, 70), (0x0E, 0x0E, 0x0E)),
                           ('sidebar card', (100, 300), (0x18, 0x18, 0x18)), ('search field', (150, 14), (0x14, 0x14, 0x14))):
        c = im.getpixel(xy)
        (ok if near(c, want, 2) else fail)('prefs-cats', f'{what} {hexc(c)} (want {hexc(want)})')
    card = im.getpixel((100, 300))
    top = next((y for y in range(40, 80) if im.getpixel((100, y)) == card), None)
    (ok if top == 58 else fail)('prefs-cats', f'sidebar card top {top} (want 58)')
    left = next((x for x in range(0, 40) if im.getpixel((x, 300)) == card), None)
    (ok if left == 8 else fail)('prefs-cats', f'sidebar card x {left} (want 8)')
    ink = ink_x(im, (215, 8, 600, 44), im.getpixel((600, 20)))
    (ok if ink and abs(ink[0] - 240) <= 1 else fail)('prefs-cats', f'page title x {ink and ink[0]} (want 240)')
    c = brightest(im, (215, 8, 600, 44))
    (ok if near(c, (0x96, 0x96, 0x96), 6) else fail)('prefs-cats', f'page title {hexc(c)} (want #969696)')
    # General (first row, centre y 125) and the current row Audio (y 454, label #EAEAEA)
    for name, cy, want in (('General', 125, (0x8F, 0x8F, 0x8F)), ('Audio', 454, (0xEA, 0xEA, 0xEA))):
        bg = im.getpixel((180, cy))
        ink = ink_x(im, (46, cy - 6, 180, cy + 6), bg)
        (ok if ink and abs(ink[0] - 58) <= 1 else fail)('prefs-cats', f'{name} label x {ink and ink[0]} (want 58)')
        c = brightest(im, (46, cy - 6, 180, cy + 6))
        (ok if near(c, want, 6) else fail)('prefs-cats', f'{name} label {hexc(c)} (want {hexc(want)})')
    ink = ink_x(im, (215, 60, 400, 105), im.getpixel((600, 70)))
    (ok if ink and abs(ink[0] - 240) <= 1 else fail)('prefs-cats', f'Output section x {ink and ink[0]} (want 240)')

# 13d. player behaviour (2026-11-13): checks that the action had its effect
BAR = (0x1B, 0x1B, 0x1B)

# bars-idle: in a normal window, 10 s without a pointer move hides both bars and the video fills the
# window; a move shows the bars over it; 10 s later they are hidden again
for tag, bars in (('t0', True), ('idle', False), ('moved', True), ('hidden', False)):
    t = img('bars-idle', tag)
    if t:
        top = dominant(t, (300, 4, 1700, 36))
        (ok if near(top, BAR, 4) == bars else fail)('bars-idle', f'{tag}: top strip {hexc(top)} (want {"the bar" if bars else "the video"})')
        bottom = dominant(t, (300, 1030, 1700, 1076))
        dark = max(bottom) < 0x30
        (ok if dark == bars else fail)('bars-idle', f'{tag}: bottom strip {hexc(bottom)} (want {"the bar" if bars else "the video"})')

# rail-move: the picture does not move when the left menu is shown or hidden
def picture_x(im, y=500):
    # first x of the test picture's red column (the letterbox and the rail are dark)
    return next((x for x in range(im.size[0]) if im.getpixel((x, y))[0] > 200 and im.getpixel((x, y))[1] < 60), None)

a, b = img('rail-move', 'with'), img('rail-move', 'without')
if a and b:
    xa, xb = picture_x(a), picture_x(b)
    (ok if xa is not None and xa == xb else fail)('rail-move', f'picture starts at x {xa} with the left menu, {xb} without (want the same)')
    c = dominant(a, (4, 300, 40, 700))
    (ok if max(c) < 0x30 else fail)('rail-move', f'rail strip {hexc(c)} (want the dark rail over the video)')

# queue-click: one click on the second queue row plays it (the accent marker moves to that row)
t = img('queue-click', 'a')
if t:
    row1 = count_color(t, (1612, 160, 1622, 186), ACCENT, 40)
    row2 = count_color(t, (1612, 196, 1622, 222), ACCENT, 40)
    (ok if row2 > 0 and row1 == 0 else fail)('queue-click', f'playing marker: {row1}px on row 1, {row2}px on row 2 (want only row 2)')

# queue-around: E06 plays, the folder E01-E12 is queued: E06 is the sixth row of the queue card
# (accent title), not the first
t = img('queue-around', 'after')
if t:
    # tight tolerance: the white titles' anti-aliased edges come within 60 of the accent
    rows = [count_color(t, (1556, 462 + 40 * i, 1700, 484 + 40 * i), ACCENT, 25) for i in range(6)]
    (ok if rows[5] > 40 and max(rows[:5]) < 20 else fail)('queue-around', f'accent title pixels per queue row {rows} (want only the sixth)')

# 13e. player tests (2026-11-13): each asserts that the action had its effect
def values(scene, tag):
    # at.py values: sliders (name -> current) and labels (the times are labels such as 00:07)
    p = f'{OUT}/{scene}-{tag}.values'
    sliders, labels = {}, []
    if os.path.exists(p):
        for line in open(p):
            f = line.rstrip('\n').split('\t')
            if len(f) == 5:
                sliders[f[0]] = float(f[2])
            elif len(f) == 4 and f[1] == 'label':
                labels.append((f[0], int(f[2]), int(f[3])))
    return sliders, labels

def bar_times(scene, tag):
    # the elapsed (left of the seek bar) and total (right) times, in seconds
    _, labels = values(scene, tag)
    t = sorted((x, n) for n, x, y in labels if re.fullmatch(r'\d\d:\d\d', n) and y > 1000)
    secs = lambda n: int(n[:2]) * 60 + int(n[3:])
    return (secs(t[0][1]), secs(t[-1][1])) if len(t) >= 2 else (None, None)

def controls(scene, tag):
    # the ctl file of a shot: name -> flags ('c' checked)
    p = f'{OUT}/{scene}-{tag}.ctl'
    out = {}
    if os.path.exists(p):
        for line in open(p):
            f = line.rstrip('\n').split('\t')
            if len(f) >= 3 and not line.startswith('#'):
                out.setdefault(f[1], f[2])
    return out

def card_rows(g):
    # buttons inside the library card, below its header (x 60-430, y 150+)
    return [n for n, boxes in g.items() for (x, y, w, h) in boxes if 60 <= x < 430 and 150 <= y < 1000]

# card-sections: crumb per section, and the row that proves the right content loaded
for tag, crumb, row in (('home', 'Home', None), ('videos', 'Videos', 'Videos'), ('music', 'Music', 'Music'),
                        ('network', 'Network', 'Add Network Stream'), ('playlists', 'Playlists', 'Create playlist'),
                        ('recent', 'Recent', None)):
    if not os.path.exists(f'{OUT}/card-sections.log'):
        break
    g = geom('card-sections', tag)
    if not g:
        fail('card-sections', f'{tag}: no geometry'); continue
    has_crumb = any(140 <= x < 300 and y < 100 for x, y, w, h in g.get(crumb, []))
    (ok if has_crumb else fail)('card-sections', f'{tag}: card header says "{crumb}"')
    if row:
        rows = card_rows(g)
        (ok if row in rows else fail)('card-sections', f'{tag}: card lists "{row}" (rows: {", ".join(sorted(set(rows))[:6])})')
# the Music section must not list the video folders (seen 2026-11-13: it listed "Videos")
g = geom('card-sections', 'music')
if g:
    (ok if 'Videos' not in card_rows(g) else fail)('card-sections', 'music: the Videos folder is not listed under Music')

# card-play: S01 lists its episodes, a click on E02 plays it (top bar: Back to S01, window title)
g = geom('card-play', 's01')
if g:
    (ok if 'The_Wand_S01E02' in card_rows(g) else fail)('card-play', 'S01 lists The_Wand_S01E02')
g = geom('card-play', 'a')
if g:
    (ok if 'Back to S01' in g else fail)('card-play', 'the clicked episode plays (top bar "Back to S01")')

# lib-button: rail shown, the library button hides it, U shows it, U hides it
RAIL = ('Home', 'Recent', 'Add item')
def rail_shown(tag):
    g = geom('lib-button', tag)
    return sum(1 for n in RAIL for (x, y, w, h) in g.get(n, []) if x < 50) == len(RAIL)
if geom('lib-button', 'shown'):
    for tag, want, what in (('shown', True, 'at start'), ('a', False, 'after the library button'),
                            ('b', True, 'after U'), ('c', False, 'after U again')):
        (ok if rail_shown(tag) == want else fail)('lib-button', f'rail {"shown" if want else "hidden"} {what}')

# drag-to-queue: the queue had 1 element, a dragged row makes 2 (long_movie.mp4 added)
def queue_count(g):
    m = [re.match(r'(\d+) elements?', n) for n in g]
    return next((int(x.group(1)) for x in m if x), None)
a, b = geom('drag-to-queue', 'a'), geom('drag-to-queue', 'b')
if a and b:
    ca, cb = queue_count(a), queue_count(b)
    (ok if ca == 1 and cb == 2 and 'long_movie.mp4' in b else fail)('drag-to-queue', f'queue {ca} -> {cb} elements, long_movie.mp4 {"queued" if "long_movie.mp4" in b else "missing"} (want 1 -> 2)')

# queue-reorder: short.mp4 was second, after the drag it is first
def queue_order(g):
    rows = sorted((y, n) for n, boxes in g.items() for (x, y, w, h) in boxes
                  if n.endswith('.mp4') and 1600 <= x < 1640 and 100 < y < 800)
    return [n for _, n in rows]
a, b = geom('queue-reorder', 'a'), geom('queue-reorder', 'b')
if a and b:
    oa, ob = queue_order(a), queue_order(b)
    (ok if oa == ['sample.mp4', 'short.mp4'] and ob == ['short.mp4', 'sample.mp4'] else fail)('queue-reorder', f'order {oa} -> {ob} (want the two swapped)')

# transport: +10 s, -10 s, Next (short.mp4, 4 s long), Previous (sample.mp4, 2 min)
t0, fwd, back = (bar_times('transport', t) for t in ('a', 'fwd', 'back'))
if not os.path.exists(f'{OUT}/transport.log'):
    pass
elif t0[0] is not None and fwd[0] is not None and back[0] is not None:
    (ok if 8 <= fwd[0] - t0[0] <= 12 else fail)('transport', f'Step forward: {t0[0]} s -> {fwd[0]} s (want +10)')
    (ok if 7 <= fwd[0] - back[0] <= 12 else fail)('transport', f'Step back: {fwd[0]} s -> {back[0]} s (want -10)')
else:
    fail('transport', 'no times read under the seek bar')
nx, pv = bar_times('transport', 'next'), bar_times('transport', 'prev')
if os.path.exists(f'{OUT}/transport.log'):
    (ok if nx[1] == 4 else fail)('transport', f'Next: total time {nx[1]} s (want 4, short.mp4)')
    (ok if pv[1] == 120 else fail)('transport', f'Previous: total time {pv[1]} s (want 120, sample.mp4)')

# keys-fullscreen: bars hidden in the middle, still hidden after a seek key, shown by Tab; the seek moved on
if os.path.exists(f'{OUT}/keys-fullscreen-a.ctl'):
    for tag, want in (('a', False), ('seek', False), ('tab', True)):
        shown = 'Play/Pause' in controls('keys-fullscreen', tag)
        (ok if shown == want else fail)('keys-fullscreen', f'{tag}: bars {"shown" if shown else "hidden"} (want {"shown" if want else "hidden"})')
    el, _ = bar_times('keys-fullscreen', 'tab')
    # started ~9 s before Tab; Right adds 10 s
    (ok if el is not None and el >= 15 else fail)('keys-fullscreen', f'time after Right: {el} s (want 15 or more: the key seeked)')

# resume-start: the second play continues past the start, says so, and Start over goes back
g = geom('resume-start-2', 'a')
if g:
    (ok if any(n.startswith('Continued from') for n in g) and 'Start over' in g else fail)('resume-start-2', '"Continued from" and Start over shown')
    a, b = bar_times('resume-start-2', 'a'), bar_times('resume-start-2', 'b')
    (ok if a[0] is not None and a[0] >= 10 else fail)('resume-start-2', f'continued at {a[0]} s (want 10 or more)')
    (ok if b[0] is not None and b[0] <= 3 else fail)('resume-start-2', f'Start over: {b[0]} s (want 3 or less)')

# auto-subs: with the English audio no subtitle is on; the French audio turns Track 1 on
e, f_ = controls('auto-subs', 'eng'), controls('auto-subs', 'fra')
if e and f_:
    # (the None row does not report itself checked: no track ticked means None)
    (ok if not any('c' in v for k, v in e.items() if k.startswith('Track ')) else fail)('auto-subs', 'English audio: no subtitle on')
    (ok if 'c' in f_.get('Track 1 - [English]', '') else fail)('auto-subs', 'French audio: subtitle Track 1 turned on')

# mini-queue: the card lists both items; a click on short.mp4 opens the player on it
a, b = geom('mini-queue', 'a'), geom('mini-queue', 'b')
if a:
    (ok if any(n.startswith('2 items') for n in a) and 'short.mp4' in a else fail)('mini-queue', 'queue card lists 2 items')
if b:
    (ok if 'short.mp4' in b and b['short.mp4'][0][:2] == (0, 0) and 'Player topbar' in b else fail)('mini-queue', 'a click on short.mp4 plays it in the player')

# titlebar-drawn: VLC's own window buttons in the top bar
g = geom('titlebar-drawn', 'a')
if g:
    for n in ('Minimize', 'Close'):
        (ok if any(y < 40 for x, y, w, h in g.get(n, [])) else fail)('titlebar-drawn', f'{n} button in the top bar')

# unpinned: no bar with the pointer in the middle, the control bar near the bottom edge
a, b = controls('unpinned', 'a'), controls('unpinned', 'b')
if os.path.exists(f'{OUT}/unpinned-a.ctl'):
    (ok if 'Play/Pause' not in a else fail)('unpinned', 'pointer in the middle: no bar')
    (ok if 'Play/Pause' in b else fail)('unpinned', 'pointer at the bottom: the control bar')

# enter-fullscreen: Enter enters fullscreen (top bar hidden), keypad Enter leaves it
gs = [geom('enter-fullscreen', t) for t in ('win', 'on', 'off')]
if all(gs):
    (ok if 'Player topbar' in gs[0] and 'Player topbar' not in gs[1] and 'Player topbar' in gs[2] else fail)(
        'enter-fullscreen', 'Enter: fullscreen (no top bar), keypad Enter: back')

# edge-bars: fullscreen, pointer in the middle = no bar, at the top = only the top bar, at the bottom = only the control bar
if os.path.exists(f'{OUT}/edge-bars-mid.ctl'):
    for tag, top, bottom in (('mid', False, False), ('top', True, False), ('mid2', False, False), ('bottom', False, True)):
        c = controls('edge-bars', tag)
        got = ('Fullscreen' in c, 'Play/Pause' in c)
        (ok if got == (top, bottom) else fail)('edge-bars', f'{tag}: top bar {got[0]}, control bar {got[1]} (want {top}, {bottom})')

# tracks-picker: three tabs and the subtitle tracks
c = controls('tracks-picker', 'subs')
if c:
    for n in ('Video', 'Audio', 'Subtitles', 'None', 'Track 1 - [English]', 'Track 2 - [French]'):
        (ok if n in c else fail)('tracks-picker', f'"{n}" in the picker')

# effects panels: their sliders are there (the two of the control bar not counted)
for scene, tag, least in (('effects-audio', 'eq', 10), ('effects-audio', 'compressor', 7),
                          ('effects-video', 'essential', 6), ('effects-video', 'colors', 3)):
    p = f'{OUT}/{scene}-{tag}.ctl'
    if os.path.exists(p):
        n = sum(1 for l in open(p) if l.startswith('slider\t')) - 2
        (ok if n >= least else fail)(scene, f'{tag}: {n} sliders (want {least} or more)')

# 13f. library tests (2026-11-13): each asserts that the action had its effect
def geom_rows(scene, tag):
    # (name, role, x, y, w, h) in tree order; the first frame is the main window, named after what plays
    p = f'{OUT}/{scene}-{tag}.geom'
    rows = []
    if os.path.exists(p):
        for line in open(p):
            f = line.rstrip('\n').split('\t')
            if len(f) == 6:
                rows.append((f[0], f[1], *map(int, f[2:])))
    return rows

def window_title(scene, tag):
    return next((n for n, r, *_ in geom_rows(scene, tag) if r == 'frame'), None)

def playing(scene, tag, name=None):
    # the player view is open (its top bar) and, if given, the window is named after that file
    g = geom(scene, tag)
    t = window_title(scene, tag) or ''
    return bool(g) and 'Player topbar' in g and (name is None or t.startswith(name))

def cells(scene, tag):
    # the library grid's items: table cells, left to right then top to bottom
    return [n for n, r, x, y, w, h in sorted(geom_rows(scene, tag), key=lambda r: (r[3], r[2])) if r == 'table cell']

def last_crumb(scene, tag):
    # the address line: crumb buttons on the header row (y 55-75, right of back/forward)
    crumbs = [(x, n) for n, r, x, y, w, h in geom_rows(scene, tag) if r == 'button' and 55 <= y <= 75 and 300 <= x < 1300]
    return max(crumbs)[1] if crumbs else None

def check(scene, cond, what):
    (ok if cond else fail)(scene, what)

# playlists
if geom('pl-play', 'a'):
    check('pl-play', playing('pl-play', 'a', 'long_movie'), f'Play: the player opens on the first item (window "{window_title("pl-play", "a")}")')
    check('pl-play', any(n.startswith('2 elements') for n in geom('pl-play', 'q')), 'Play: the queue holds the 2 items of the playlist')
if geom('pl-shuffle', 'a'):
    check('pl-shuffle', playing('pl-shuffle', 'a'), 'Shuffle: the player opens')
    check('pl-shuffle', any(n.startswith('2 elements') for n in geom('pl-shuffle', 'q')), 'Shuffle: the queue holds the 2 items')
if os.path.exists(f'{OUT}/pl-export.log'):
    m3u = f'{OUT}/pl-export.m3u'
    text = open(m3u, errors='replace').read() if os.path.exists(m3u) else ''
    check('pl-export', text.startswith('#EXTM3U') and 'long_movie' in text and 'Sample%20Movie' in text.replace('Sample Movie', 'Sample%20Movie'),
          f'Export Playlist wrote an M3U with both videos ({len(text)} bytes)')
if geom('pl-addqueue', 'q'):
    # sample.mp4 plays; the playlist's two videos are queued after it
    check('pl-addqueue', any(n.startswith('3 items') for n in geom('pl-addqueue', 'q')), 'Add to Queue: the mini player queue card lists 3 items (1 playing + the 2 of the playlist)')
if geom('pl-rename', 'a'):
    c = cells('pl-rename', 'a')
    check('pl-rename', 'Holiday' in c and 'Road_Trip' not in c, f'Rename: the card is called Holiday (cards: {c})')
if geom('pl-delete', 'a'):
    b, a = cells('pl-delete', 'before'), cells('pl-delete', 'a')
    check('pl-delete', 'Road_Trip' in b and 'Road_Trip' not in a, f'Delete (Yes): Road_Trip gone ({b} -> {a})')
if geom('pl-new-files', 'a'):
    # the playlist's page lists its media as rows (labels), not grid cards
    rows = [n for n, r, x, y, w, h in geom_rows('pl-new-files', 'a') if y > 120 and x > 209]
    check('pl-new-files', any(n.startswith('short') for n in rows), 'New Playlist with a chosen file: its page lists short.mp4')

# folder '...' menu
if geom('fm-add-file', 'a'):
    check('fm-add-file', playing('fm-add-file', 'a', 'short'), f'Add File: short.mp4 plays (window "{window_title("fm-add-file", "a")}")')
if geom('fm-add-folder', 'a'):
    check('fm-add-folder', 'fixtures' in cells('fm-add-folder', 'a'), f'Add Folder: the fixtures folder is in the library ({cells("fm-add-folder", "a")})')
if geom('fm-resync', 'a'):
    check('fm-resync', cells('fm-resync', 'a') == cells('fm-resync', 'before') and cells('fm-resync', 'a'),
          f'Resync: the library still lists {cells("fm-resync", "before")} (now {cells("fm-resync", "a")})')
c = controls('fm-subtitle', 'a')
if os.path.exists(f'{OUT}/fm-subtitle-a.ctl'):
    check('fm-subtitle', any(k.startswith('Track') for k in c), f'Edit Subtitle Tracks: a subtitle track is listed ({[k for k in c if k.startswith("Track")]})')
c = controls('fm-audio', 'a')
if os.path.exists(f'{OUT}/fm-audio-a.ctl'):
    tracks = [k for k in c if k.startswith('Track')]
    check('fm-audio', len(tracks) >= 2, f'Edit Audio Tracks: a second audio track is listed ({tracks})')
if geom('fm-info', 'a'):
    check('fm-info', any('Information' in n for n, *_ in geom_rows('fm-info', 'a')), 'Info opens the Media Information window')

# Back/Forward up and down
if geom('nav-updown', 'wand'):
    got = [last_crumb('nav-updown', t) for t in ('wand', 'b1', 'b2', 'f1')]
    check('nav-updown', got == ['The Wand', 'Shows', 'Videos', 'Shows'], f'address line {got} (want The Wand, Back Shows, Back Videos, Forward Shows)')

# Music folder tree
if geom('music-folder', 'root'):
    check('music-folder', 'Music' in cells('music-folder', 'root') and '6 songs' in geom('music-folder', 'root'), 'Music lists the Music folder with 6 songs')
    check('music-folder', len(cells('music-folder', 'a')) == 6, f'the Music folder lists its 6 songs ({cells("music-folder", "a")})')
    check('music-folder', playing('music-folder', 'play'), 'a click on a song plays it')

# Continue Watching > Remove from list
if geom('cw-remove-2', 'a'):
    cw = lambda tag: 'Continue Watching' in geom('cw-remove-2', tag) and 'long_movie' in cells('cw-remove-2', tag)
    check('cw-remove-2', cw('a'), 'Home lists long_movie under Continue Watching')
    check('cw-remove-2', not cw('b'), 'Remove from list takes it off')

# search and sort inside a folder
if geom('search-filter', 'b'):
    a, b = cells('search-filter', 'a'), cells('search-filter', 'b')
    check('search-filter', 'long_movie' in a and b == ['Sample Movie'], f'"Sample" filters {a} to {b} (want only Sample Movie)')
if geom('sort-za', 'b'):
    a, b = cells('sort-za', 'a'), cells('sort-za', 'b')
    order = lambda c: [n for n in c if n in ('long_movie', 'Sample Movie')]
    check('sort-za', order(a) == ['long_movie', 'Sample Movie'] and order(b) == ['Sample Movie', 'long_movie'], f'Title Z-A: {order(a)} -> {order(b)}')

# file menu
if geom('video-ctx-play', 'a'):
    check('video-ctx-play', playing('video-ctx-play', 'a', 'long_movie'), f'Play plays long_movie (window "{window_title("video-ctx-play", "a")}")')
for scene, word in (('video-stream', 'Stream'), ('video-convert', 'Convert')):
    if geom(scene, 'a'):
        check(scene, any(word in n and r in ('frame', 'dialog', 'window') for n, r, *_ in geom_rows(scene, 'a')), f'{word} opens its window')
# Convert: a profile is chosen (an empty Profile box means Start can never be used)
p = f'{OUT}/video-convert-a.ctl'
if os.path.exists(p):
    combos = [l.split('\t')[1] for l in open(p) if l.startswith('combo box\t')]
    check('video-convert', any(c.strip() for c in combos), f'Convert has a profile selected (combo boxes: {combos})')
if geom('folder-ctx-play', 'after'):
    check('folder-ctx-play', playing('folder-ctx-play', 'after', 'The_Wand_S01E01'), f'folder Play starts its first video (window "{window_title("folder-ctx-play", "after")}")')
if geom('open-network', 'a'):
    check('open-network', any('Network' in n for n in geom('open-network', 'a')), 'Open Network Stream opens its dialog')

# Home and Music pages
g = geom('home-night', 'a')
if g:
    check('home-night', 'New Videos' in g and 'New Music' in g, 'Home shows New Videos and New Music')
    check('home-night', sum(1 for n in cells('home-night', 'a') if n.startswith('The_Wand')) >= 5, 'New Videos lists the episodes')
g = geom('music-albums', 'a')
if g:
    check('music-albums', 'Music' in cells('music-albums', 'a') and '6 songs' in g, 'the Music page lists the Music folder (6 songs)')

# Network page
if geom('net-play', 'a'):
    check('net-play', playing('net-play', 'a', 'sample'), f'Add Stream + Play plays the stream (window "{window_title("net-play", "a")}")')
if geom('net-save', 'saved'):
    check('net-save', any('short' in n for n, r, x, y, w, h in geom_rows('net-save', 'saved') if y > 120), 'Save lists the stream on the Network page')
    check('net-save', playing('net-save', 'play', 'short'), 'a click on the saved stream plays it')

# audio button menu
t = img('audio-menu-switch', 'a')
if t:
    # the accent tick left of the row (the Audio tab's radio buttons report no checked state)
    eng = count_color(t, (1515, 646, 1560, 686), ACCENT, 40)
    fra = count_color(t, (1515, 690, 1560, 730), ACCENT, 40)
    check('audio-menu-switch', fra > 3 and eng == 0, f'Track 2 in the audio menu switches the audio to French (tick pixels: English {eng}, French {fra})')
    # and screen readers are told: the row reports itself checked (test-findings: it did not)
    c = controls('audio-menu-switch', 'a')
    check('audio-menu-switch', 'c' in c.get('Track 2 - [French]', '') and 'c' not in c.get('Track 1 - [English]', ''),
          f'screen readers see Track 2 checked (flags: English "{c.get("Track 1 - [English]")}", French "{c.get("Track 2 - [French]")}")')

# output devices (sound:null): the current device is ticked, the tick follows a change; volume at start
def device_ticks(scene, tag):
    # {device: accent tick pixels left of its row} for the two null outputs in the picker
    t, rows = img(scene, tag), geom_rows(scene, tag)
    out = {}
    if t:
        for n, r, x, y, w, h in rows:
            if n in ('Test Speakers', 'Test Headphones') and x > 1400 and h >= 20:
                out[n] = max(out.get(n, 0), count_color(t, (x, y, min(x + 60, t.size[0]), y + h), ACCENT, 40))
    return out
if os.path.exists(f'{OUT}/audio-device-tick.log'):
    a, b = device_ticks('audio-device-tick', 'a'), device_ticks('audio-device-tick', 'b')
    check('audio-device-tick', set(a) == {'Test Speakers', 'Test Headphones'}, f'the picker lists both outputs ({sorted(a)})')
    check('audio-device-tick', a.get('Test Speakers', 0) > 3 and a.get('Test Headphones', 0) == 0,
          f'the current output (Test Speakers) is ticked when the picker opens (tick pixels {a})')
    check('audio-device-tick', b.get('Test Headphones', 0) > 3 and b.get('Test Speakers', 0) == 0,
          f'after choosing Test Headphones the tick moves to it (tick pixels {b})')
    sl, _ = values('audio-device-tick', 'vol')
    check('audio-device-tick', sl.get('Volume', 0) > 0, f'the volume bar is not empty when the video starts (Volume {sl.get("Volume")})')

# equalizer preset icons: every preset row of the open dropdown has its icon left of the name
PRESETS = ['Flat', 'Classical', 'Club', 'Dance', 'Full bass', 'Full bass and treble', 'Full treble', 'Headphones',
           'Large Hall', 'Live', 'Party', 'Pop', 'Reggae', 'Rock', 'Ska', 'Soft', 'Soft rock', 'Techno']
for scene in ('eq-preset-icons', 'eq-preset-icons-day'):
    t, rows = img(scene, 'list'), geom_rows(scene, 'list')
    if not (t and rows):
        continue
    found, missing = 0, []
    for name in PRESETS:
        boxes = [(x, y, w, h) for n, r, x, y, w, h in rows if n == name and r in ('list item', 'menu item', 'label', 'push button', 'button')]
        if not boxes:
            missing.append(name + ' (no row)'); continue
        x, y, w, h = max(boxes, key=lambda b: b[2])           # the row (the widest box of that name)
        icon = (x + 8, y + 4, x + 52, y + h - 4)               # the icon sits left of the label
        acc = count_color(t, icon, ACCENT, 60)
        if name == 'Flat':
            # grey line only: some pixels away from the row colour, none of them accent
            face = dominant(t, icon)
            ink = sum(1 for p in pixels(t.crop(icon)) if max(abs(a - b) for a, b in zip(p, face)) > 40)
            ok_ = acc == 0 and ink >= 10
        else:
            ok_ = acc >= 4
        found += ok_
        if not ok_:
            missing.append(f'{name} ({acc} accent px)')
    check(scene, not missing, f'{found}/{len(PRESETS)} preset rows draw their icon' + (f'; missing: {missing}' if missing else ''))
g = geom('eq-preset-icons', 'rock')
if g:
    check('eq-preset-icons', any(n == 'Rock' and r == 'combo box' for n, r, *_ in geom_rows('eq-preset-icons', 'rock')),
          'choosing Rock in the dropdown selects it (the preset box shows Rock)')

# tracks picker: which tab is current (the accent underline under the tab buttons), per button
def picker_tab(scene, tag):
    t, c = img(scene, tag), f'{OUT}/{scene}-{tag}.ctl'
    if not (t and os.path.exists(c)):
        return None
    under = {}
    for line in open(c):
        f = line.rstrip('\n').split('\t')
        if len(f) == 7 and f[0] == 'button' and f[1] in ('Video', 'Audio', 'Subtitles') and int(f[3]) > 1400:
            x, y, w, h = map(int, f[3:])
            under[f[1]] = count_color(t, (x, y + h - 6, x + w, y + h + 2), ACCENT, 40)
    if not under or max(under.values()) < 10:
        return 'none'                                   # no picker open
    return max(under, key=under.get)

for scene, tag, want, what in (('picker-default-tab', 'first', 'Subtitles', 'the subtitles button opens the picker on Subtitles'),
                               ('picker-default-tab', 'audio', 'Audio', 'the Audio tab can be chosen'),
                               ('picker-default-tab', 'again', 'Subtitles', 'reopened, it is on Subtitles again (not the last tab)'),
                               ('audio-button-picker', 'a', 'Audio', 'the audio button opens the same picker on Audio'),
                               ('audio-button-picker', 'subs', 'Subtitles', 'then the subtitles button opens it on Subtitles')):
    if img(scene, tag):
        got = picker_tab(scene, tag)
        check(scene, got == want, f'{what} (current tab: {got})')

# window (window.txt, run with an empty KWINRULES)
r = geom_rows('win-open-size', 'a')
if r:
    w = next(((x, y, ww, hh) for n, ro, x, y, ww, hh in r if n == 'Main interface'), None)
    check('win-open-size', w is not None and w[2:] == (1280, 800) and abs(w[0] - (1920 - 1280) // 2) <= 20,
          f'the window opens at 1280x800, centred ({w})')
g = geom('win-resize', 'a')
if g:
    top = g.get('Player topbar', [(0, 0, 0, 0)])[0]
    prog = g.get('Progress', [(0, 0, 0, 0)])[0]
    check('win-resize', top[2] == 1000 and 0 < prog[0] + prog[2] < 1000, f'resized to 1000 wide: top bar {top[2]} wide, seek bar ends at {prog[0] + prog[2]}')

# 14. every scene produced its screenshots
for at in sorted(glob.glob(f'{OUT}/*.at')):
    scene = os.path.basename(at)[:-3]
    for line in open(at):
        if line.startswith('no match') or line.startswith('no action'):
            fail(scene, 'AT-SPI: ' + line.strip())

# 15. accessibility: the AT-SPI audit (at.py audit) finds nothing on the audited screens
for a in sorted(glob.glob(f'{OUT}/*.a11y')):
    scene = os.path.basename(a)[:-5].rsplit('-', 1)[0]
    issues = [l.rstrip('\n').split('\t') for l in open(a) if l.strip()]
    for rule, role, name, where in issues:
        fail(scene, f'a11y {rule}: {role} "{name}" at {where}')
    if not issues:
        ok(scene, 'a11y audit: every control is named, has a role, is focusable and at least 24x24')

# 16. contrast of every enabled control on every screenshot (contrast.py, WCAG 1.4.11: 3:1)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import contrast as _contrast
_cfails, _cinfos, _cn = _contrast.check(OUT)
for scene, msg in _cfails:
    fail(scene, msg)
for scene in sorted({os.path.basename(p)[:-4].rsplit('-', 1)[0] for p in glob.glob(f'{OUT}/*.ctl')} - {s for s, _ in _cfails}):
    ok(scene, 'contrast: every enabled control stands out at least 3:1 (contrast.html)')

# WCAG contrast of the Figma colour pairs, for information (the Figma greys are kept on purpose)
def luminance(hexc_):
    r, g, b = (int(hexc_[i:i + 2], 16) / 255 for i in (1, 3, 5))
    lin = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)

def contrast(fg, bg):
    a, b = sorted((luminance(fg), luminance(bg)), reverse=True)
    return (a + 0.05) / (b + 0.05)

CONTRAST_PAIRS = [  # what, foreground, background, needed (4.5 text, 3 large text or UI)
    ('Night: body text on the library', '#E3E3E3', '#0E0E0E', 4.5),
    ('Night: bar icons and times on the player bar', '#8F8F8F', '#1B1B1B', 4.5),
    ('Night: menu labels', '#8F8F8F', '#181818', 4.5),
    ('Night: menu shortcuts and section titles', '#6B6B6B', '#181818', 4.5),
    ('Night: side panel row labels', '#6B6B6B', '#0E0E0E', 4.5),
    ('Night: side panel section titles', '#969696', '#0E0E0E', 4.5),
    ('Night: inactive side panel tab icons', '#404040', '#090909', 3),
    ('Night: accent on the library', '#D37918', '#0E0E0E', 3),
    ('Night: play glyph on the accent', '#1A0E02', '#D37918', 3),
    ('Day: side panel values', '#2A2A2A', '#D2D2D1', 4.5),
    ('Day: side panel row labels', '#4A4A4A', '#D2D2D1', 4.5),
    ('Day: inactive side panel tab icons', '#8A8A8A', '#BDBDBC', 3),
]
contrast_rows = []
for what, fg, bg, need in CONTRAST_PAIRS:
    r = contrast(fg, bg)
    contrast_rows.append((what, fg, bg, r, need))

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
    f"<h1>{len(failures)} failures, {len(passes)} passes</h1>" + ''.join(rows)
    + "<h2>WCAG contrast (information)</h2>"
    + ''.join(f"<div class={'good' if r >= need else 'bad'}>{html.escape(w)}: {fg} on {bg} = {r:.2f}:1 (AA needs {need}:1)</div>"
              for w, fg, bg, r, need in contrast_rows))
print(f'{len(failures)} failures, {len(passes)} passes')
for s, w in failures:
    print(f'FAIL {s}: {w}')
low = [(w, r, need) for w, fg, bg, r, need in contrast_rows if r < need]
if low:
    print('contrast below WCAG AA (information): ' + '; '.join(f'{w} {r:.2f}:1 < {need}' for w, r, need in low))
sys.exit(1 if failures else 0)
