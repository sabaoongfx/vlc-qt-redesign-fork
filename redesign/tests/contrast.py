#!/usr/bin/env python3
"""Contrast of every enabled control on every screenshot (WCAG 2.2, 1.4.11 non-text contrast: 3:1).

Each `shot:`/`shotwin:` of a scene also writes <shot>.ctl (lib/at.py controls: role, name, flags and the
screen box of every enabled control). For each control this measures, in the screenshot, how far its
drawn content (icon strokes, label text) stands out from its own background:

  ink         its strongest marks (icon strokes, label text, a slider handle) against the most common
              colour inside the box (its face, or the bar under a bare icon)
  boundary    its face against the colour around the box (swatches, filled pills, tracks)
  (the better of the two counts; details in measure())

A control fails below 3:1 (WCAG's minimum for user interface components and graphics; text inside a
control is held to the same floor here, 4.5:1 is reported as information). Disabled controls are exempt,
as in WCAG. Controls that draw nothing of their own (a box over a thumbnail, an invisible hit area) are
skipped when their box is a flat colour (under 1.05:1).

Known exceptions go in contrast-allow.txt: `scene regex | control name regex | reason` (fields split on ' | ').

usage: contrast.py OUT_DIR       prints the failures, writes OUT_DIR/contrast/ (zoomed crops) and
                                 OUT_DIR/contrast.html; exit 1 on failures. check.py calls check(out).
"""
import glob, html, os, re, sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FAIL_BELOW = 3.0
INFO_BELOW = 4.5


def _lin(c):
    c = c / 255.0
    return np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def luminance(rgb):
    rgb = np.asarray(rgb, dtype=np.float64)
    l = _lin(rgb)
    return 0.2126 * l[..., 0] + 0.7152 * l[..., 1] + 0.0722 * l[..., 2]


