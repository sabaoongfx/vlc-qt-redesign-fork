#!/usr/bin/env python3
"""The Settings window's option list, and static tests on it.

Every row of the redesigned Settings window (`SettingsRows` in
modules/gui/qt/dialogs/preferences/simple_preferences.cpp) is read from the code into
settings-options.tsv: one line per row, with its page (the sidebar name), section, label, the VLC
option(s) behind it and how it is built. The runtime tests (settings_scenes.py, check_settings.py)
work from that file.

  settings_options.py --write   regenerate settings-options.tsv from the code
  settings_options.py           the static tests (exit 1 on a failure):
    1. settings-options.tsv matches the code (regenerate it after changing the rows)
    2. every option is declared somewhere in VLC (src/, modules/): a row whose option is gone is
       silently dropped at runtime (`config_FindConfig` returns NULL)
    3. redesign/SETTINGS-MAP.md lists the same rows with the same options, page by page
    4. no row repeats an option the classic pages' own Save code writes (see SETTINGS-MAP.md)
    5. labels are unique on a page (the runtime tests find a row by its label)
    6. an option shown on two pages is reported (both rows must not undo each other on Save;
       the runtime tests change each one on its own)
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CODE = os.path.join(ROOT, 'modules/gui/qt/dialogs/preferences/simple_preferences.cpp')
MAP = os.path.join(ROOT, 'redesign/SETTINGS-MAP.md')
TSV = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'settings-options.tsv')

# the sidebar name of each page (the runtime tests press it)
PAGES = {
    'SPrefsVideo': 'Video', 'SPrefsAudio': 'Audio', 'SPrefsInputAndCodecs': 'Playback',
    'SPrefsInterface': 'Interface', 'SPrefsSubtitles': 'Subtitles', 'SPrefsHotkeys': 'Controls',
    'SPrefsMediaLibrary': 'Library', 'SPrefsGeneral': 'General', 'SPrefsPrivacy': 'Privacy',
    'SPrefsNetwork': 'Network', 'SPrefsPerformance': 'Performance', 'SPrefsRecording': 'Recording',
    'SPrefsExtensions': 'Extensions',
}
# SETTINGS-MAP.md page titles
MAP_PAGES = {
    'Video Defaults': 'Video', 'Audio Defaults': 'Audio', 'Playback Preferences': 'Playback',
    'Interface Settings': 'Interface', 'Subtitle Defaults': 'Subtitles', 'Mouse & Keyboard Controls': 'Controls',
    'Playlists, Folders & Files': 'Library', 'Global Settings': 'General', 'Privacy Settings': 'Privacy',
    'Network Connections & Security': 'Network', 'Performance Settings': 'Performance',
    'Recording, Casting & Streaming Out': 'Recording', 'Add-ons & Scripts': 'Extensions',
}
# written by the classic pages' Save code: never a row (SETTINGS-MAP.md, Rules)
CLASSIC_ONLY = {'volume-save', 'audio-filter', 'freetype-shadow-opacity', 'freetype-background-opacity',
                'qt-fullscreen-screennumber', 'intf'}
# rows that are not a VLC option in vlcrc
NOT_VLCRC = {'Theme': 'qt:color-scheme-index'}

COLUMNS = ['page', 'section', 'label', 'options', 'kind', 'advanced', 'guard']
# kind: option = rows.option() (a ConfigControl picked by the option type)
#       widget = rows.widget() bound to the options listed (hidden check boxes, a hidden line edit)
#       action = rows.widget() with no option (a button: Clear history, Edit Keyboard Shortcuts, Plugins)


def qtr(s):
    return re.search(r'qtr\(\s*"((?:[^"\\]|\\.)*)"\s*\)', s)


def extract():
    lines = open(CODE, encoding='utf-8').read().split('\n')
    rows, page, section, advanced, guards, pending, in_rows = [], None, '', 0, [], [], False
    for line in lines:
        s = line.strip()
        m = re.match(r'case (SPrefs\w+)\s*:', s)
        if m:
            page = PAGES.get(m.group(1))
            section, advanced, pending, in_rows = '', 0, [], False
            continue
        if page is None:
            continue
        # only the Figma rows: the classic page code before them is not read
        if 'SettingsRows rows(' in s:
            in_rows, pending = True, []
            continue
        if s.startswith('#if'):
            guards.append(s)
            continue
        if s.startswith('#else') and guards:
            guards[-1] = '!(' + guards[-1] + ')'
            continue
        if s.startswith('#endif') and guards:
            guards.pop()
            continue
        guard = ' && '.join(guards)
        if not in_rows:
            continue
        if 'rows.section(' in s:
            section = qtr(s).group(1)
            continue
        if 'rows.advanced()' in s:
            advanced = 1
            continue
        # options a custom row binds (collected until its rows.widget call)
        for name in re.findall(r'(?:hiddenBool|config_FindConfig)\(\s*"([^"]+)"', s):
            if 'rows.widget(' not in s and 'rows.option(' not in s and name not in pending:
                pending.append(name)
        m = re.search(r'rows\.option\(\s*qtr\(\s*"((?:[^"\\]|\\.)*)"\s*\)\s*,\s*"([^"]+)"', s)
        if m:
            rows.append(dict(page=page, section=section, label=m.group(1), options=m.group(2), kind='option',
                             advanced=advanced, guard=guard))
            continue
        # rows from a table: { qtr( "Label" ), "option" } or std::pair<...>( qtr( "Label" ), "option" )
        for lab, opt in re.findall(r'qtr\(\s*"((?:[^"\\]|\\.)*)"\s*\)\s*,\s*"([a-z0-9-]+)"\s*[)}]', s):
            rows.append(dict(page=page, section=section, label=lab, options=opt, kind='option',
                             advanced=advanced, guard=guard))
        m = re.search(r'rows\.widget\(\s*qtr\(\s*"((?:[^"\\]|\\.)*)"\s*\)', s)
        if m:
            label = m.group(1)
            opts = NOT_VLCRC.get(label) or ' '.join(pending)
            rows.append(dict(page=page, section=section, label=label, options=opts,
                             kind='widget' if opts else 'action', advanced=advanced, guard=guard))
            pending = []
            continue
        if re.search(r'rows\.block\(', s):
            pending = []
    return rows


def write(rows):
    with open(TSV, 'w', encoding='utf-8') as f:
        f.write('# generated by settings_options.py --write from simple_preferences.cpp; do not edit\n')
        f.write('\t'.join(COLUMNS) + '\n')
        for r in rows:
            f.write('\t'.join(str(r[c]) for c in COLUMNS) + '\n')


def read_tsv(path=TSV):
    rows = []
    with open(path, encoding='utf-8') as f:
        lines = [l.rstrip('\n') for l in f if not l.startswith('#')]
    head = lines[0].split('\t')
    for l in lines[1:]:
        if l:
            r = dict(zip(head, l.split('\t')))
            r['advanced'] = int(r['advanced'])
            rows.append(r)
    return rows


def declared_options():
    """option name -> declaration macro (add_bool, add_integer...), from every C/C++ source"""
    found = {}
    decl = re.compile(r'\badd_(\w+)\s*\(\s*((?:[A-Z_][A-Z0-9_]*\s*)?"[^"]*")')
    for top in ('src', 'modules', 'lib'):
        for dirpath, _, files in os.walk(os.path.join(ROOT, top)):
            for fn in files:
                if not fn.endswith(('.c', '.cpp', '.h', '.hpp', '.m')):
                    continue
                try:
                    text = open(os.path.join(dirpath, fn), encoding='utf-8', errors='replace').read()
                except OSError:
                    continue
                if 'add_' not in text:
                    continue
                defines = dict(re.findall(r'#\s*define\s+([A-Z_][A-Z0-9_]*)\s+"([^"]*)"', text))
                for macro, arg in decl.findall(text):
                    # add_obsolete_*: the name is kept only to ignore old vlcrc lines, no row can use it
                    if macro.startswith('obsolete') or macro in ('shortcut', 'submodule', 'category', 'subcategory'):
                        continue
                    m = re.match(r'(?:([A-Z_][A-Z0-9_]*)\s*)?"([^"]*)"', arg)
                    prefix = defines.get(m.group(1), '') if m.group(1) else ''
                    if m.group(1) and m.group(1) not in defines:
                        continue
                    found.setdefault(prefix + m.group(2), macro)
    return found


def map_rows():
    """(page, label, option or None) from SETTINGS-MAP.md's tables"""
    out, page = [], None
    for line in open(MAP, encoding='utf-8'):
        m = re.match(r'## (.+)', line)
        if m:
            page = MAP_PAGES.get(m.group(1).strip())
            continue
        m = re.match(r'\| (.+?) \| (.+?) \|$', line.strip())
        if page and m and m.group(1) not in ('Row', '---'):
            opt = re.match(r'`([^`]+)`', m.group(2))
            out.append((page, m.group(1), opt.group(1) if opt else None))
    return out


