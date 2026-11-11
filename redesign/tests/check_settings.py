#!/usr/bin/env python3
"""Checks the settings scenes (settings_scenes.py) after a harness run.

load     (set-baseline) every row first shows the value vlcrc holds: check boxes, spin boxes and text
         fields (combo boxes show a translated item, not the stored value, and are not compared)
change   (set-<page>-<row>) the row was found and its control changed (at.py setrow: old != new)
save     Save wrote the row's option with a new value, equal to what the control showed (check box,
         spin box, text, colour, accent; Theme: color-scheme-index in vlc-qt-interface.conf), and
         changed no other option (compared with the baseline, saved without a change)
type     the control matches the option's declaration (a bool is a check box, a font a font list...)
reload   (set-<page>-<row>-reload) after a restart, every row showing that option (some options are
         on two pages) shows the new value
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
from settings_options import declared_options  # noqa: E402
from settings_scenes import NO_RELOAD, SPECIAL, on_linux, scene_for, slug  # noqa: E402

# the controls SettingsRows::option may build for each declaration (add_<type>), as at.py names them
ROLES = {
    'bool': {'check box'},
    'integer': {'spin button', 'combo box'}, 'integer_with_range': {'spin button', 'combo box'},
    'float': {'spin button'}, 'float_with_range': {'spin button'},
    'string': {'text', 'entry', 'combo box'}, 'module': {'combo box'}, 'module_list': {'combo box', 'text', 'entry'},
    'password': {'password text', 'text', 'entry'},
    'loadfile': {'text', 'entry'}, 'savefile': {'text', 'entry'}, 'directory': {'text', 'entry'},
    'font': {'combo box'}, 'rgb': {'colour'},
}
# rows that show their option the other way round
INVERTED = {'Seek precisely'}
# rows whose shown value is not the stored one (custom combos, colour buttons)
NOT_COMPARABLE = {'Repeat', 'When playback finishes', 'Text color', 'Outline color'}


def vlcrc(path):
    """option -> (value, active); active = written uncommented (differs from the default)"""
    out = {}
    if not path or not os.path.exists(path):
        return out
    for line in open(path, encoding='utf-8', errors='replace'):
        m = re.match(r'^(#?)([a-z0-9][a-z0-9-]*)=(.*)$', line.rstrip('\n'))
        if m:
            active = m.group(1) == ''
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


def rows_file(path):
    """label -> (role, value), first row with that label (the page's own rows come first)"""
    out = {}
    if os.path.exists(path):
        for line in open(path, encoding='utf-8', errors='replace'):
            parts = line.rstrip('\n').split('\t')
            if len(parts) == 3 and parts[0] not in out:
                out[parts[0]] = (parts[1], parts[2])
    return out


def same(a, b):
    """values equal as numbers when both are numbers (1 vs 1.000000), else as text"""
    try:
        return float(a) == float(b)
    except (TypeError, ValueError):
        return str(a) == str(b)


def shown_as_stored(label, role, shown):
    """the vlcrc value a row's displayed value stands for, or None when it cannot be compared"""
    if label in NOT_COMPARABLE or role in ('combo box', 'buttons', 'colour', 'button', 'push button'):
        return None
    if role == 'check box':
        v = int(float(shown))
        return str(1 - v) if label in INVERTED else str(v)
    return shown


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
    tsv = [r for r in read_tsv() if r['kind'] != 'action' and on_linux(r['guard'])]

    declared = declared_options()
    results = []

    def res(status, check, name, msg):
        results.append((status, check, name, msg))

    # load: what each row shows first equals vlcrc
    for r in tsv:
        name = scene_for(r)[0]
        opts = r['options'].split()
        shown = rows_file(os.path.join(out, f'set-baseline-{slug(r["page"])}.rows')).get(r['label'])
        if len(opts) != 1 or opts[0].startswith('qt:'):
            continue
        if shown is None:
            res('SKIP' if opts[0] not in base else 'FAIL', 'load', name,
                'option not in this build' if opts[0] not in base else 'row not listed on its page')
            continue
        want = shown_as_stored(r['label'], shown[0], shown[1])
        if want is None:
            continue
        stored = base.get(opts[0], ('?',))[0]
        res('PASS' if same(want, stored) else 'FAIL', 'load', name, f'shows {shown[1]}, vlcrc {opts[0]}={stored}')

    for r in tsv:
        name = scene_for(r)[0]
        opts = r['options'].split()
        p = profile(out, name)
        if not p:
            res('FAIL', 'change', name, 'scene did not run (no profile)'); continue
        atp = os.path.join(out, name + '.at')
        at = open(atp, errors='replace').read() if os.path.exists(atp) else ''
        missing = [o for o in opts if not o.startswith('qt:') and o not in base]
        if 'no row:' in at or 'no match:' in at or 'setrow\t' not in at:
            if missing:
                res('SKIP', 'change', name, f'option {missing} not in this build (row hidden)')
            else:
                res('FAIL', 'change', name, 'row not found or not changed: ' + (at.strip().splitlines() or ['(no at.py output)'])[-1])
            continue
        m = re.search(r'^setrow\t[^\t]*\t([^\t]*)\t([^\t]*)\t([^\t\n]*)$', at, re.M)
        role, old, new = m.groups() if m else ('', '', '')
        click = SPECIAL.get(r['label'], '').startswith('click:')
        if not click and same(old, new):
            res('FAIL', 'change', name, f'the {role} did not change (stayed "{old}")'); continue
        res('PASS', 'change', name, f'{role}: {old} -> {new}')
        if r['kind'] == 'option':
            kind = declared.get(opts[0])
            if kind in ROLES:
                res('PASS' if role in ROLES[kind] else 'FAIL', 'type', name,
                    f'add_{kind} option shown as a {role} (expected {"/".join(sorted(ROLES[kind]))})')

        # save
        if opts == ['qt:color-scheme-index']:
            theme = qtconf(os.path.join(p, 'config/vlc/vlc-qt-interface.conf'), 'color-scheme-index')
            res('PASS' if theme is not None and theme != base_theme else 'FAIL', 'save', name,
                f'color-scheme-index {base_theme} -> {theme}')
        else:
            saved = vlcrc(os.path.join(p, 'config/vlc/vlcrc'))
            if not saved:
                res('FAIL', 'save', name, 'Save wrote no vlcrc'); continue
            active = {k: v for k, (v, a) in saved.items() if a}
            changed = {k for k in set(active) | set(base_active) if active.get(k) != base_active.get(k)}
            own = [o for o in opts if o in changed]
            other = sorted(changed - set(opts))
            problems = []
            if not own:
                problems.append(f'{"/".join(opts)} not written (still {[base.get(o, ("?",))[0] for o in opts]})')
            if other:
                problems.append(f'other options changed: {other[:8]}')
            if own and len(opts) == 1:
                stored = active.get(opts[0], saved.get(opts[0], ('',))[0])
                if role == 'colour':
                    if not same(stored, 0x123456):
                        problems.append(f'{opts[0]}={stored}, expected #123456 ({0x123456})')
                elif r['label'] == 'Accent color':
                    if stored.lower() != '#8d721c':
                        problems.append(f'{opts[0]}={stored}, expected #8D721C (third swatch)')
                else:
                    want = shown_as_stored(r['label'], role, new)
                    if want is not None and not same(want, stored):
                        problems.append(f'{opts[0]}={stored}, the control showed {new}')
            detail = ', '.join(f'{o}: {base.get(o, ("?",))[0]} -> {active.get(o, "(default)")}' for o in opts)
            res('FAIL' if problems else 'PASS', 'save', name, '; '.join(problems) or detail)

        # reload: every row bound to the option shows the new value after a restart
        rel = name + '-reload'
        skip = [NO_RELOAD[o] for o in opts if o in NO_RELOAD]
        if skip:
            res('SKIP', 'reload', name, skip[0]); continue
        if not profile(out, name) or not glob.glob(os.path.join(out, rel + '-*.rows')):
            res('FAIL', 'reload', name, 'reload scene listed no rows'); continue
        for x in tsv:
            if not set(opts) & set(x['options'].split()):
                continue
            shown = rows_file(os.path.join(out, f'{rel}-{slug(x["page"])}.rows')).get(x['label'])
            where = f'{x["page"]} / {x["label"]}'
            if shown is None:
                res('FAIL', 'reload', name, f'{where}: row not listed'); continue
            if x['label'] == 'Theme':
                ok = 'Day' in shown[1].split(',')
            elif x['label'] == 'Accent color':
                ok = '2' in shown[1].split(',')
            elif x['label'] in NOT_COMPARABLE:
                continue
            elif x is r or x['label'] == r['label']:
                ok = same(shown[1], new)
            else:
                # the same option on another page: compare through the stored value
                a = shown_as_stored(x['label'], shown[0], shown[1])
                b = shown_as_stored(r['label'], role, new)
                if a is None or b is None:
                    continue
                ok = same(a, b)
            res('PASS' if ok else 'FAIL', 'reload', name, f'{where} shows {shown[1]} after a restart (set to {new})')

    lines = [f'{s}\t{c}\t{n}\t{m}' for s, c, n, m in results]
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