def ratio(l1, l2):
    hi, lo = np.maximum(l1, l2), np.minimum(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def dominant(px):
    """mean of the most common colour (quantised to 8 levels per channel against gradients and noise)"""
    q = px // 8
    keys = q[:, 0] * 1024 + q[:, 1] * 32 + q[:, 2]
    vals, counts = np.unique(keys, return_counts=True)
    return px[keys == vals[np.argmax(counts)]].mean(axis=0)


def measure(img, box):
    """(background rgb, ink rgb, contrast) of the control drawn in box = (x, y, w, h), or None.

    Two ways a control can be seen, the better one counts (WCAG 1.4.11 asks for either):
      ink       its strongest marks against its own face: icon strokes, label text, a slider handle;
                reached by the top 0.1% of its pixels (at least 6), so a one-pixel speck does not pass
                a control but a thin handle or a short label in a wide field still counts
      boundary  its face against what surrounds it (a 3px ring outside the box): colour swatches,
                filled pills, tracks
    """
    x, y, w, h = box
    W, H = img.size
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    if x1 - x0 < 6 or y1 - y0 < 6:
        return None
    rgb = img.convert('RGB') if img.mode != 'RGB' else img
    a = np.asarray(rgb.crop((x0, y0, x1, y1)), dtype=np.int32)
    # 1px inset: focus rings and borders of the neighbour are not the control's content
    if a.shape[0] > 8 and a.shape[1] > 8:
        a = a[1:-1, 1:-1]
    px = a.reshape(-1, 3)
    bg = dominant(px)
    c = ratio(luminance(px), luminance(bg))
    k = max(6, int(len(c) * 0.001))
    if k >= len(c):
        return None
    idx = np.argpartition(c, -k)[-k:]
    ink_c = float(np.min(c[idx]))
    ink = px[idx[np.argmin(c[idx])]]
    # boundary: the face against a ring 3px outside the box
    r0, s0, r1, s1 = max(0, x0 - 4), max(0, y0 - 4), min(W, x1 + 4), min(H, y1 + 4)
    big = np.asarray(rgb.crop((r0, s0, r1, s1)), dtype=np.int32)
    mask = np.ones(big.shape[:2], bool)
    mask[y0 - s0 + 1:y1 - s0 - 1, x0 - r0 + 1:x1 - r0 - 1] = False  # keep the ring only
    ring = big[mask]
    if len(ring) >= 8:
        around = dominant(ring)
        edge_c = float(ratio(luminance(bg), luminance(around)))
        if edge_c > ink_c:
            return around, bg, edge_c
    return bg, ink, ink_c


def load_allow():
    rules = []
    path = os.path.join(HERE, 'contrast-allow.txt')
    if os.path.exists(path):
        for line in open(path):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = [p.strip() for p in line.split(' | ')]  # regexes may use | without spaces
            if len(parts) >= 3:
                rules.append((re.compile(parts[0]), re.compile(parts[1]), parts[2]))
    return rules


def hexc(rgb):
    return '#%02X%02X%02X' % tuple(int(round(v)) for v in rgb)


def check(out):
    """[(scene, message)] failures, [(scene, message)] infos, html rows."""
    allow = load_allow()
    os.makedirs(os.path.join(out, 'contrast'), exist_ok=True)
    worst = {}  # (scene, role, name) -> (contrast, shot, box, bg, ink)
    for ctl in sorted(glob.glob(f'{out}/*.ctl')):
        png = ctl[:-4] + '.png'
        if not os.path.exists(png):
            continue
        shot = os.path.basename(png)[:-4]
        scene = shot.rsplit('-', 1)[0]
        img = Image.open(png)
        ox = oy = 0
        for line in open(ctl):
            if line.startswith('# offset'):
                _, _, sx, sy = line.split()
                ox, oy = int(sx), int(sy)
                continue
            f = line.rstrip('\n').split('\t')
            if len(f) != 7:
                continue
            role, name, flags = f[0], f[1], f[2]
            box = (int(f[3]) - ox, int(f[4]) - oy, int(f[5]), int(f[6]))
            m = measure(img, box)
            if m is None:
                continue
            bg, ink, c = m
            if c < 1.05:  # nothing drawn at all: an empty hit area
                continue
            key = (scene, role, name or '(unnamed)')
            if key not in worst or c < worst[key][0]:
                worst[key] = (c, shot, box, bg, ink)

    fails, infos, rows = [], [], []
    for (scene, role, name), (c, shot, box, bg, ink) in sorted(worst.items(), key=lambda kv: kv[1][0]):
        if c >= INFO_BELOW:
            continue
        reason = next((r for s, n, r in allow if s.search(scene) and n.search(name)), None)
        msg = f'contrast {c:.2f}:1 {role} "{name}" ({hexc(ink)} on {hexc(bg)}) in {shot} at {box[0]},{box[1]} {box[2]}x{box[3]}'
        crop = None
        if c < FAIL_BELOW:
            img = Image.open(os.path.join(out, shot + '.png'))
            x, y, w, h = box
            pad = 6
            z = img.crop((max(0, x - pad), max(0, y - pad), x + w + pad, y + h + pad))
            s = max(1, min(6, 240 // max(1, z.height)))
            crop = f'contrast/{shot}-{x}-{y}.png'
            z.resize((z.width * s, z.height * s), Image.NEAREST).save(os.path.join(out, crop))
            (infos if reason else fails).append((scene, msg + (f' [allowed: {reason}]' if reason else '')))
        else:
            infos.append((scene, msg + ' (below 4.5:1, information)'))
        cls = 'good' if c >= FAIL_BELOW or reason else 'bad'
        rows.append(f"<tr class={cls}><td>{c:.2f}</td><td>{html.escape(scene)}</td><td>{html.escape(role)}</td>"
                    f"<td>{html.escape(name)}</td><td><span class=sw style='background:{hexc(ink)}'></span>{hexc(ink)} on "
                    f"<span class=sw style='background:{hexc(bg)}'></span>{hexc(bg)}</td><td>{html.escape(reason or '')}</td>"
                    f"<td>{f'<img src={chr(39)}{crop}{chr(39)}>' if crop else ''}</td></tr>")
    open(os.path.join(out, 'contrast.html'), 'w').write(
        "<!doctype html><meta charset=utf-8><title>Control contrast</title><style>body{background:#111;color:#ddd;"
        "font:14px sans-serif;margin:24px}td{padding:4px 8px;border-bottom:1px solid #333;vertical-align:middle}"
        ".bad td:first-child{color:#f66}.good td:first-child{color:#7c7}.sw{display:inline-block;width:12px;height:12px;"
        "border:1px solid #666;margin-right:4px;vertical-align:middle}img{max-height:120px}</style>"
        f"<h1>Control contrast: {len(fails)} below {FAIL_BELOW}:1</h1><p>{len(worst)} controls measured "
        f"(enabled ones, worst shot per scene). Below {INFO_BELOW}:1 listed; red fails WCAG 1.4.11.</p><table>"
        "<tr><th>ratio</th><th>scene</th><th>role</th><th>name</th><th>ink on background</th><th>allowed</th><th></th></tr>"
        + ''.join(rows) + "</table>")
    return fails, infos, len(worst)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'out', 'run')
    fails, infos, n = check(out)
    for s, m in fails:
        print(f'FAIL {s}: {m}')
    print(f'{n} controls measured, {len(fails)} below {FAIL_BELOW}:1, report: {out}/contrast.html')
    sys.exit(1 if fails else 0)
