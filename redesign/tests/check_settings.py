#!/usr/bin/env python3
"""Checks the settings scenes (settings_scenes.py) after a harness run.

For every row of settings-options.tsv that has a scene:
  - the row was found and changed (at.py setrow printed old and new values, and they differ)
  - Save wrote the row's option to vlcrc with a value other than the baseline's
    (Theme: color-scheme-index in vlc-qt-interface.conf)
  - Save changed no other option (compared with the scene `set-baseline`, saved without a change)
A row whose option this build does not have (not even as a commented default in the baseline vlcrc)
is a SKIP: the row is hidden at runtime. Writes <out>/settings-report.txt.

  python3 redesign/tests/check_settings.py <out>
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from settings_options import read_tsv  # noqa: E402
from settings_scenes import on_linux, scene_for  # noqa: E402


def vlcrc(path):
    """option -> (value, active); active = written uncommented (differs from the default)"""
    out = {}
    if not path or not os.path.exists(path):
        return out
    for line in open(path, encoding='utf-8', errors='replace'):
        m = re.match(r'^(#?)([a-z0-9][a-z0-9-]*)=(.*)$', line.rstrip('\n'))
        if m:
            active = m.group(1) == ''
            # an option can appear as a commented default and as an active line: the active one wins
            if active or m.group(2) not in out:
                out[m.group(2)] = (m.group(3), active)
    return out


def qtconf(path, key):
    if not path or not os.path.exists(path):
        return None
    for line in open(path, encoding='utf-8', errors='replace'):
        if line.startswith(key + '='):
            return line.split('=', 1)[1].strip()
    return None


def profile(out, name):
    p = sorted(glob.glob(os.path.join(out, 'profiles', name + '.*')))
    return p[-1] if p else None


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out', 'run')
    base_p = profile(out, 'set-baseline')
    if not base_p:
        print('no set-baseline profile in', out); return 1
    base = vlcrc(os.path.join(base_p, 'config/vlc/vlcrc'))
    base_theme = qtconf(os.path.join(base_p, 'config/vlc/vlc-qt-interface.conf'), 'color-scheme-index')
    if not base:
        print('the baseline Save wrote no vlcrc'); return 1
    base_active = {k: v for k, (v, a) in base.items() if a}

    results = []

    def res(status, name, msg):
        results.append((status, name, msg))

    for r in read_tsv():
        if r['kind'] == 'action' or not on_linux(r['guard']):
            continue
        name, _ = scene_for(r)
        opts = r['options'].split()
        p = profile(out, name)
        if not p:
            res('FAIL', name, 'scene did not run (no profile)'); continue
        at = open(os.path.join(out, name + '.at'), errors='replace').read() if os.path.exists(os.path.join(out, name + '.at')) else ''
        missing = [o for o in opts if not o.startswith('qt:') and o not in base]
        if 'no row:' in at or 'no match:' in at:
            if missing:
                res('SKIP', name, f'option {missing} not in this build (row hidden)')
            else:
                res('FAIL', name, 'row not found or not changed: ' + at.strip().splitlines()[-1])
            continue
        m = re.search(r'^setrow\t[^\t]*\t[^\t]*\t([^\t]*)\t([^\t\n]*)$', at, re.M)
        if m and m.group(1) == m.group(2):
            res('FAIL', name, f'the control did not change (stayed "{m.group(1)}")')
            continue

        if opts == ['qt:color-scheme-index']:
            theme = qtconf(os.path.join(p, 'config/vlc/vlc-qt-interface.conf'), 'color-scheme-index')
            res('PASS' if theme is not None and theme != base_theme else 'FAIL', name,
                f'color-scheme-index {base_theme} -> {theme}')
            continue

        saved = vlcrc(os.path.join(p, 'config/vlc/vlcrc'))
        if not saved:
            res('FAIL', name, 'Save wrote no vlcrc'); continue
        active = {k: v for k, (v, a) in saved.items() if a}
        changed = {k for k in set(active) | set(base_active) if active.get(k) != base_active.get(k)}
        own = [o for o in opts if o in changed]
        other = sorted(changed - set(opts))
        problems = []
        if not own:
            problems.append(f'{"/".join(opts)} not written (still {[base.get(o, ("?",))[0] for o in opts]})')
        if other:
            problems.append(f'other options changed: {other[:8]}')
        detail = ', '.join(f'{o}: {base.get(o, ("?",))[0]} -> {active.get(o, "(default)")}' for o in opts)
        res('FAIL' if problems else 'PASS', name, '; '.join(problems) or detail)

    lines = [f'{s}\t{n}\t{m}' for s, n, m in results]
    counts = {s: sum(1 for x in results if x[0] == s) for s in ('PASS', 'FAIL', 'SKIP')}
    summary = f'{counts["PASS"]} passed, {counts["FAIL"]} failed, {counts["SKIP"]} skipped'
    open(os.path.join(out, 'settings-report.txt'), 'w').write('\n'.join(lines + [summary]) + '\n')
    for l in lines:
        if not l.startswith('PASS'):
            print(l)
    print(summary)
    return 1 if counts['FAIL'] else 0


if __name__ == '__main__':
    sys.exit(main())
