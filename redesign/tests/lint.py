#!/usr/bin/env python3
"""Static checks of the redesign's code (no build, a few seconds): the project rules from CLAUDE.md
and code smells, applied to what the redesign added on top of upstream VLC (git diff against BASE),
so upstream's own code is not reported.

Errors (exit 1):
  canvas      QML uses Canvas, getContext or QtQuick.Shapes: the Windows Qt has neither, the whole
              file fails to load there (v0.1.0: the player showed only the video)
  qml-colour  a colour literal (#rgb, Qt.rgba(...)) in QML outside style/: colours come from VLCStyle
              (figmaColors, palette), or the Day/Night themes and the accent setting miss it
  qml-build   a QML file of the Qt module missing from Makefile.am or meson.build (it is then not in
              the binary: "is not a type" at runtime, the build does not fail)
  shell       a harness or packaging shell script with a syntax error (bash -n)

Warnings (information, listed with file:line):
  px-literal  font.pixelSize / width / height / margins set to a bare number in QML: sizes go through
              VLCStyle (dp scaling, the font scale setting)
  no-a11y     a QML file adds a MouseArea/TapHandler click but no Accessible.* anywhere: a control
              that screen readers and keyboard users may not reach (WCAG 4.1.2, 2.1.1)
  cpp-colour  a colour literal in C++ outside style/ (QColor(0x..), "#rrggbb" in a stylesheet)
  long-func   a C++ function the redesign added or grew past 150 lines
  todo        TODO/FIXME/XXX/HACK added by the redesign

A deliberate exception carries `// lint: allow <rule> (reason)` on its line; the reason is required.

usage: lint.py [--base REV] [--all]   --all also lists warnings in upstream lines of touched files
"""
import os, re, subprocess, sys

ROOT = subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True,
                      cwd=os.path.dirname(os.path.abspath(__file__))).stdout.strip()
QT = 'modules/gui/qt'
BASE = 'dd056f2640'  # where the redesign branched from upstream (redesign/docs/04-upstream-divergence.md)
args = sys.argv[1:]
if '--base' in args:
    BASE = args[args.index('--base') + 1]
ALL = '--all' in args


def git(*a):
    return subprocess.run(['git', *a], capture_output=True, text=True, cwd=ROOT).stdout


if subprocess.run(['git', 'cat-file', '-e', BASE + '^{commit}'], cwd=ROOT).returncode:
    sys.exit(f'lint: base {BASE} is not in this clone (shallow? git fetch --depth=1 origin <full sha>)')


def added_lines():
    """{path: {line numbers added since BASE}} for the working tree."""
    out, cur, res = git('diff', '-U0', '--no-color', BASE, '--', '.'), None, {}
    for line in out.splitlines():
        if line.startswith('+++ '):
            cur = line[6:] if line.startswith('+++ b/') else None
        elif line.startswith('@@') and cur:
            m = re.search(r'\+(\d+)(?:,(\d+))?', line)
            start, n = int(m.group(1)), int(m.group(2) or 1)
            res.setdefault(cur, set()).update(range(start, start + n))
    return res


errors, warnings = [], []
added = added_lines()
untracked = git('ls-files', '--others', '--exclude-standard').split()
for f in untracked:  # new files not committed yet count as added
    p = os.path.join(ROOT, f)
    if os.path.isfile(p) and not f.startswith('contrib/'):
        try:
            added[f] = set(range(1, sum(1 for _ in open(p, errors='replace')) + 2))
        except OSError:
            pass


def lines_of(path):
    try:
        return open(os.path.join(ROOT, path), encoding='utf-8', errors='replace').read().split('\n')
    except OSError:
        return []


def is_comment(s):
    s = s.strip()
    return s.startswith('//') or s.startswith('*') or s.startswith('/*') or s.startswith('#')


COLOUR_QML = re.compile(r'''(["'])#[0-9A-Fa-f]{3,8}\1|Qt\.rgba?\s*\(|Qt\.hsla?\s*\(''')
CANVAS = re.compile(r'\bCanvas\s*\{|getContext\s*\(|import\s+QtQuick\.Shapes')
PX = re.compile(r'^\s*(font\.pixelSize|width|height|implicitWidth|implicitHeight|spacing|radius|'
                r'(?:anchors\.)?(?:left|right|top|bottom)?[mM]argins?|(?:left|right|top|bottom)?[pP]adding)\s*:\s*\d+(\.\d+)?\s*$')
COLOUR_CPP = re.compile(r'QColor\s*\(\s*(0x|\d+\s*,)|QColor\s*\(\s*"#|"[^"]*#[0-9A-Fa-f]{6}\b[^"]*"')
TODO = re.compile(r'\b(TODO|FIXME|XXX|HACK)\b')

