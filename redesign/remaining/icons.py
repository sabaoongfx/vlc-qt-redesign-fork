# Builds the "Every Figma icon" section of redesign/remaining/index.html.
# usage: python3 icons.py icons.json index.html (icons.json: the Icon sheet, cropped into img/icons from Icon.svg of the Figma export)
import html, json, sys

icons = json.load(open(sys.argv[1]))

# Figma use: where the icon's instances sit in the file (read with the Plugin API on 2026-10-30).
# Qt: status (used / part / none) and the glyph or file that draws it.
D = {
 'settings': ('Customize Player button list; settings gear of the side panel controls and buttons; main menu (Customize/More settings); right-click menu', 'used', 'settings glyph (Interface category of Settings), menu redesign-settings.svg / redesign-moresettings.svg'),
 'playback settings': ('Player bar: the playback settings button (Controls), active state when its panel is open', 'used', 'effect_filter glyph: the Extended settings button of the player bar'),
 'preferences': ('Settings sidebar: General and Performance categories (sliders)', 'part', 'General and Performance use effect_filter (playback settings shape), not the sliders icon'),
 'playlist': ('Library sidebar Playlists row (rail and card), playlist rows, file and right-click menus', 'used', 'playlists glyph (sidebar, rail, library card), menu redesign-playlist.svg'),
 'lists': ('Player bar queue button (Controls) and the mini player queue button', 'used', 'playlist glyph: Play Queue button, mini player queue button'),
 'hotkeys': ('Settings sidebar Controls category; main menu Keyboard Shortcuts', 'used', 'menu_keyboard glyph (Controls category), menu redesign-keyboard.svg'),
 'subtitles': ('Player bar subtitles button; Settings Subtitles category; Subtitles entries of the context menus', 'used', 'audiosub glyph (Languages and tracks button, Subtitles category), menu redesign-subtitle.svg'),
 'audio': ('Player bar audio button; Settings Audio category; Audio entries of the context menus', 'used', 'visualization glyph (audio button, Audio category), menu redesign-audio.svg'),
 'play': ('Play pill of the player bar, the play component, mini player hover controls', 'used', 'play_filled glyph (PlayButton, mini player), Figma transport outline'),
 'playback': ('Settings Playback category; side panel Playback tab; Play entries of the context menus', 'used', 'play glyph (Playback category), menu redesign-play.svg / redesign-playback.svg'),
 'pause': ('Pause state of the play component', 'used', 'pause_filled glyph, menu redesign-pause.svg'),
 'next': ('Player bar, mini player hover controls, right-click menu', 'used', 'next glyph (Figma transport outline), menu redesign-next.svg'),
 'stop': ('Customize Player button list; right-click menu', 'used', 'stop glyph, menu redesign-stop.svg'),
 'previous': ('Player bar, mini player hover controls, right-click menu', 'used', 'previous glyph (Figma transport outline), menu redesign-previous.svg'),
 'forward-10-sec': ('Customize Player button list only (the Player frames have no 10 s buttons)', 'used', 'skip_for glyph: the 10 s forward button of the default bar'),
 'forward-15-sec': ('Music player bar (Player - Music); Customize Player button list', 'none', 'not in the font: the music player uses the 10 s buttons'),
 'backward-10-sec': ('Customize Player button list only', 'used', 'skip_back glyph: the 10 s back button of the default bar'),
 'backward-15-sec': ('Music player bar (Player - Music); Customize Player button list', 'none', 'not in the font: the music player uses the 10 s buttons'),
 'refresh': ('Subtitles side panel (refresh the output devices); folder context menu (Resync)', 'used', 'ic_fluent_arrow_sync_24_regular glyph (tracks picker refresh)'),
 'replay': ('Mini player at the end of playback; Customize Player button list', 'none', 'not in the font; the mini player has no replay state'),
 'recent': ('Library sidebar Recent row; main menu Open Recent', 'used', 'history glyph (rail and library card Recent, Privacy category), menu redesign-recent.svg'),
 'volume': ('Player bar mute button (high)', 'used', 'volume_high / medium / low / zero / muted glyphs'),
 'close': ('Window close, Settings and dialog close, side panels, mini player, resume card', 'used', 'window_close and close glyphs'),
 'move': ('Drag handle of the queue rows (side panel queue and mini player queue)', 'none', 'not in the font: queue rows have no drag handle'),
 'minimize': ('Window button of every top bar', 'used', 'window_minimize glyph'),
 'maximize': ('Window button of every top bar', 'used', 'window_maximize glyph'),
 'fullscreen': ('Top bar fullscreen button', 'used', 'fullscreen / defullscreen glyphs (also the library card pop-out)'),
 'home': ('Library sidebar Home row (active state filled)', 'used', 'home / home_filled glyphs'),
 'folder': ('Top bar folder name, sidebar folders, Settings Library category, folder tiles, menus', 'used', 'ic_fluent_folder_open_24_regular glyph (folder tiles, top bar, mini player), menu redesign-folder.svg'),
 'new folder': ('Folder context menu: Add Folder', 'used', 'medialibrary_add glyph'),
 'sidebar': ('Top bar sidebar toggle (left/right, active)', 'used', 'panel_left glyph; the top bar draws SidebarGlyph from the user\'s SVGs'),
 'album': ('Library sidebar, Music section', 'none', 'not in the font: Music is a folder tree, no album rows'),
 'expand-sidebar': ('not placed in any frame', 'none', 'not needed'),
 'collapse-sidebar': ('not placed in any frame', 'none', 'not needed'),
 'music': ('Library sidebar, Music section', 'none', 'not in the font (songs is used for Music)'),
 'video': ('Settings Video category; Add Subtitles to Playlist rows; Video entries of the menus', 'part', 'menu redesign-video.svg; the Video category uses topbar_video (the videos shape)'),
 'songs': ('Library sidebar Music row (active filled, selected)', 'used', 'topbar_music / topbar_music_filled glyphs'),
 'videos': ('Library sidebar Videos row (active filled, selected)', 'used', 'topbar_video / topbar_video_filled glyphs'),
 'streaming': ('Library sidebar Network row; Settings Network category; Open Network Stream in the menus', 'used', 'topbar_network / topbar_network_filled glyphs, menu redesign-network.svg'),
 'tv': ('not placed in any frame', 'used', 'tv glyph: program button of the player bar'),
 'divider': ('Top bar, between the menu and the folder name', 'used', 'drawn as a 1px line in the top bar'),
 'chevron': ('Settings dropdowns and rows, side panel cards (expand/collapse), sidebar crumbs, submenu arrows', 'used', 'chevron_up / chevron_down and ic_fluent_chevron_* glyphs, Settings redesign-chevron PNGs'),
 'arrow': ('Library sidebar back / forward', 'used', 'back glyph (page header and library card back/forward)'),
 'upload': ('not placed in any frame', 'none', 'not needed'),
 'open': ('Library sidebar pop-out button; mini player pop-out', 'part', 'the pop-out button uses the fullscreen glyph'),
 'repeat': ('Queue header (side panel); Customize Player button list', 'used', 'repeat_all glyph'),
 'shuffle': ('Queue header; Customize Player button list; playlist context menu Shuffle', 'used', 'shuffle glyph'),
 'more': ('Top bar menu button, library sidebar, media and playlist rows, Setting Preset', 'used', 'more / ellipsis glyphs'),
 'vlc': ('Top bar of every window, onboarding', 'used', 'the VLC cone picture'),
 'add': ('Library sidebar Add, queue add, New Playlist, folder context menu', 'used', 'add glyph (rail, library card, mini player queue)'),
 'remove': ('Queue rows (side panel and mini player)', 'used', 'remove glyph (mini player queue)'),
 'view': ('not placed in any frame', 'none', 'not needed'),
 'link': ('Video Crop card: the aspect link', 'part', 'drawn as two rounded rectangles in the crop card (no glyph)'),
 'check': ('Every menu with a ticked entry, sorting options, view options, side panel lists, dropdowns', 'used', 'check / ok glyphs, Settings redesign-check PNG'),
 'sort': ('Library sidebar sort; queue header', 'used', 'topbar_sort glyph (page header and card sort)'),
 'search': ('Library sidebar search, Settings search, Keyboard Shortcuts search', 'used', 'search glyph'),
 'zoom': ('Customize Player button list', 'none', 'not in the font'),
 'artist': ('Mini player artist line; library sidebar Music', 'part', 'artist rows use VLC\'s stock profile_new glyph'),
 'profile': ('Main menu (Profiles); Profiles frame', 'used', 'menu redesign-profile.svg'),
 'accessibility': ('not placed in any frame', 'none', 'not needed'),
 'info': ('Settings row hints (i), Customize Player list, Info entries of the menus', 'used', 'info glyph (Settings hints), menu redesign-about.svg'),
 'interface': ('Settings Interface category', 'part', 'the Interface category uses the settings glyph'),
 'subtitle': ('Add Subtitles to Playlist rows (subtitle files)', 'none', 'not in the font: the flow is not built'),
 'file': ('Main menu Open File(s); right-click menu', 'used', 'menu_file glyph, menu redesign-file.svg / redesign-openmedia.svg'),
 'swap': ('Main menu Convert; file context menu; subtitle rows hover', 'used', 'menu_convert glyph, menu redesign-convert.svg'),
 'window': ('not placed in any frame', 'none', 'not needed'),
 'wrench': ('not placed in any frame', 'none', 'not needed'),
 'paint': ('Main menu Customize Player', 'used', 'menu_brush glyph, menu redesign-customize.svg'),
 'grid': ('Library sidebar view toggle; View Options', 'used', 'grid glyph'),
 'list': ('Library sidebar view toggle; View Options', 'used', 'list glyph'),
 '0': ('Empty slot of the option rows (no icon)', 'used', 'rows without an icon'),
 'speed': ('Customize Player button list', 'none', 'not in the font'),
 'record': ('Settings Recording category; Customize Player list; right-click menu', 'used', 'record glyph, menu redesign-record.svg'),
 'snapshot': ('Customize Player button list', 'none', 'not in the font'),
 'queue': ('Queue header; Add to Queue in the file and playlist menus', 'used', 'enqueue glyph'),
 'chapters': ('Side panel chapters list; Customize Player list', 'none', 'not in the font'),
 'bookmarks': ('Side panel bookmarks; Customize Player list', 'part', 'bookmark glyph (bookmark button of the bar), no bookmarks panel'),
 'bookmark': ('Customize Player button list', 'used', 'bookmark glyph'),
 'spectometer': ('Audio Visualizer picker', 'none', 'not in the font: the picker is not built'),
 'spectrum': ('Audio Visualizer picker', 'none', 'not in the font: the picker is not built'),
 'scope': ('Audio Visualizer picker', 'none', 'not in the font: the picker is not built'),
 'waveform': ('Audio Visualizer picker', 'none', 'not in the font: the picker is not built'),
 'PiP': ('Customize Player button list', 'used', 'pip glyph: picture in picture button'),
 'HDR': ('Customize Player button list', 'none', 'not in the font'),
 'EQ': ('EQ presets list (17 presets: classical, club, dance, full bass, ...)', 'none', 'not in the font: the presets list is not built'),
 'thumbnail': ('Placeholder covers of media rows and the library sidebar', 'used', 'cover placeholders of the library'),
 'favorite': ('File and playlist context menus; Customize Player list', 'none', 'not in the font: no favourites backend'),
 'edit': ('Keyboard Shortcuts rows; Subtitles side panel external tracks', 'used', 'edit glyph (tracks picker external tracks)'),
 'save': ('Playlist context menu (Export)', 'none', 'not in the font: Export Playlist has no icon'),
 'disc': ('Main menu Open Disc', 'used', 'menu_disc glyph, menu redesign-disc.svg'),
 'capture-device': ('Main menu Open Capture Device', 'used', 'menu_capture glyph, menu redesign-capture.svg'),
 'plugins': ('Settings Extensions category', 'part', 'the Extensions category uses the add glyph'),
 'privacy': ('Settings Privacy category', 'part', 'the Privacy category uses the history glyph'),
 'quit': ('Right-click menu Quit; Customize Player list', 'used', 'menu redesign-quit.svg'),
 'ui': ('Right-click menu Hide UI', 'used', 'menu redesign-hideui.svg'),
 'genre': ('Library sidebar, Music section', 'none', 'not in the font: no genre rows'),
}
missing = set(icons) - set(D)
assert not missing, missing

