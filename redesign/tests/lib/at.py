#!/usr/bin/env python3
# AT-SPI helper: at.py tree | geom | audit | controls | press NAME [nth] | setrow LABEL=VALUE | dump-file PATH
import sys, gi, time
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
elif cmd == 'apps':
    d = Atspi.get_desktop(0)
    for i in range(d.get_child_count()):
        a = d.get_child_at_index(i); print(a.get_name() if a else None)
elif cmd == 'setrow':
    # change one Settings row to another value (redesign/tests/settings_scenes.py): the row's control
    # carries the row label as its accessible name (SettingsRows::addRow). VALUE is used by text fields
    # (the new text), "dialog" by colour buttons (types a colour into Qt's colour dialog), "child:N" by
    # rows of plain buttons (presses the Nth, e.g. the accent swatches); check boxes toggle, spin boxes
    # step once, combo boxes move to the next item (the previous one when on the last).
    # Prints: setrow<TAB>label<TAB>role<TAB>old<TAB>new (or "no row: label", exit 2)
    import subprocess
    label, _, value = sys.argv[2].partition('=')
    label = label.replace('_', ' ')
    S = Atspi.StateType
    def showing(n):
        try:
            return n.get_state_set().contains(S.SHOWING)
        except Exception:
            return False
    def key(k):
        subprocess.run(['env', '-u', 'WAYLAND_DISPLAY', 'xdotool', 'key', k])
    def text_of(n):
        try:
            t = n.get_text_iface()
            return t.get_text(0, t.get_character_count()) if t else ''
        except Exception:
            return ''
    def descendants(n):
        out = []
        walk(n, 0, out)
        return [d for _, d in out[1:]]
    def combo_state(n):
        # (items, selected index) from the combo's list child; ([], -1) when Qt does not expose it
        for d in descendants(n):
            if d.get_role_name() in ('list', 'list box', 'menu'):
                items = [d.get_child_at_index(i) for i in range(d.get_child_count())]
                sel = [i for i, it in enumerate(items) if it and it.get_state_set().contains(S.SELECTED)]
                return [(it.get_name() or '') for it in items if it], (sel[0] if sel else -1)
        return [], -1
    hits = [n for _, n in nodes() if (n.get_name() or '') == label and n.get_role_name() != 'label']
    hits = [n for n in hits if showing(n)] + [n for n in hits if not showing(n)]
    if not hits:
        print('no row:', label); sys.exit(2)
    n = hits[0]
    role = n.get_role_name()
    # a row widget holding the real control (a path field with Browse, swatches): use what is inside
    if role in ('panel', 'filler', 'unknown', 'grouping'):
        inner = [d for d in descendants(n) if d.get_role_name() in ('text', 'entry', 'password text', 'push button', 'button', 'toggle button')]
        if value.startswith('child:'):
            buttons = [d for d in inner if d.get_role_name() in ('push button', 'button', 'toggle button')]
            k = int(value.split(':', 1)[1])
            if len(buttons) <= k:
                print('no row:', label, f'(only {len(buttons)} buttons)'); sys.exit(2)
            old = ','.join(str(i) for i, b in enumerate(buttons) if b.get_state_set().contains(S.CHECKED))
            buttons[k].get_action_iface().do_action(0)
            print(f'setrow\t{label}\t{role}\tchecked {old}\tpressed {k}'); sys.exit(0)
        fields = [d for d in inner if d.get_role_name() in ('text', 'entry', 'password text')]
        if fields:
            n, role = fields[0], fields[0].get_role_name()
    old = new = ''
    if role == 'check box':
        old = n.get_state_set().contains(S.CHECKED)
        n.get_action_iface().do_action(0)
        time.sleep(0.3)
        new = n.get_state_set().contains(S.CHECKED)
    elif role in ('spin button', 'slider'):
        v = n.get_value_iface()
        old = v.get_current_value()
        step = v.get_minimum_increment() or 1
        target = old + step if old + step <= v.get_maximum_value() else old - step
        v.set_current_value(target)
        time.sleep(0.3)
        new = v.get_current_value()
    elif role == 'combo box':
        items, idx = combo_state(n)
        old = items[idx] if 0 <= idx < len(items) else text_of(n)
        n.get_component_iface().grab_focus()
        time.sleep(0.3)
        key('Up' if items and idx == len(items) - 1 else 'Down')
        time.sleep(0.4)
        items, idx = combo_state(n)
        new = items[idx] if 0 <= idx < len(items) else text_of(n)
    elif role in ('text', 'entry', 'password text'):
        old = text_of(n)
        n.get_editable_text_iface().set_text_contents(value)
        time.sleep(0.3)
        new = text_of(n)
    elif role in ('push button', 'button') and value == 'dialog':
        # a colour row: its button opens Qt's colour dialog; type the colour, then OK
        n.get_action_iface().do_action(0)
        time.sleep(1.5)
        all_nodes = [x for _, x in nodes()]
        html = [x for x in all_nodes if (x.get_name() or '').replace('&', '').rstrip(':') == 'HTML'
                and x.get_role_name() in ('text', 'entry')]
        if not html:
            print('no row:', label, '(no HTML field in the colour dialog)'); key('Escape'); sys.exit(2)
        old = text_of(html[0])
        html[0].get_editable_text_iface().set_text_contents('#123456')
        time.sleep(0.3)
        ok_btn = [x for x in all_nodes if (x.get_name() or '').replace('&', '') == 'OK' and x.get_role_name() in ('push button', 'button')]
        if ok_btn:
            ok_btn[0].get_action_iface().do_action(0)
        else:
            key('Return')
        new = '#123456'
    else:
        print('no row:', label, f'(role {role} not handled)'); sys.exit(2)
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
