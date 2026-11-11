#!/usr/bin/env python3
"""Writes settings.txt: two harness scenes per Settings row, from settings-options.tsv.

Each scene starts VLC on an empty profile (run.sh kind "prefs"), opens Settings (Ctrl+P), goes to
the row's page (and opens Advanced Options when the row is under it), changes the row once
(at.py setrow), presses Save and quits; its "-reload" scene starts VLC again on that profile and
lists the rows of every page showing the option (at.py rows). `set-baseline` opens every page,
lists the rows as first shown and saves without a change. check_settings.py then checks that the
row changed, that only its option changed in vlcrc and to the value shown, that a restart shows it,
and (baseline) that every row first shows the value vlcrc holds.

  python3 redesign/tests/settings_scenes.py            # writes redesign/tests/settings.txt
  SKIP_FIXTURES=1 SCEN=redesign/tests/settings.txt OUT=<dir> redesign/tests/run.sh 'set-'
  python3 redesign/tests/check_settings.py <dir>

The fixtures must exist (run.sh without SKIP_FIXTURES once; the scenes need no media).
Rows built only on another system (an #ifdef that excludes Linux) get no scene.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from settings_options import read_tsv  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'settings.txt')

# text fields: a valid value for the option (anything else gets "vlctest"); no spaces or "|"
TEXT = {
    'crop': '16:9',
    'aspect-ratio': '16:9',
    'logfile': '/tmp/vlc-settings-test.log',
    'input-record-path': '/tmp',
    'http-host': '127.0.0.2',
    'http-proxy': 'http://127.0.0.1:3128/',
    'scrobbler-url': 'http://127.0.0.1/vlctest',
    'codec': 'avcodec',
    'sub-language': 'fr',
    'menu-language': 'fr',
}
# rows that are not a plain control (at.py setrow values)
SPECIAL = {
    'Theme': 'click:Day',        # segmented Night / Day / System (the scenes run in Night); reacts to clicked
    'Accent color': 'click:2',   # the third swatch (#8D721C)
    'Text color': 'colour',      # a button opening Qt's colour dialog
    'Outline color': 'colour',
}
# options whose new value keeps the check from reaching Settings after a restart (no reload scene)
NO_RELOAD = {'qt-start-minimized': 'VLC starts hidden in the tray: no window takes Ctrl+P'}
NOT_LINUX = ('_WIN32', '__APPLE__', '__OS2__')


def on_linux(guard):
    """evaluate the #if lines around a row for a Linux build"""
    if not guard:
        return True
    expr = guard
    expr = re.sub(r'#ifdef\s+(\w+)', r'defined(\1)', expr)
    expr = re.sub(r'#ifndef\s+(\w+)', r'not defined(\1)', expr)
    expr = re.sub(r'#if\s+', '', expr)
    expr = expr.replace('&&', ' and ').replace('||', ' or ')
    expr = re.sub(r'!\s*(?!=)', ' not ', expr)
    expr = re.sub(r'defined\s*\(\s*(\w+)\s*\)', lambda m: str(m.group(1) not in NOT_LINUX), expr)
    try:
        return bool(eval(expr, {}, {}))
    except Exception:
        return True  # unknown macro (e.g. UPDATE_CHECK): try it, the check reports a missing row


def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')


def page_steps(page, advanced):
    steps = [f'press:{page}', 'sleep:0.8']
    if advanced:
        steps += ['press:Advanced_Options', 'sleep:0.6']
    return steps


def scene_for(r):
    """(name, actions) of the scene that changes row r, Saves and quits"""
    label = r['label'].replace(' ', '_')
    opts = r['options'].split()
    value = SPECIAL.get(r['label']) or TEXT.get(opts[0] if opts else '', 'vlctest')
    actions = ['sleep:2', 'key:ctrl+p', 'sleep:2.5'] + page_steps(r['page'], r['advanced'])
    actions += [f'setrow:{label}={value}', 'sleep:0.8', 'shotwin:changed', 'press:Save', 'sleep:1.5', 'key:ctrl+q', 'sleep:2', 'term']
    return f'set-{slug(r["page"])}-{slug(r["label"])}', ' '.join(actions)


def reload_for(r, rows):
    """(name, actions) of the scene that starts VLC again on the saved profile (run.sh kind "same") and
    lists the rows of every page showing the same option: the new value must be there after a restart"""
    opts = set(r['options'].split())
    pages = []
    for x in rows:
        if opts & set(x['options'].split()) and (x['page'], x['advanced']) not in pages:
            pages.append((x['page'], x['advanced']))
    actions = ['sleep:2', 'key:ctrl+p', 'sleep:2.5']
    for page, adv in pages:
        actions += page_steps(page, adv) + [f'rows:{slug(page)}']
    actions += ['key:Escape', 'sleep:0.5', 'key:ctrl+q', 'sleep:2', 'term']
    return scene_for(r)[0] + '-reload', ' '.join(actions)


def baseline(rows):
    """open every page (and its Advanced Options), list the rows as first shown, Save without a change"""
    actions = ['sleep:2', 'key:ctrl+p', 'sleep:2.5']
    for page in dict.fromkeys(r['page'] for r in rows):
        actions += page_steps(page, any(r['advanced'] for r in rows if r['page'] == page)) + [f'rows:{slug(page)}']
    actions += ['press:Save', 'sleep:1.5', 'key:ctrl+q', 'sleep:2', 'term']
    return 'set-baseline', ' '.join(actions)


def scene_lines():
    """(lines of settings.txt, rows without a scene on Linux)"""
    rows = read_tsv()
    name, actions = baseline([r for r in rows if r['kind'] != 'action' and on_linux(r['guard'])])
    lines = [
        '# generated by settings_scenes.py from settings-options.tsv; do not edit',
        "# name | theme (2 = Night, - = the profile's own) | kind (prefs = empty profile, kept; same = the previous scene's) | media | actions",
        f'{name} | 2 | prefs | | {actions}',
    ]
    skipped = []
    for r in rows:
        if r['kind'] == 'action':
            continue  # a button with no option (Clear history, Edit Keyboard Shortcuts, Plugins)
        if not on_linux(r['guard']):
            skipped.append(f'{r["page"]} / {r["label"]} ({r["guard"]})')
            continue
        name, actions = scene_for(r)
        lines.append(f'{name} | 2 | prefs | | {actions}')
        if not set(r['options'].split()) & set(NO_RELOAD):
            name, actions = reload_for(r, rows)
            # theme "-": the harness does not force Night, so the Theme scene's saved choice is kept
            lines.append(f'{name} | {"-" if "qt:color-scheme-index" in r["options"] else 2} | same | | {actions}')
    return lines, skipped


def main():
    lines, skipped = scene_lines()
    open(OUT, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print(f'{len(lines) - 3} scenes (a change and a reload per row) + baseline written to {os.path.relpath(OUT)}')
    for s in skipped:
        print('  no scene (not built on Linux):', s)


if __name__ == '__main__':
    main()