LABEL = {'used': ('used', 'In Qt'), 'part': ('part', 'Partly'), 'none': ('none', 'Not in Qt')}
groups = {k: [] for k in LABEL}
for name, e in icons.items():
    groups[D[name][1]].append(name)

def card(name):
    e = icons[name]; fig, st, qt = D[name]
    cls, tag = LABEL[st]
    variants = [' '.join('two-tone' if part == 'yes' else part for part in v.split('/')) for v in e['variants'] if v != 'default']
    var = f'<br><span class="dim">Variants: {html.escape(", ".join(dict.fromkeys(variants)))}</span>' if variants else ''
    shown = 'blank' if name == '0' else name
    return (f'<figure class="icon {cls}"><img loading="lazy" src="img/icons/{e["file"]}" alt="{html.escape(shown)} icon">'
            f'<figcaption><b>{html.escape(shown)}</b> <span class="tag {cls}">{tag}</span>'
            f'<br>Figma: {html.escape(fig)}<br>Qt: <span class="dim">{html.escape(qt)}</span>{var}</figcaption></figure>')

n = {k: len(v) for k, v in groups.items()}
out = [
 '<h2 id="all-icons">Every Figma icon: where it is used</h2>',
 f'<p class="lede">All {len(icons)} icons of the Figma Icon sheet ({sum(len(e["variants"]) for e in icons.values())} variants), with the frames that '
 'place them (read from <a href="https://www.figma.com/design/3AjlB7EG9I8vrZ864Yk8wV/VLC-Redesign--Community-">the Figma file</a> on 2026-10-30: 3,053 icon instances) and the glyph or picture that draws them in Qt. '
 '8 icons are on the sheet but placed in no frame. In the Customize Player frames the list of available buttons sits in a layer named '
 '"Add Subtitles to Playlist/Folder"; it is called the Customize Player button list here.</p>',
 f'<div class="legend"><span><span class="tag used">In Qt</span> {n["used"]} drawn from the Figma outline or picture</span>'
 f'<span><span class="tag part">Partly</span> {n["part"]} another icon stands in</span>'
 f'<span><span class="tag none">Not in Qt</span> {n["none"]} no glyph yet</span></div>',
]
for k, title in (('none', 'Not in Qt'), ('part', 'Partly'), ('used', 'In Qt')):
    out.append(f'<h3>{title} ({n[k]})</h3>')
    out.append('<div class="icons">')
    out += [card(x) for x in sorted(groups[k], key=str.lower)]
    out.append('</div>')
section = '\n'.join(out) + '\n'

css = '''.tag.used { color: #3f9b5b; } .tag.none { color: var(--todo); }
.icons { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 12px; margin-bottom: 8px; }
.icon { margin: 0; background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 10px; display: grid; grid-template-columns: 56px minmax(0, 1fr); gap: 10px; align-items: start; }
.icon img { width: 56px; height: 56px; padding: 10px; border-radius: 8px; background: #141414; display: block; }
.icon figcaption { font-size: 12.5px; line-height: 1.45; overflow-wrap: anywhere; }
.icon figcaption b { font-size: 13.5px; }'''

page = open(sys.argv[2]).read()
START, END = '<!-- icons -->\n', '<!-- /icons -->\n'
if START in page:
    a = page.index(START); b = page.index(END) + len(END)
    page = page[:a] + START + section + END + page[b:]
else:
    anchor = '<h2>Frames with no Qt screen yet</h2>'
    assert page.count(anchor) == 1
    page = page.replace(anchor, START + section + END + anchor)
if '.icons {' not in page:
    old = '.tag.used { color: #3f9b5b; } .tag.none { color: var(--todo); }'
    assert page.count(old) == 1
    page = page.replace(old, css)
open(sys.argv[2], 'w').write(page)
print(n)
