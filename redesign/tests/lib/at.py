#!/usr/bin/env python3
# AT-SPI helper: at.py tree | geom | audit | controls | press NAME [nth] | setrow LABEL=VALUE | dump-file PATH
import sys, gi, time, warnings
warnings.filterwarnings('ignore', category=DeprecationWarning)
gi.require_version('Atspi', '2.0')
from gi.repository import Atspi

def app():
    d = Atspi.get_desktop(0)
    import os
    for i in range(d.get_child_count()):
        a = d.get_child_at_index(i)
        if a and os.environ.get('APP','vlc') in (a.get_name() or '').lower():
            return a
    return None

def walk(n, depth=0, out=None, maxd=60):
    if n is None or depth > maxd: return
    out.append((depth, n))
    try:
        for i in range(n.get_child_count()):
            walk(n.get_child_at_index(i), depth + 1, out, maxd)
    except Exception: pass

def nodes():
    a = None
    for _ in range(40):
        a = app()
        if a: break
        time.sleep(0.25)
    out = []
    walk(a, 0, out)
    return out

cmd = sys.argv[1]
if cmd == 'tree':
    for d, n in nodes():
        try:
            r = n.get_role_name(); nm = n.get_name()
            ext = n.get_extents(Atspi.CoordType.WINDOW)
            print('  ' * d + f'{r} "{nm}" @{ext.x},{ext.y} {ext.width}x{ext.height}')
        except Exception as e: pass
elif cmd == 'geom':
    # name<TAB>role<TAB>x<TAB>y<TAB>w<TAB>h for every visible, named node (screen coordinates)
    for d, n in nodes():
        try:
            nm = n.get_name() or ''
            e = n.get_extents(Atspi.CoordType.SCREEN)
            if nm and e.width > 0 and e.height > 0:
                print(f"{nm}\t{n.get_role_name()}\t{e.x}\t{e.y}\t{e.width}\t{e.height}")
        except Exception:
            pass
elif cmd == 'audit':
    # accessibility audit of what is on screen, one issue per line: rule<TAB>role<TAB>name<TAB>x,y wxh
    #  name   WCAG 4.1.2: an interactive control without an accessible name (or description)
    #  role   WCAG 4.1.2: something with an action but no control role
    #  target WCAG 2.5.8: an interactive target smaller than 24x24
    #  focus  WCAG 2.1.1: a button-like control that keyboard focus can never reach
    interactive = {'push button', 'button', 'toggle button', 'check box', 'radio button', 'combo box', 'slider',
                   'spin button', 'menu item', 'check menu item', 'radio menu item', 'page tab', 'link',
                   'entry', 'text', 'list item', 'table cell', 'tree item', 'scroll bar'}
    vague = {'unknown', 'filler', 'panel', 'redundant object', 'label', 'image', 'section'}
    S = Atspi.StateType
    for d, n in nodes():
        try:
            # Qt Quick reports no SHOWING/VISIBLE states: hidden items have an empty box
            st = n.get_state_set()
            role = n.get_role_name(); nm = (n.get_name() or '').strip()
            e = n.get_extents(Atspi.CoordType.SCREEN)
            if e.width <= 0 or e.height <= 0:
                continue
            # Qt gives every accessible item SetFocus/ShowMenu: only actions that operate a control count
            try:
                ai = n.get_action_iface()
                acts = sum(1 for i in range(ai.get_n_actions() if ai else 0)
                           if ai.get_action_name(i).lower() in ('press', 'click', 'toggle', 'activate', 'increase', 'decrease'))
            except Exception:
                acts = 0
            if role == 'text' and not st.contains(S.EDITABLE):
                continue
            where = f'{e.x},{e.y} {e.width}x{e.height}'
            if role in interactive or acts:
                if not nm and not (n.get_description() or '').strip():
                    print(f'name\t{role}\t\t{where}')
                if acts and role in vague:
                    print(f'role\t{role}\t{nm}\t{where}')
                if role not in ('list item', 'table cell', 'tree item', 'text', 'entry', 'scroll bar', 'menu item',
                                'check menu item', 'radio menu item') and (e.width < 24 or e.height < 24):
                    print(f'target\t{role}\t{nm}\t{where}')
                if role in ('push button', 'button', 'toggle button', 'check box', 'radio button', 'combo box', 'slider', 'page tab') \
                        and st.contains(S.ENABLED) and not st.contains(S.FOCUSABLE):
                    print(f'focus\t{role}\t{nm}\t{where}')
        except Exception:
            pass
