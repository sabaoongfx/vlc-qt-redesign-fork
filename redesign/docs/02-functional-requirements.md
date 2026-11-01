# 02 Functional requirements specification

Version 1.0, 2026-11-02, describing `redesign` at v0.1.6.

## Conventions

- **shall** = mandatory, **should** = desired, **may** = optional.
- IDs are stable: `FR-<AREA>-<NNN>`. A removed requirement is marked *Deleted*, its ID is never reused.
- **Test** names the harness scene in `redesign/tests/scenarios.txt` (checked by `check.py`), a CI
  step, or *manual*. *None* marks a gap (see 07).
- **Status**: *Verified* (seen working in a scene, CI or by hand), *Implemented* (built, not checked
  at runtime), *Partial*.
- Terms: **library** = VLC's media library (indexed folders); **entry point** = a folder the user
  added to the library; **queue** = the play queue (VLC's playlist); **player view** = the full
  player page; **mini player** = the floating card shown in the library while something plays.

---

## 1. Main window (SHELL)

**FR-SHELL-001** The sidebar shall list Home, Videos, Music, Network and Playlists, in that order,
when the media library is available, and only Home and Network without it.
Test: `home-*`, `a11y-home`; unit test `test_navigation_model` (not built in CI). Status: Verified.

**FR-SHELL-002** The sidebar shall be expanded while nothing plays and collapsed while something
plays; the sidebar toggle shall override that until the next state change.
Test: *None*. Status: Implemented.

**FR-SHELL-003** The active sidebar row shall be marked with the accent icon and the full-strength label.
Test: `home-night`, `home-day`. Status: Verified.

**FR-SHELL-004** The window shall use the system title bar by default on every platform; the
interface shall not repeat the window title inside the window while the system title bar is shown.
In fullscreen (no system title bar) the player's top bar shall show the media title.
Test: `edge-bars` (fullscreen title), *manual* for the library title. Status: Verified (2026-11-01).

**FR-SHELL-005** The main window shall open at 1280x800 (85% of a smaller screen), centred.
Test: *None*. Status: Implemented.

**FR-SHELL-006** The interface shall follow the colour scheme chosen in Settings: System, Day or
Night; changing it shall apply without a restart, also to Widgets dialogs and menus.
Test: `home-day`, `home-system`, `prefs-live-day`. Status: Verified.

## 2. Page header and navigation (NAV)

**FR-NAV-001** Each library page header shall show back and forward buttons, the page crumb(s), the
item count, a sort button, a grid/list toggle, a search field and a "..." menu.
Test: `video-grid`, `folder-tree`. Status: Verified.

**FR-NAV-002** In folder trees (Videos, Music) and Playlists, back shall go to the parent and
forward to the child last visited on the current branch; opening another folder starts a new branch.
Other pages, the mouse side buttons and Alt+Left shall use the visit history.
Test: *None*. Status: Implemented.

**FR-NAV-003** The address line shall show the path from the first level to the current folder;
each segment shall open that folder; a long path shall be shortened with "...".
Test: `folder-tree` (geometry). Status: Verified.

**FR-NAV-004** Typing in the search field shall filter the current page (folder level included) as
the user types. A click anywhere in the field box shall focus it.
Test: `search`. Status: Verified.

**FR-NAV-005** Sort shall apply inside a folder; with no sort chosen, folder trees list media by
title A to Z. A sort saved by an older build shall still win.
Test: `sort`. Status: Verified.

## 3. Library: Videos and Music folder trees (LIB)

**FR-LIB-001** Videos shall open on a folder tree whose first level is the library's entry points.
Test: `folder-tree`. Status: Verified.

**FR-LIB-002** A folder level shall list its subfolders first (by name), then its own videos;
banned and missing folders shall not be listed.
Test: `folder-tree`. Status: Verified.

**FR-LIB-003** A single click on a folder shall open it; a single click on a video shall play it and
open the player view.
Test: `video-click`, `video-list-click`. Status: Verified.

**FR-LIB-004** An empty folder shall show an empty-state label.
Test: *None*. Status: Implemented.

**FR-LIB-005** Music shall use the same folder tree with square album covers in grid, list and the
player's library card.
Test: `lib-music-folder*` CI shots. Status: Verified.

**FR-LIB-006** Folder cards shall show no duration; video cards shall show the duration.
Test: `folder-tree`. Status: Verified.

**FR-LIB-007** A video without a thumbnail shall show a dark tinted tile (no orange "new" corner);
the thumbnailer shall wait up to 15 s and seek precisely.
Test: *manual*. Status: Implemented.

**FR-LIB-008** The context menu of a folder shall offer Play, Play as audio, Enqueue, Add to a
video-only playlist, Add to a playlist; of an added folder also "Remove from list".
Test: `folder-ctx-play` (menu shot). Status: Verified.

**FR-LIB-009** *Play* from the context menu of a video page (folder tree, Home rows) shall open the
player view, like a click on a video.
Test: `folder-ctx-play`. Status: Verified (2026-11-01).

**FR-LIB-010** *Play* on a folder shall queue the folder's own media A to Z, then each subfolder's
media the same way, subfolders by name, recursively; banned and missing subfolders shall be skipped.
*Given* `Videos/Shows/The Wand/S01/E01..E12` and nothing directly in `Shows`, *when* the user chooses
Play on `Shows`, *then* `The_Wand_S01E01` starts in the video player.
Test: `folder-ctx-play`. Status: Verified (2026-11-01).

**FR-LIB-011** *Play* on a folder should replace or append to the queue according to a user choice
(today it appends, VLC's default). Status: Open question (12).

**FR-LIB-012** "Mark as watched"/"Mark as unseen" on a folder row shall not crash and shall either
apply to the folder's videos or not be offered. Status: Unverified (cast hazard noted in CLAUDE.md).

## 4. Home (HOME)

**FR-HOME-001** Home shall show Continue Watching (videos with a saved position) and New Videos,
each with See All.
Test: `home-*`. Status: Verified.

**FR-HOME-002** "Remove from list" in Continue Watching shall mark the video unplayed so it leaves
the list; the file shall stay on disk.
Test: *None*. Status: Implemented.

**FR-HOME-003** Without a media library, Home shall show the cone and "Drop a video... Ctrl+O" hint.
Test: `start-nolib`. Status: Verified.

## 5. Network (NET)

**FR-NET-001** Network shall list saved streams with Address and Last played columns.
Test: CI `lib-network-*`. Status: Verified.

**FR-NET-002** "Add Stream" shall be in the page's "..." menu and open the Open network stream
dialog; a saved stream shall appear in the list without a restart.
Test: CI Phase C (menu at 1244,77). Status: Partial (list refresh unverified).

**FR-NET-003** The Open network stream dialog shall follow the Figma frame (title band, URL field,
hint, Cancel/Open).
Test: `open-network`, `open-network-day`. Status: Verified.

## 6. Playlists (PL)

**FR-PL-001** Playlists shall be a top-level sidebar entry listing video and music playlists;
opening one shows "Playlists > name".
Test: *None*. Status: Implemented.

**FR-PL-002** A floating New Playlist button shall open the New Playlist dialog; files may be dropped
or chosen; Save shall create the playlist with or without files.
Test: *None*. Status: Implemented.

**FR-PL-003** The playlist "..." menu shall offer Play, Shuffle (sets random on), Export Playlist
(valid .m3u), Add to Queue, Rename, Delete (with a themed confirmation box).
Test: *None*. Status: Implemented.

## 7. Player (PLAYER)

**FR-PLAYER-001** With controls pinned (default) and windowed, the video shall sit between a 40 px
top bar and a 55 px control bar, both #1B1B1B, always visible.
Test: `player-playing` (video starts at y 40). Status: Verified.

**FR-PLAYER-002** Over the video (fullscreen, or controls unpinned) a bar shall show only while the
pointer is near its edge: the top bar within 2x its height from the top, the control bar within 2x
its height from the bottom; none in between. A bar shall stay while the pointer stays in its zone.
A key press shall show both. While a panel or menu is open, or the pointer is on a bar, the shown
bar shall stay.
Test: `edge-bars`. Status: Verified (fullscreen); unpinned window *None*.

**FR-PLAYER-003** The control bar shall hold: library button, previous, 10 s back, play/pause,
10 s forward, next, times either side of the seek bar, volume, and the right-side panel buttons.
The play button shall be grey while playing.
Test: `player-playing`, `player-paused`. Status: Verified.

**FR-PLAYER-004** Hovering the seek bar shall show a preview card with the frame and time at the
pointer.
Test: `player-seekhover`. Status: Verified.

**FR-PLAYER-005** Right-side bar buttons shall toggle their panel; opening one panel shall close the
play queue.
Test: `panel-tabs`, `queue-open`. Status: Verified.

**FR-PLAYER-006** "Languages and tracks" shall open the tracks picker (Video/Audio/Subtitles tabs,
None, output devices with refresh, external tracks with edit/add, Show Preferences).
Test: `tracks-picker`. Status: Verified.

**FR-PLAYER-007** Effects shall open as side-panel cards: Equalizer, Compressor, Video Essential,
Colors, Crop; the old Effects window stays reachable under Open Advanced Settings.
Test: `effects-video`, `effects-audio`, `effects-gear`. Status: Verified.

**FR-PLAYER-008** A right-click on the video shall open the context menu every time, with hotkey
hints right-aligned.
Test: `rclick-menu`. Status: Verified (X11); see 12 for Wayland.

**FR-PLAYER-009** When a video with a saved position starts, a resume prompt shall show above the
seek bar: "You already watched till HH:MM:SS" and Continue Watching.
Test: `resume-first`, `resume-prompt`. Status: Verified.

**FR-PLAYER-010** The library button (control 0x2B) shall toggle the compact library card left of
the video, with the icon rail (Home, Videos, Music, Network, Playlists, Recent, Add); each section
shall load its model; rows shall play on click and shall be draggable into the queue.
Test: *manual* (drag tested by hand 2026-10-31). Status: Verified by hand.

**FR-PLAYER-011** A saved Default Style control bar from an older build shall gain the library and
10 s buttons automatically.
Test: *None*. Status: Implemented.

**FR-PLAYER-012** On a Wayland session the video shall render through VLC's Wayland EGL output
(window module `qt`, OpenGL `egl_*wl`), never an X11 window.
Test: CI configure `--enable-wayland` + `appimage.sh` check; *manual* playback. Status: Verified 2026-11-01.

## 8. Mini player and queue (MINI)

**FR-MINI-001** While something plays in the library, a 391x338 floating card shall show at the
bottom right with a framed preview, title, transport and a queue button.
Test: `lib-mini-video`, `lib-mini-audio`. Status: Verified.

**FR-MINI-002** The queue button shall open the Queue card above it (count and duration, sort,
clear, add; rows play on click).
Test: *None*. Status: Implemented.

**FR-MINI-003** After playback ends the library shall show no stale mini player.
Test: `lib-after-end`. Status: Verified.

## 9. Settings (PREFS)

**FR-PREFS-001** Ctrl+P (Cmd+, on macOS) shall open Settings centred on the VLC window, on General.
Test: `prefs`. Status: Verified.

**FR-PREFS-002** Settings shall show 13 categories as Figma row pages bound to VLC options; classic
pages shall stay under Advanced Options.
Test: `prefs-cats`, `prefs-all`. Status: Verified.

**FR-PREFS-003** Search shall show only matching rows and hide categories without a match.
Test: `prefs-search`. Status: Verified.

**FR-PREFS-004** Save shall write only rows whose value changed; opening every category and
saving unchanged shall leave every option as it was.
Test: `prefs-save`. Status: Verified.

**FR-PREFS-005** Changing a row and saving shall store the new value and show it when Settings
reopens. Test: *None* (per-setting test proposed in 07). Status: Implemented.

## 10. Dialogs and menus (DLG)

**FR-DLG-001** Widgets dialogs (Open Media, Media Information, Messages, Plugins, Effects, About,
stock message/input/progress boxes) shall use the redesign palette and stylesheet in Day and Night.
Test: CI `dlg-*` shots; *manual* on Windows for stock boxes. Status: Partial.

**FR-DLG-002** Menus shall use the redesign menu style (#181818 card, 48 px rows, right-aligned
shortcuts) and keep the Day/Night palette on Windows.
Test: `main-menu*`, `menu-shortcuts`, `rclick-menu`. Status: Verified.

## 11. Keyboard (KEY)

**FR-KEY-001** The global shortcuts shall work with every compositor (they are window shortcuts by
default): Ctrl+O open, Ctrl+Shift+O open file, Ctrl+F open folder, Ctrl+N network stream, Ctrl+D disc,
Ctrl+C capture, Ctrl+Y save playlist, Ctrl+R convert, Ctrl+S stream, Ctrl+E effects, Ctrl+I media
information, Ctrl+J codec information, Ctrl+M messages, Ctrl+P settings, Ctrl+T go to time,
Ctrl+L play queue, Ctrl+H minimal view, F1 help, F10 menu, F11 fullscreen interface, Ctrl+Q quit,
Ctrl+=/Ctrl+- interface zoom.
Test: Ctrl+P, Ctrl+F, `f` in scenes; the rest *None*. Status: Partial (Ctrl+N on Windows open, 12).

## 12. Installation and packaging (PKG)

**FR-PKG-001** Every package shall install next to VideoLAN's VLC without conflicts: Windows in
`C:\Program Files\VLC juxtopposed` with its own uninstall entry; Linux packages in
`/opt/vlc-juxtopposed` with the command `vlc-juxtopposed`; macOS as "VLC juxtopposed.app".
Test: Linux `install-test` jobs; *manual* Windows/macOS. Status: Verified (Linux).

**FR-PKG-002** The deb, rpm and Arch package shall install with their dependencies on Ubuntu 24.04,
Debian 13, Fedora, openSUSE Tumbleweed and Arch, start, load the Qt interface, have a fresh plugin
cache and no missing library.
Test: `redesign-linux-packages.yml` job `install-test`. Status: Verified (run 41335861451).

**FR-PKG-003** The AppImage shall run natively on Wayland and X11 sessions.
Test: AppImage smoke test (X11); *manual* Wayland. Status: Verified 2026-11-01.

**FR-PKG-004** Releases shall publish fixed-name assets, SHA256SUMS and build-provenance attestations;
full releases shall update the signed apt and pacman repositories.
Test: release workflow. Status: Verified (v0.1.6: release run 41344525346; InRelease and the pacman db verified against KEY.gpg).
