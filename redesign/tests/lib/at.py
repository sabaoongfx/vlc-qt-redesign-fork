#!/usr/bin/env python3
# AT-SPI helper: at.py tree | geom | audit | press NAME [nth] | dump-file PATH
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
elif cmd == 'apps':
    d = Atspi.get_desktop(0)
    for i in range(d.get_child_count()):
        a = d.get_child_at_index(i); print(a.get_name() if a else None)
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