def main():
    rows = extract()
    if '--write' in sys.argv:
        write(rows)
        print(f'{len(rows)} rows written to {os.path.relpath(TSV, ROOT)}')
        return 0

    fails, oks = [], 0

    def check(cond, msg):
        nonlocal oks
        if cond:
            oks += 1
        else:
            fails.append(msg)

    # 1. the list is current
    listed = read_tsv() if os.path.exists(TSV) else []
    key = lambda r: tuple(str(r[c]) for c in COLUMNS)
    check(os.path.exists(TSV), 'settings-options.tsv is missing (run settings_options.py --write)')
    for r in rows:
        check(key(r) in {key(x) for x in listed}, f'not in settings-options.tsv: {r["page"]} / {r["label"]}')
    for r in listed:
        check(key(r) in {key(x) for x in rows}, f'settings-options.tsv has a row the code lost: {r["page"]} / {r["label"]}')

    # 2. every option exists in VLC
    declared = declared_options()
    for r in rows:
        for opt in r['options'].split():
            if opt.startswith('qt:'):
                continue
            check(opt in declared, f'{r["page"]} / {r["label"]}: option "{opt}" is not declared anywhere (row dropped at runtime)')

    # 3. SETTINGS-MAP.md matches
    mapped = map_rows()
    code_map = [(r['page'], r['label'], r['options'] if r['kind'] == 'option' else None) for r in rows]
    for t in code_map:
        check(t in mapped, f'SETTINGS-MAP.md lacks {t[0]} / {t[1]} ({t[2] or "custom"})')
    for t in mapped:
        check(t in code_map, f'SETTINGS-MAP.md lists {t[0]} / {t[1]} ({t[2] or "custom"}), the code does not')

    # 4. no classic-only option as a row
    for r in rows:
        for opt in r['options'].split():
            check(opt not in CLASSIC_ONLY, f'{r["page"]} / {r["label"]}: "{opt}" is written by the classic page\'s Save')

    # 5. unique labels per page
    seen = {}
    for r in rows:
        k = (r['page'], r['label'])
        check(k not in seen, f'{r["page"]}: two rows labelled "{r["label"]}"')
        seen[k] = r

    # 6. options on two pages (information)
    pages = {}
    for r in rows:
        for opt in r['options'].split():
            pages.setdefault(opt, []).append(f'{r["page"]} / {r["label"]}')
    shared = {o: p for o, p in pages.items() if len(p) > 1}

    print(f'settings rows: {len(rows)}, options: {len(pages)}')
    for o, p in sorted(shared.items()):
        print(f'  info: "{o}" is on {len(p)} rows: {"; ".join(p)}')
    for f in fails:
        print('FAIL', f)
    print(f'{oks} passed, {len(fails)} failed')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