elif cmd == 'controls':
    # every enabled, on-screen control for the contrast check (contrast.py):
    # role<TAB>name<TAB>flags<TAB>x<TAB>y<TAB>w<TAB>h (screen coordinates; flags: c = checked, f = focused)
    roles = {'push button', 'button', 'toggle button', 'check box', 'radio button', 'combo box', 'slider',
             'spin button', 'page tab', 'link', 'menu item', 'check menu item', 'radio menu item'}
    S = Atspi.StateType
    for d, n in nodes():
        try:
            role = n.get_role_name()
            if role not in roles:
                continue
            st = n.get_state_set()
            if not (st.contains(S.ENABLED) and st.contains(S.SENSITIVE)):
                continue
            e = n.get_extents(Atspi.CoordType.SCREEN)
            if e.width <= 0 or e.height <= 0:
                continue
            flags = ('c' if st.contains(S.CHECKED) or st.contains(S.PRESSED) else '') + ('f' if st.contains(S.FOCUSED) else '')
            nm = (n.get_name() or n.get_description() or '').strip().replace('\t', ' ').replace('\n', ' ')
            print(f"{role}\t{nm}\t{flags}\t{e.x}\t{e.y}\t{e.width}\t{e.height}")
        except Exception:
            pass
elif cmd == 'values':
    # name<TAB>role<TAB>current<TAB>min<TAB>max for every on-screen node with a Value interface (sliders:
    # Progress, Volume; spin boxes), then name<TAB>label for every on-screen label (times, counts, titles)
    for d, n in nodes():
        try:
            e = n.get_extents(Atspi.CoordType.SCREEN)
            if e.width <= 0 or e.height <= 0:
                continue
            nm = (n.get_name() or '').replace('\t', ' ').replace('\n', ' ')
            v = n.get_value_iface()
            if v:
                print(f"{nm}\t{n.get_role_name()}\t{Atspi.Value.get_current_value(v):g}\t"
                      f"{Atspi.Value.get_minimum_value(v):g}\t{Atspi.Value.get_maximum_value(v):g}")
            elif n.get_role_name() == 'label' and nm:
                print(f"{nm}\tlabel\t{e.x}\t{e.y}")
        except Exception:
            pass
elif cmd == 'apps':
    d = Atspi.get_desktop(0)
    for i in range(d.get_child_count()):
        a = d.get_child_at_index(i); print(a.get_name() if a else None)