for path, nums in sorted(added.items()):
    if not os.path.isfile(os.path.join(ROOT, path)):
        continue
    src = lines_of(path)
    in_style = '/style/' in path
    if path.endswith('.qml'):
        clickable = any(re.search(r'\b(MouseArea|TapHandler)\b', src[n - 1]) for n in nums if n <= len(src))
        if clickable and not any('Accessible.' in l for l in src):
            warnings.append(('no-a11y', path, 0, 'clicks handled, no Accessible.* in the file'))
    for n in sorted(nums):
        if n > len(src):
            continue
        s = src[n - 1]
        if path.endswith('.qml'):
            code = re.split(r'(?<![:"])//', s)[0]
            if CANVAS.search(code):
                errors.append(('canvas', path, n, s.strip()))
            if not in_style and COLOUR_QML.search(code):
                errors.append(('qml-colour', path, n, s.strip()))
            if PX.search(code) and not re.search(r':\s*0\s*$', code):
                warnings.append(('px-literal', path, n, s.strip()))
        if path.endswith(('.cpp', '.hpp', '.h', '.c')) and not in_style and not is_comment(s) and COLOUR_CPP.search(s):
            warnings.append(('cpp-colour', path, n, s.strip()[:110]))
        if TODO.search(s) and path.startswith(('modules/', 'src/', 'include/', 'extras/package/redesign/', 'redesign/tests/')) \
                and not path.endswith('lint.py'):
            warnings.append(('todo', path, n, s.strip()[:110]))

# long C++ functions the redesign touched (brace matching from a function header at column 0)
for path, nums in sorted(added.items()):
    if not path.endswith('.cpp') or not path.startswith(QT):
        continue
    src = lines_of(path)
    i = 0
    while i < len(src):
        if re.match(r'^[A-Za-z_][\w:<>,\s\*&~]*\([^;]*\)\s*(const)?\s*(override)?\s*$', src[i]) \
                and i + 1 < len(src) and src[i + 1].strip() == '{':
            depth, j = 0, i + 1
            while j < len(src):
                depth += src[j].count('{') - src[j].count('}')
                if depth == 0:
                    break
                j += 1
            length = j - i + 1
            if length > 150 and any(i + 1 <= n <= j + 1 for n in nums):
                warnings.append(('long-func', path, i + 1, f'{src[i].strip()[:80]} ({length} lines)'))
            i = j
        i += 1

# every QML file of the Qt module is in both build files
mk = open(os.path.join(ROOT, QT, 'Makefile.am')).read()
ms = open(os.path.join(ROOT, QT, 'meson.build')).read()
for d, _, files in os.walk(os.path.join(ROOT, QT)):
    for f in files:
        if not f.endswith('.qml'):
            continue
        rel = os.path.relpath(os.path.join(d, f), os.path.join(ROOT, QT))
        if rel.startswith('tests/'):
            continue
        for name, text in (('Makefile.am', mk), ('meson.build', ms)):
            if rel not in text:
                errors.append(('qml-build', f'{QT}/{rel}', 0, f'not listed in {name}'))

# shell scripts parse
for d in ('redesign/tests', 'redesign/tests/lib', 'extras/package/redesign'):
    for f in sorted(os.listdir(os.path.join(ROOT, d))):
        if f.endswith('.sh'):
            r = subprocess.run(['bash', '-n', os.path.join(ROOT, d, f)], capture_output=True, text=True)
            if r.returncode:
                errors.append(('shell', f'{d}/{f}', 0, r.stderr.strip().splitlines()[-1]))

# a line can carry `// lint: allow <rule> (reason)` for a deliberate exception
def allowed(rule, path, n):
    src = lines_of(path)
    return n and n <= len(src) and re.search(r'lint: allow\s+' + re.escape(rule) + r'\b\s*\(.+\)', src[n - 1])
errors = [e for e in errors if not allowed(e[0], e[1], e[2])]
warnings = [w for w in warnings if not allowed(w[0], w[1], w[2])]

for kind, items in (('ERROR', errors), ('warning', warnings)):
    for rule, path, n, what in items:
        print(f'{kind} {rule}: {path}{":" + str(n) if n else ""}: {what}')
counts = {}
for rule, *_ in warnings:
    counts[rule] = counts.get(rule, 0) + 1
print(f'{len(errors)} errors, {len(warnings)} warnings'
      + (' (' + ', '.join(f'{k} {v}' for k, v in sorted(counts.items())) + ')' if counts else '')
      + f'; redesign changes since {BASE}')
sys.exit(1 if errors else 0)