elif cmd in ('rows', 'setrow'):
    # Settings rows (redesign/tests/settings_scenes.py). A row (SettingsRows::addRow) is a widget holding
    # its label, an optional info icon and the control; a combo box is named after its current item, not
    # after the label, so rows are found through their label. Only rows on screen count (the classic pages
    # under Advanced Options reuse labels such as "Font").
    #   rows             label<TAB>role<TAB>value for every row on screen; value: check box 1/0, spin box
    #                    the number, combo box the current item, text field the text, a group of buttons
    #                    the checked ones (name or index)
    #   setrow LABEL=V   change the row once and print setrow<TAB>label<TAB>role<TAB>old<TAB>new (or
    #                    "no row: ..." and exit 2): a check box toggles, a spin box steps once (down at its
    #                    maximum), a combo box takes the next item (the previous one on the last), a text
    #                    field gets V; V = "click:NAME" or "click:N" clicks a button of a group (Theme, accent
    #                    swatches: they react to clicked, which an AT-SPI action does not send), V = "colour"
    #                    sets #123456 through Qt's colour dialog (the row's button opens it modally)
    import subprocess
    S = Atspi.StateType
    def xdo(*a):
        subprocess.run(['env', '-u', 'WAYLAND_DISPLAY', 'xdotool'] + list(a))
    def ext(n):
        return n.get_extents(Atspi.CoordType.SCREEN)
    def on_screen(n):
        try:
            e = ext(n)
            return e.width > 0 and e.height > 0 and e.x >= 0 and e.y >= 0 and n.get_state_set().contains(S.SHOWING)
        except Exception:
            return False
    def click(n):
        e = ext(n)
        xdo('mousemove', str(e.x + e.width // 2), str(e.y + e.height // 2), 'click', '1')
    def kids(n):
        try:
            return [n.get_child_at_index(i) for i in range(n.get_child_count())]
        except Exception:
            return []
    def descendants(n, maxd=6):
        out = []
        walk(n, 0, out, maxd)
        return [d for _, d in out[1:]]
    def text_of(n):
        try:
            # Atspi.Text explicitly: n.get_text resolves to a deprecated Accessible method that returned ''
            return Atspi.Text.get_text(n, 0, Atspi.Text.get_character_count(n)) if n.get_text_iface() else ''
        except Exception:
            return ''
    TEXT = ('text', 'entry', 'password text')
    BUTTONS = ('push button', 'button', 'toggle button', 'check box', 'radio button')
    def combo_state(n):
        # (items, selected index) from the combo's list child
        for d in descendants(n, 3):
            if d.get_role_name() in ('list', 'list box', 'menu'):
                items = [it for it in kids(d) if it]
                sel = [i for i, it in enumerate(items) if it.get_state_set().contains(S.SELECTED)]
                return [it.get_name() or '' for it in items], (sel[0] if sel else -1)
        return [], -1
    def control_of(label_node):
        # the row's control: a sibling of the label that is not the label or the info icon; a container
        # (a path field with Browse, a group of buttons) is returned as it is
        row = label_node.get_parent()
        # a row holds the label, maybe an info icon and the control; a section title sits in the page
        # itself, next to every row (same text as a row: "Deinterlacing")
        if row is None or row.get_child_count() > 4:
            return None
        for c in kids(row):
            if c and c.get_role_name() not in ('label', 'image') and on_screen(c):
                return c
        return None
    def value_of(c):
        role = c.get_role_name()
        if role == 'check box':
            return role, int(c.get_state_set().contains(S.CHECKED))
        if role in ('spin button', 'slider'):
            v = c.get_value_iface()
            return role, (v.get_current_value() if v else text_of(c))
        if role == 'combo box':
            items, i = combo_state(c)
            return role, (items[i] if 0 <= i < len(items) else c.get_name() or '')
        if role in TEXT:
            return role, text_of(c)
        inner = [d for d in descendants(c) if d.get_role_name() in TEXT]
        if inner:
            return 'field', text_of(inner[0])
        buttons = [d for d in descendants(c) if d.get_role_name() in BUTTONS]
        if buttons:
            return 'buttons', ','.join((b.get_name() or str(i)) for i, b in enumerate(buttons)
                                        if b.get_state_set().contains(S.CHECKED))
        return role, ''
    all_nodes = [n for _, n in nodes()]
    labels = [n for n in all_nodes if n.get_role_name() == 'label' and on_screen(n)]
    if cmd == 'rows':
        for l in labels:
            c = control_of(l)
            if c is None:
                continue
            try:
                role, val = value_of(c)
                print(f"{(l.get_name() or '').strip()}\t{role}\t{val}")
            except Exception:
                pass
        sys.exit(0)

    label, _, value = sys.argv[2].partition('=')
    label = label.replace('_', ' ')
    def window_of(n):
        while n is not None and n.get_role_name() not in ('dialog', 'frame', 'window'):
            n = n.get_parent()
        return n
    def activate(n):
        # keys go to the active window: click a label of n's window that is on screen (no effect) first
        w = window_of(n)
        if w is None:
            return
        we = ext(w)
        for l in labels:
            if window_of(l) is not None and ext(window_of(l)).x == we.x:
                e = ext(l)
                if we.y + 60 < e.y < we.y + we.height - 20:
                    click(l); time.sleep(0.4); return
    def type_into(field, text, then=None):
        # set_text_contents is ignored by Qt's line edits: focus the field and type
        activate(field)
        field.get_component_iface().grab_focus()
        time.sleep(0.3)
        xdo('key', 'ctrl+a')
        xdo('type', '--delay', '20', text)
        if then:
            xdo('key', then)
        time.sleep(0.3)
    def find_control(label):
        for l in labels:
            if (l.get_name() or '').strip() == label:
                c = control_of(l)
                if c is not None:
                    return c
        return None
    c = find_control(label)
    if c is None:
        print('no row:', label); sys.exit(2)
    role = c.get_role_name()
    try:
        _, old = value_of(c)
    except Exception:
        old = ''
    if value.startswith('click:'):
        want = value.split(':', 1)[1]
        buttons = [d for d in descendants(c) if d.get_role_name() in BUTTONS]
        target = [b for b in buttons if (b.get_name() or '') == want] or \
                 ([buttons[int(want)]] if want.isdigit() and int(want) < len(buttons) else [])
        if not target:
            print('no row:', label, f'(no button {want} among {len(buttons)})'); sys.exit(2)
        click(target[0]); role = 'buttons'
    elif value == 'colour':
        click(c)  # the dialog is modal: an AT-SPI action would not return until it closes
        time.sleep(1.5)
        dlg = [n for _, n in nodes()]
        html = [n for n in dlg if (n.get_name() or '').replace('&', '').strip() == 'HTML:' and n.get_role_name() in TEXT]
        if not html:
            xdo('key', 'Escape'); print('no row:', label, '(no HTML: field in the colour dialog)'); sys.exit(2)
        old = text_of(html[0])
        # Return ends the edit (the dialog takes the colour on editingFinished) and accepts the dialog
        html[0].get_component_iface().grab_focus()
        time.sleep(0.3)
        xdo('key', 'ctrl+a')
        xdo('type', '--delay', '20', '#123456')
        xdo('key', 'Return')
        time.sleep(0.8)
        print(f'setrow\t{label}\tcolour\t{old}\t#123456'); sys.exit(0)
    elif role == 'check box':
        c.get_action_iface().do_action(0)
    elif role in ('spin button', 'slider'):
        v = c.get_value_iface()
        cur, step = v.get_current_value(), (v.get_minimum_increment() or 1)
        v.set_current_value(cur + step if cur + step <= v.get_maximum_value() else cur - step)
    elif role == 'combo box':
        # open the list with the combo's own action (no click: the row may be scrolled out of view),
        # then move in the popup, which grabs the keyboard, and accept
        items, i = combo_state(c)
        ai = c.get_action_iface()
        names = [Atspi.Action.get_action_name(ai, k) for k in range(ai.get_n_actions())]  # ai.get_name is the Accessible's
        k = next((names.index(x) for x in ('Press', 'press', 'ShowMenu', 'showMenu') if x in names), 0)
        ai.do_action(k)
        time.sleep(0.6)
        xdo('key', 'Up' if items and i == len(items) - 1 else 'Down')
        time.sleep(0.2)
        xdo('key', 'Return')
    else:
        fields = [c] if role in TEXT else [d for d in descendants(c) if d.get_role_name() in TEXT]
        if not fields:
            print('no row:', label, f'(role {role} not handled)'); sys.exit(2)
        type_into(fields[0], value)
        role = fields[0].get_role_name()
    time.sleep(0.5)
    # a combo box is renamed after its new item: read the row again
    labels = [n for _, n in nodes() if n.get_role_name() == 'label' and on_screen(n)]
    c2 = find_control(label)
    try:
        _, new = value_of(c2) if c2 else ('', '')
    except Exception:
        new = ''
    print(f'setrow\t{label}\t{role}\t{old}\t{new}')

elif cmd == 'press':
    arg = sys.argv[2].replace('_', ' ')
    nth = 0
    if '#' in arg:
        arg, n = arg.rsplit('#', 1); nth = int(n)
    def actionable(n):
        try:
            ai = n.get_action_iface()
            return ai is not None and ai.get_n_actions() > 0
        except Exception:
            return False
    # a trailing * matches a prefix (e.g. Back_to_* for the folder crumb)
    match = (lambda nm: nm.startswith(arg[:-1])) if arg.endswith('*') else (lambda nm: nm == arg)
    hits = [n for _, n in nodes() if match(n.get_name() or '') and actionable(n)]
    # prefer what is on screen (a hidden page or menu can carry the same name)
    def showing(n):
        try:
            return n.get_state_set().contains(Atspi.StateType.SHOWING)
        except Exception:
            return False
    hits = [n for n in hits if showing(n)] + [n for n in hits if not showing(n)]
    if len(hits) <= nth:
        print('no match:', arg); sys.exit(1)
    hits[nth].get_action_iface().do_action(0); print('pressed', arg, nth)
