# CLAUDE.md

Working notes for the VLC Qt redesign. This repo is a fork of `videolan/vlc`; the work happens on the `redesign` branch.

## Goal

Port the HTML prototype (`sabaoongfx/vlc`, local `..\vlc`) into VLC's real Qt/QML interface (`modules/gui/qt`).
The prototype is the visual reference only; do not copy its data layer. Back the new look with VLC's real models.

## Backlog (user requests, 2026-10-29)

Bugs and changes the user asked for after v0.1.3. All five were done the same day (after v0.1.3) and
checked only by CI: items 1-4 by the screenshots and the Network checks, item 5 (drag) not at all, try
it by hand (drag a row of the player's library card onto the open play queue). Notes kept for context:

1. Music: song covers are 16:9 cards (the Video grid item); they should be square. The music folder tree
   (`VideoFolderTreeDisplay` with `audio: true`) reuses `VideoGridItem`/`VideoGridDisplay`, whose picture
   size is `gridCover_video_width/height`: give the audio tree the album cover size (`gridCover_music_*`)
   in the grid, and square covers in the list and in the player's library card (`CompactLibrary` tiles
   use 1:1 for music already, rows are 32px squares).
2. Network page: remove "Browse devices" (`NetworkStreamsDisplay.qml` button and the `showBrowse` signal in
   `MainDisplay`). Decide whether device browsing stays reachable anywhere (it is VLC's SMB/UPnP browser).
3. Network page: no orange "Add stream" button; put "Add Stream" in the "..." menu on the right of the
   search (`LibraryMenuButton.qml`: today it shows the folder menu everywhere; give it per-page entries,
   Network = Add Stream). The empty page text then points at the "..." menu (or keeps a plain link).
   The CI Phase C clicks Add stream at 676,488 and 286,150: switch it to the menu (1244,77) when this lands.
4. Network list header (the icon, "Url"/Title and the clock icon row): it sits right under the button bar
   with no gap (`net-saved.png`, CI run 40939738061: header at y~189, buttons end at y~167). Add spacing
   above it; once the button bar is gone (item 3) re-check it against the page header line instead.
5. Player library card (`CompactLibrary.qml`): its main purpose is dragging items into the play queue;
   rows only play on click today. Reuse `MLDragItem` (as `VideoAll.qml`) and the queue's drop handling.

## Done 2026-10-29 evening (after the backlog; Windows, CI-checked only where said)

- Sort: the Videos and Music folder trees list their media by title A to Z when no sort is chosen
  (`MLVideoFolderTreeModel::Loader::load`: `VLC_ML_SORTING_DEFAULT` -> ALPHA ascending; the library's
  default put Track 3 first). Seen in CI (`lib-music-folder-night`, run 41010529443). A sort saved by an
  older build (`sortCriteria/...` in the Qt settings) still wins.
- Back/Forward are up/down, not the visit history (user request: "parent to child, back = parent parent"):
  `PageExt.treeNavigation` + `canGoUp`/`canGoDown` + `goUp`/`goDown` signals. Folder trees keep a `_branch`
  (deepest trail of the current branch; another folder starts a new one); Playlists keeps `_lastList` and
  the playlist page shows "Playlists > name"; Network (one level) has both off. Other pages, the mouse side
  buttons and Alt+Left still use History. The player card already did up/down; its crumbs and reopening
  the same child now keep the forward stack. Unchecked at runtime (CI does not click the arrows).
- Lists: `TableViewExt.headerTopPadding` defaults to `margin_normal` (column titles sat on the header line on
  every table; Network's own margin was removed so it does not double). Network list columns are text,
  "Address" and "Last played" (the icons sat centred over nothing). The music tree list says "Songs" /
  "N songs" and uses the album placeholder (`TableColumns.audio`, `VideoListDisplay.audio`). CI shoots
  `lib-music-folderlist-*` now; the video-list hover moved to y 180.
- Dialogs: Qt's stock boxes (QMessageBox questions such as Delete playlist, QInputDialog, QProgressDialog)
  and plain QDialog/QWizard windows were white with light text and blank buttons on Windows (native style
  under the dark palette). `QVLCDialog::styleStockDialogs()` (called in the `DialogsProvider` constructor)
  installs an app event filter that gives every top-level QDialog without its own stylesheet the shared
  window stylesheet on Polish, plus a palette background and label colour (`qvlcframe.cpp`). C++ written
  blind: check it compiles in CI and look at a Delete playlist box on Windows.
- Still open: drag from the player's library card into the queue (CI cannot test it, try by hand); Ctrl+N
  on Windows; the v0.1.3-rc1 pre-release (keep or delete, not answered). CI run 41010529443 was cancelled
  in its screenshot step at the moment of the next push (concurrency is `cancel-in-progress: false`; cause
  not found).

## FIRST on Manjaro: work written on Windows, compiled in CI but not run by hand (2026-10-28)

Status 2026-10-30: steps 1-3 done on Manjaro. `550223c` builds clean; a full harness run has no QML warnings at all
(the blind fixes of the 2026-10-27 list hold) and passes 172/172 after the harness update (`60da4de`). Found and fixed:
global shortcuts that are Qt.ApplicationShortcut (Ctrl+P, Ctrl+N, Ctrl+M...) never fired with the X11 compositor
(offscreen interface window; Ctrl+O/F/Y are window shortcuts and worked): `ShortcutExt` defaults to
Qt.WindowShortcut now (`006bec0`; likely also the open "Ctrl+N on Windows", check there). Harness: the fixture
library is made with Ctrl+F (Videos and Music roots, like a user's; the wizard adds none) and has no history,
`fixture` scenes copy the profile, Settings opens with `key:ctrl+p`, video scenes open the Videos folder first.
Not done: `test_navigation_model` (not built), step 4 (features on a real window).

`git log d3064c2..HEAD` (commits that say "untested"). It compiles in CI (step 0); only a few screens were seen in CI screenshots. Do this in order,
commit each fix on its own, push a code commit before any docs-only one (see the CI note below).

0. CI state (2026-10-28). Run 1 on `938efbd` (40746908202 / ...185 / ...607): all three failed to compile in
   `menus/qml_menu_wrapper.cpp` (Export Playlist: the M3U newline escapes had become real line breaks in the string literals).
   Fixed in `4170fbd`; run 2 on it (40755132685 / ...948 / ...677): Linux build, Linux packages and Windows all PASSED, so all the
   new C++ compiles, links and packages. Its screenshots (artifact `screenshots`) showed the new sidebar (Home, Videos, Music,
   Network, Playlists, expanded while idle), the top bar without cone/menu, and Videos opening on the folder tree, plus two bugs:
   "0 ms" under every folder card (fixed `c79ac2d`: folders report no duration) and the Network page buttons not drawn (fixed
   `ce12e07`: the page and both Figma dialogs had no ColorContext palette, see the gotcha below). Run 3 on `ce12e07`
   (40763153420 Linux, ...534 packages, ...468 Windows) was started 2026-10-28 20:25; check it with `gh run list` and look at
   `lib-video-*` and `lib-browse-*` in its screenshots. Without a build machine, QML is checked with PySide6's `qmlcachegen
   --only-bytecode` and `qmllint` (venv in the Windows scratchpad; CI also runs qmlcachegen, so a QML syntax error fails the build).
   Run 4 (`5371054`, 40767290174 Linux build): CI now runs VLC at `--verbose=1` and a "QML warnings" step lists them (annotations +
   `shots/qml-warnings.txt`). It showed why the Network buttons were blank: `ButtonExt.qml:196/205 Unable to assign [undefined] to
   ButtonExt_QMLTYPE_n` (inline components typed `required property ButtonExt control`; CI's Qt resolves the file's own type to
   several type objects, so every stock button in that build lost icon and text), the same in `ListViewExt.qml:424`, and
   `PageExt.qml:238/244` (crumbs briefly undefined). Fixed in `7069aa2` (`var` properties, `?? []`). Run 5 on `a0d1a8b`
   (40823748465 Linux, ...509 packages, ...497 Windows, 2026-10-29): all three PASSED; the warning list is down to the SVG lines
   below, and the Network page buttons are drawn and sit on the header margins (`a0d1a8b`). Also listed, older and
   CI-only: `Unsupported image format` for every SVG (the CI Qt has no SVG image plugin; the cone and placeholders). Read the list
   after every run: it is the first real view of QML errors on screens the screenshots do not reach.
   Still unseen at runtime: compact library and rail in the player, both dialogs, resume card, mini player queue, menus, the
   Export Playlist file, the 10 s buttons; the unit test `test_navigation_model` has not run (CI does not build tests).
1. `git pull`, `make -C build -j$(nproc)` (it compiles in CI now; a local build still has to be clean). QML load errors do not fail
   the build: run `./build/vlc --verbose=1` and read the log for `is not a type`, `ReferenceError`, `Cannot assign`, `binding loop`.
   New QML files must be in `Makefile.am` AND `meson.build` (both were edited by hand).
2. `redesign/tests/run.sh 'folder-tree|browse'`, then a full run in the background; compare QML warnings with the 2026-10-27 list
   (the blind fixes: `SideNavigationPane.rowLeftPadding`, `PageExt` header padding, `PlaylistButton`, `BrowseDeviceView`, Player blur).
3. Fix the harness: Video scenes (`video-grid`, `search`, `sort`, `video-ctx`, `video-hover/click`, `a11y-video`, `lib-mini-video`,
   showcase `videos*`) click the first card at 390,220 and now land on a folder; sidebar rows moved (Home 75, Videos 121, Music 167,
   Network 213, Playlists 259; the Discover row is gone; `.github/workflows/redesign-build.yml` click targets were shifted by hand too).
   `src/` tests: `modules/gui/qt/tests/test_navigation_model.cpp` was rewritten blind (5 rows with the media library: Home, Videos, Music, Network, Playlists; 2 without).
4. Look at each feature on a real window (the checklist; the Figma frame is named in brackets, all in
   `~/Downloads/VLC Redesign (Community)(1)/`, status per frame in `redesign/remaining/index.html`):
   - Sidebar (Home, Videos, Music, Network, Playlists): expanded while nothing plays, collapsed during playback; the toggle button
     still overrides (`MainDisplay` `pannelVisiblity.stopped`). Discover (Services, URL pages) is no longer reachable.
   - Videos = folder tree [Player-4]: first level = added folders, folder with subfolders AND videos, back/forward, address line
     crumbs, search and sort inside a folder, empty folder label, a video plays on click. Check `History.push` takes the `trail`
     array; "Mark as watched" on a folder row (cast hazard, same as group rows); context menu Play of a folder = its own videos only.
   - Network page: saved streams list, "Add stream" opens the dialog [Open network stream], "Browse devices" opens the old Browse.
     A saved stream must show in the list without a restart (the list model may need a reset event after `MLUrlModel::add`).
   - New Playlist dialog [new playlist]: floating button on the Video and Music playlist lists, drop files, file chooser, Save with
     and without files (`MLPlaylistListModel::create` with an empty list), the name-only playlist.
   - Playlist "..." menu [playlist context menu]: Play, Shuffle (sets random on), Export Playlist writes a valid .m3u, Add to Queue,
     Rename, Delete.
   - Folder "..." menu [folder context menu] on the right of the search (page header and compact card): Add File, Add Folder,
     Resync, Info. The library top bar lost the cone and the menu button (no way into View/Tools/Help/Quit there now: decide).
   - Player: compact library [Player - customize-8, sidebar]: rail left of the video (Home, Videos, Music, Network, Playlists,
     Recent, Add), card with the address line, the bottom-bar library button (new control 0x2B; a saved Default Style should get it
     and the 10 s buttons automatically: check a profile saved by an old build), `panelArea`/video margins with the card open, the
     play queue and tracks panels still placed right, each rail section loads its model (Home = continue watching, Music = Songs/
     Albums/Artists/Genres lists, Network, Playlists, Recent).
   - Control bar: library button, previous, 10 s back, play, 10 s forward, next [play]; the play pill is grey while playing.
   - Resume prompt [continue watching]: at the bottom centre above the seek bar, "You already watched till HH:MM:SS" (needs
     `MediaLib::mediaProgress`; shows "You already watched this" when the library has no progress), Continue Watching resumes.
   - Mini player [Miniplayer]: the queue button opens the Queue card above it (count and duration, sort, clear, add, rows play on
     click). The old docked play queue panel is no longer opened from there. Missing: hover overlay (close, pop-out, prev/play/next),
     drag to reorder.
5. Not built, still open: Onboarding (11 frames), Keyboard Shortcuts dialog, Home rows (Listen Again, Frequently Visited), subtitle
   timeline, waveform seek bar, bookmarks panel, shortcut in the OSD, Setting Presets/Profiles, Add Subtitles to Playlist, audio
   visualizer/HDR/spatializer/stereo-widener/EQ presets frames, Podcasts/Radio in the card, sort/view/pop-out buttons in the card.
6. Dead code to remove once it builds (kept for rebase-ability): `VideoAllDisplay.qml`, `VideoAllSubDisplay.qml`,
   `VideoGroupDisplay.qml`, `SortMenuVideo` grouping, `MLVideoFoldersModel`; `DiscoverDisplay` pages are unreachable.
   Smells left: `useGlobalShortcuts` focus line repeated ten times, the sidebar entries exist in `navigationmodel.cpp` and in
   `LibraryRail.qml`, `MLVideoFolderTreeModel` loads the subfolder list twice per refresh.
7. After checking on a real window, update this file and `redesign/remaining/index.html` (both still say the new screens are untested).

## Linux machine (current, Manjaro KDE) — read this first

- Tree: `~/Documents/vlc-qt-redesign-fork`, LF line endings. Remotes differ from the Windows notes below:
  `origin` = the fork (`sabaoongfx/vlc-qt-redesign-fork`, push here), `upstream` = `videolan/vlc`. `git`/`gh` are on PATH.
- Here VLC IS built and tested locally (the Windows "never run locally" rule does not apply): `make -C build -j$(nproc)`
  (~25 s for QML/C++ changes in the Qt module; QML is compiled into the binary, so rebuild before every capture).
  `contrib/native/` (local medialibrary build) is untracked on purpose.
- Test harness: `redesign/tests/run.sh [scene-regex]` runs each scene of `scenarios.txt` in a headless nested KWin
  (xdotool clicks, AT-SPI `press:Name`, `shot`/`shotwin`/`geom`), then `check.py` (QML warnings, colours and geometry
  measured on the Figma frames, unchanged vlcrc after Settings Save). Output in `redesign/tests/out/run/` (`report.html`);
  each run wipes the previous PNGs. Full run ~25 min (run it in the background). `OUT=<dir>` runs a few scenes without
  wiping the main output; `QPA=wayland` runs VLC as a native Wayland client (what the user's KDE session does; scenes run
  on Xwayland by default, and some bugs only show on Wayland, e.g. the every-other right-click).
  Test runs are always silent (`--aout=adummy`) and log at `--verbose=1`: QML warnings only reach the log from verbosity 1,
  so before 2026-10-27 check.py saw none. Last full run (2026-10-27, first with QML warnings visible): 124 failures, all
  QML warnings: a `SideNavigationDelegate` implicitWidth binding loop (SideNavigationPane.qml:185/288, ~40 scenes, likely
  the collapsed-sidebar `rowLeftPadding`), a `DefaultPageHeader` binding loop (PageExt.qml:112), `PlaylistButton.qml:34`
  playlistWidget undefined, `BrowseDeviceView.qml:139` forceActiveFocus of undefined; on Wayland `Player.qml:668`
  DualKawaseBlur.scheduleUpdate is not a function. Fix these next.
  Do not rebuild while a run is going (scenes use the build tree). The user may be watching something in their own
  `./build/vlc`: never kill or restart it unless asked; rebuilding under it is safe (the running process keeps the old plugin).
- Figma export: `~/Downloads/VLC Redesign (Community)/` (per-screen folders with `figma.png`, `notes.md`; `COMPARISON.md`)
  and `~/Downloads/VLC Redesign (Community) (1)/` (Subtitles side-panel SVGs, render with `rsvg-convert -w 400`).
- Plan and status: `redesign/PLAN.md` (phases 1-5); settings option map: `redesign/SETTINGS-MAP.md`.
- Pushed 2026-10-29 (code head `a0d1a8b`, run 5 green; this CLAUDE.md commit sits on top): `origin/redesign` matches local. Three workflows run on every push to `redesign`
  (Linux build, Windows build, Linux packages); a push whose head commit says `[skip ci]` runs none, so push a code
  commit on its own first (`git push origin <sha>:redesign`) when a harness/docs commit sits on top. One run per
  workflow at a time; a newer push replaces a still-pending run (it shows as "cancelled"), it never stops a running one.
- Commit per fix, `Co-Authored-By` trailer, `[skip ci]` for docs/harness-only commits.
- Harness extras: `SCEN=<file>` runs another scene list, `SKIP_FIXTURES=1` skips the test fixtures and check.py,
  `KWINRULES=<file>` replaces the KWin rules (an empty rules file leaves VLC's own window size and placement; the
  default rules maximise the main window, so window-size tests need it). `redesign/tests/showcase.sh` makes the website
  screenshots from generated media (gradient videos, albums; out/showcase-shots) with `showcase.txt`.
- Local install for the user: `make -C build install` puts the build in `install/` (the configured prefix; excluded in
  `.git/info/exclude`); `~/.local/share/applications/vlc-juxtopposed.desktop` starts it and KDE uses it for video.
  The user removed the official VLC (pacman `vlc`); `lua51` was reinstalled `--asdeps` because this build links it
  (if it goes missing the Lua plugin is recompiled against Lua 5.4 headers and fails to link: delete its objects).
  Refresh the install after changes; the user runs it daily.

## Release (in progress, 2026-10-27)

- Name: **VLC (juxtopposed)** (the user's choice; the design is Juxtopposed's video "I Redesigned VLC After 25 Years",
  https://youtu.be/ERFeOgqk324). Unofficial, not affiliated with VideoLAN: say so wherever it is published.
  First tag `v0.1.0`, a pre-release. Windows + Linux now, macOS later (the user's decision: needs a Qt build for macOS,
  VLC's Mac app is Cocoa). Ask the user before pushing a tag (it publishes the release).
- `.github/workflows/redesign-release.yml` (on `v*` tags): waits for the Windows and Linux-packages runs of the tagged
  commit (a tag run cannot read the redesign branch caches, so it does not build), downloads their artifacts and
  publishes fixed-name assets only, no version in the file names (the tag has it; `VLC-juxtopposed-x64-setup.exe`,
  `-x64-portable.zip`, `-x86_64.AppImage`, `-x86_64.tar.gz`) and SHA256SUMS, like notz, so the website links never
  change (`releases/latest/download`, so releases must not be pre-releases: only `-rc` tags are, since 2026-10-28). The assets are attested (`actions/attest-build-provenance`, from the next release on; v0.1.0/v0.1.1 have none),
  notes show `gh attestation verify <file> -R <repo>`. Tag a commit whose Windows and Linux-packages runs both passed.
- Windows: `build.sh -r` already runs `make package-win32` (zip, 7z, NSIS exe; the image has makensis); the NSIS script
  (`extras/package/win32/NSIS/vlc.win32.nsi.in`) has its own name/folder/registry key/uninstall entry/product id so it
  installs next to VideoLAN's VLC; paths with `${PRODUCT_PUBLISHER}` must be quoted (it has a space). Passing.
- Linux: `.github/workflows/redesign-linux-packages.yml` builds on Ubuntu 24.04 with Qt 6.10 (install-qt-action;
  qtwayland is in the base install, not a module) and calls `extras/package/redesign/appimage.sh <prefix> <src>
  <qmake6> <out>`, which also runs locally: `TOOLS=<dir with linuxdeploy + plugin-qt AppImages> extras/package/
  redesign/appimage.sh install . <qmake6> <out>` (on this machine use a qmake6 wrapper whose QT_INSTALL_PLUGINS has
  no KDE kimg_* plugins, they miss libraries). Learned: apt needs `sudo DEBIAN_FRONTEND=noninteractive` (build-dep hung
  an hour on a debconf question); vlc-cache-gen is in libexec; Qt 6.10 has one `libqwayland.so`; linuxdeploy's strip
  fails on .relr.dyn (NO_STRIP, system strip instead, 287 -> 145 MB); the plugin cache must be made after linuxdeploy
  rewrites the plugins (else every plugin is "stale"); a /usr build has no rpaths, so the script sets `$ORIGIN` rpaths
  with linuxdeploy's own patchelf (LD_LIBRARY_PATH into the AppDir breaks qmake); plugins one directory deeper
  (`plugins/access/rtp/`) need their own `$ORIGIN/../../../..` rule. Passing since `43d2e8b`.
  Qt's TIFF/WebP/MNG image plugins link libtiff.so.5 (absent on Ubuntu 24.04) and linuxdeploy stops on them: a workflow
  step deletes them after the Qt install (dropping the `qtimageformats` module alone did nothing, install-qt-action's
  restore-keys brought back an older cached Qt that still had it). `apt-get build-dep` hangs now and then and hits the
  20 min step timeout (twice): re-run the failed job (`gh run rerun <id> --failed`); a retry in the workflow would help.
- Website additions 2026-10-28 (all pushed to `main`): a second blog post `blog/videos-as-a-folder-tree/` (a design note that says
  plainly the code was never built; update or follow it with a real post once the folder tree runs, and do not let it claim
  behaviour before then); the tour section "Every screen, redrawn" is an autoplay slideshow in `main.js` (STEP 1500 ms, kept in
  step with `.tour-progress.running` in `style.css`), with a fade, prev/next arrows, a pause button, a progress bar, off with
  reduced motion, stopped by any manual move. `style.css` and `main.js` are linked with `?v=N` in `index.html` because
  `_headers` caches them for an hour: bump N when they change.
- Website: separate repo `sabaoongfx/vlc-web` (private, local `~/Documents/vlc-web`, push to `main`), plain HTML/CSS/JS
  for https://vlc.sabaoon.dev on Cloudflare Pages since 2026-10-30 (Git integration: a push to `main` deploys; no build
  command, output `/`; `_headers` has the CSP, security headers and asset caching; `vercel.json` removed; the
  `sabaoon.dev` zone is on Cloudflare, `vlc.sabaoon.dev` is the project's custom domain). Download buttons are filled by `main.js` from the GitHub API (newest release including pre-releases:
  `releases/latest/download` skips pre-releases, which is why releases are full ones); the no-JavaScript fallback links in `index.html` are
  `releases/latest/download/<fixed name>` (no version, never edited, like notz). Screenshots come from
  showcase.sh (WebP 1600 + 800). Audited clean: Lighthouse 100 (mobile perf 98 on the home page), pa11y WCAG2AA 0
  issues, html-validate. Blog: `blog/porting-juxtopposeds-vlc-redesign/` (first person as the user; facts checked
  against the repo; uses Juxtopposed's Figma Settings frame, credited). Keep it accurate when things change.
- Released 2026-10-27: **v0.1.0** (pre-release) on `43d2e8b`, all nine assets published by `redesign-release.yml`. The first
  v0.1.0 (on `18bcace`) was deleted and re-tagged: its Windows build showed only the video, no interface (see the Canvas
  gotcha under Windows CI gotchas). Delete a release with `gh release delete v0.1.0 --cleanup-tag --yes`, then re-tag.
- Released 2026-10-28: **v0.1.1** (pre-release) on `e403c1b`: "Remove from list" in the Continue Watching context menu
  (`MLRecentVideoModel::removeFromHistory`: marks the video unplayed, which drops it from the history; the file stays),
  opening a tracks/audio/effects panel closes the play queue (`ControlBar.applyMenu`), the player is dark for every
  embedded video even with the controls pinned (the Windows default; `Player.qml`/`MinimalView.qml`), Windows build
  without VideoLAN's update check (`build.sh` no longer passes `--enable-update-check`: it pointed at VideoLAN's
  releases). Its assets had versioned copies that were deleted afterwards (fixed names only now).
- Released 2026-10-28: **v0.1.2** on `4662c04` (an empty commit, so CI ran on a head that carries the new release workflow:
  the release workflow waits for runs of the tagged commit, and `[skip ci]` commits have none). Same code as v0.1.1; the
  first release with fixed names only and GitHub attestations (`gh attestation verify <file> -R <repo>` checked: exit 0).
  It was flipped from pre-release to a full release so `releases/latest/download/<name>` works (the website fallback links).
- Not signed: the Windows installer and exe have no Authenticode signature (`Get-AuthenticodeSignature`: NotSigned), so
  SmartScreen warns; the attestation is provenance only, Windows ignores it. Options noted for later: Azure Trusted
  Signing (~$10/month), an OV/EV certificate (~$100-400/year, reputation still builds slowly), SignPath Foundation (free
  for open source; the fork's GPL/VideoLAN relationship may complicate it). Nothing decided; it would be a signing step
  in the Windows workflow before NSIS. Linux files are unsigned too (checksums + attestation only).
- Windows shots (`win-shots.ps1`) play an ffmpeg test video (installed with choco in the workflow) and shoot the tracks,
  audio and play queue panels (`*-player-{tracks,audio,queue}.png`, found by their button descriptions via UI Automation)
  plus `vlc-<scheme>-player.log`. In the Day shots the title and bottom bars look mid-grey (probably the Windows blur over
  the desktop; not checked).
- Open: a retry for the apt hang in the Linux packages workflow.
- Open: Settings top bar is still the system one + Save/Cancel; the Figma window is frameless with a close x and no
  Save/Cancel. The user said leave it for now.

## Folder-tree Videos page with an address line (written 2026-10-28 on Windows, compiles in CI, not run by hand)

**Status: written blind on the Windows machine; it compiles in CI (see the FIRST section). First thing on Manjaro:
`make -C build -j$(nproc)`, fix compile errors, run `redesign/tests/run.sh 'folder-tree|browse'`, look at the shots.**
What exists: `include/vlc_media_library.h` `vlc_ml_list_subfolders/count_subfolders`; `medialibrary/mlvideofoldertreemodel.*`
(`MLVideoFolderTreeModel` derives from `MLVideoGroupsModel`: entry points or subfolders, filtered by the search text and
sorted by name in C++, then the folder's videos via `vlc_ml_list_video_of`; paging spans both; registered in `mainui.cpp`,
`Makefile.am`, `meson.build`); `medialibrary/qml/VideoFolderTreeDisplay.qml` (PageLoader, pages `base` and `folder`, the
inline `VideoFolderLevel` page carries a `trail` of `{id, title}`); `PageExt.crumbs` / `crumbClicked` draw the address line
(own crumb buttons: `VLC.Widgets` cannot import `VLC.Network`, so `NetworkAddressbar` is not reused); `VideoDisplay.qml` has
the single page `folders`; sidebar: Video is a leaf, Playlists is a top-level entry (`navigationmodel.cpp`, `MainDisplay`
page `playlists` = `VideoPlaylistsDisplay`), `tests/test_navigation_model.cpp` rewritten for it (unrun). Unchecked guesses:
`History.push` accepting the `trail` array of objects, the context menu "Mark as watched" on a folder row (the base
`setItemPlayed` casts to `MLVideo`, same hazard as group rows), the Playlists icon (`ic_fluent_apps_list`), a folder of only
subfolders plays nothing from the context menu (`list_media_of` is direct media only).
Harness: scene `folder-tree` + a `check.py` block were added; the other Video scenes (`video-grid`, `search`, `sort`,
`video-ctx`, `video-hover/click`, `a11y-video`, `lib-mini-video`, showcase `videos*`) still click the first card at 390,220 and
now land on the first-level folder card or a subfolder instead of a video: add one `click:390,220 sleep:2.5` to enter the
`Videos` folder and re-measure. Sidebar coordinates in `scenarios.txt` and `.github/workflows/redesign-build.yml` were shifted
for the Playlists row. Also fixed blind in the same commit (from the 2026-10-27 warning list): `SideNavigationPane.rowLeftPadding`
no longer reads the row width (binding loop), `PageExt` header padding uses the page width (binding loop), `PlaylistButton`
called an undefined `playlistWidget`, `BrowseDeviceView.onClicked` guards `currentItem`, `Player.qml` calls
`blurredBackground?.scheduleUpdate?.()`. Re-run the full harness to see which warnings are left.

Compact library in the player (Figma `Player - customize-8`, written blind, compiles in CI, never seen running): `player/qml/Player.qml` shows a
icon rail `player/qml/LibraryRail.qml` (Home, Videos, Music, Network, Playlists, Recent, Add; the active one picks what the card shows, `Player.librarySection`) and a `Loader` with
`medialibrary/qml/CompactLibrary.qml` (own `trail`/forward stack, address line with "..." for long paths, count, search, rows;
a video plays at once, no sort/view toggle yet) left of the video, only on the video stage (`_libraryRail`); the video margin,
`panelArea` and the panels start after them (`_leftInset`). The bottom-bar button is the new control `LIBRARY_BUTTON`
(0x2B, was RESERVED_0X2B; `LibraryButton.qml`, icon `panel_left`, toggles `MainCtx.libraryPanel.visible`, a new `SidePanelCtx`
saved as `library-panel-visible/width`), first in the Default Style video bar (`controlbar_profile_model.cpp`, with a
migration for saved Default Styles). The main sidebar is Home, Videos, Music, Network, Playlists (Discover is no longer in it)
and `MainDisplay` expands it while nothing plays and collapses it during playback (`pannelVisiblity.stopped`).

Original plan (kept for the reasoning):

Source: Juxtopposed's video (the "address line": breadcrumb + back/forward) and Figma `Player-4.png` (`VLC Redesign
(Community)(1)`: `Videos > Shows > The Wand > S01`, folder content below). Decided with the user. Build it on the Linux
machine (compile in ~25 s, harness with nested-folder media), not through Windows CI: the Windows CI has no media library,
a QML load error does not fail a build, and a C++ mistake costs a whole CI run.

- The story: the user adds many folders; a folder with subfolders shows them; a folder with subfolders AND media shows both
  (subfolders first, then its own videos). Clicking a folder goes in, a video plays, a path segment or back goes up.
- Videos page: drop the "All / Playlists" switch (`VideoDisplay.qml` pageModel, sidebar `navigationmodel.cpp` Video
  children All/Playlists); Videos opens straight on the folder view. First level = the added folders (ML entry points,
  `vlc_ml_list_entry_points`). Header = back/forward + clickable path (reuse `network/qml/NetworkAddressbar.qml`,
  `AddressbarButton.qml`) + item count + sort + grid/list + search (already in `PageExt`). Sort and search apply inside a folder.
- Playlists: a separate top-level sidebar entry as in the Figma (Home, Videos, Music, Network, Playlists, Recent, Add
  item); the old Video > Playlists page (`VideoPlaylistsDisplay.qml`) moves there. Music keeps its own Playlists child.
- Backend: the ML already has `VLC_ML_LIST_SUBFOLDERS` / `VLC_ML_COUNT_SUBFOLDERS` (arg: parent folder id; used by the
  UPnP server in `modules/control/upnp_server/ml.hpp`, NOT paginated: `query->all()`) and `vlc_ml_list_folder_media` /
  `vlc_ml_count_folder_media` (paginated). `include/vlc_media_library.h` has no inline wrapper for subfolders yet: add
  them. Qt side: a new `MLVideoFolderTreeModel` (subfolders then videos, an `isVideo`-style role, like
  `MLVideoGroupsModel` which already mixes groups and videos), items `MLFolder` + `MLVideo`.
- Pages are pushed with `History.push([...pagePrefix, "folder"], { parentId, title })` like `VideoAllDisplay.qml` does for
  groups; the path is rebuilt from the History stack (or a folder id chain).
- Known gaps: the ML gives no recursive video count, so a folder with only subfolders looks the same as an empty one (show
  every present, non-banned subfolder); empty-folder state needs a label.
- Test: a nested-folder fixture in `redesign/tests/fixtures.sh` (e.g. Shows/The Wand/S01 with videos, one folder with both a
  subfolder and videos) and a scene in `scenarios.txt` with `check.py` geometry against Player-4.
- Also open (from the same review, see `redesign/remaining/index.html` for the frame list): Onboarding, Keyboard Shortcuts
  dialog, Home rows (Listen Again, Frequently Visited Folders), sidebar Network/Recent/Add item, subtitle timeline, waveform seek
  bar, bookmarks panel + Ctrl+B, shortcut in the OSD, compact library beside the video.
- Sort menus (`8e6442a`, `4bea61f`, unbuilt when written): video pages offer Unwatched/Watched First, Newest/Oldest First,
  Title A-Z/Z-A, URI Asc/Desc; the music tracks page the Figma list minus Disc Number (no ML criterion). `SortControl` entries
  may carry a fixed `order`. Check them in the harness before relying on them.

## Where we are (2026-10-27)

- Done 2026-10-27 (fourth batch): library search field takes clicks (its Templates TextField had no implicit height:
  0px tall; it fills the box now, a tap anywhere in the box focuses it); sort and list/grid buttons centred on the
  search field; main window opens at 1280x800 (85% of a smaller screen) centred instead of 600x420 (a window saved at
  exactly 600x420 is upgraded); Settings opens centred on the VLC window every time (`PrefsDialog::showEvent`; it has a
  transient parent but no parent widget, so Qt centred it on the primary screen once); play queue rows centre the title
  column and hide an empty artist line.
- Phases 1-3 of `PLAN.md` done (harness; Customize Player modal, rounded mini-player video, Browse folder header,
  ML folder buttons; Settings rebuilt as Figma row pages, 13 categories, search, classic pages kept under Advanced Options).
- Phase 4 (pixel polish against Figma, measure with crops, fix, add a `check.py` guard) in progress. Done: player bars
  (40px top / 55px bottom, #1B1B1B, centred controls, 15px times, grey 12-14px window buttons, 10px stage radius),
  library layout (sidebar card x 8-208, rows at x 30/63, page margins 28/24, 20px grid gaps, 16:9 covers, header field
  y 60-93 / separator 110), mini player card (391x338, framed preview, no progress handle), side panel (colours, content-sized tabs, 220x48
  dropdowns, 138x34 fields, 1px #222222 section lines; measured on the `(1)` SVGs), menus (`RedesignMenuStyle`: #181818 card,
  48px rows, label x 52 #8F8F8F, right-aligned spaced shortcuts #6B6B6B, hotkey hints in the right-click menu),
  settings window chrome (50px #090909 header band with search and 16px #969696 title, #0E0E0E body, #181818 sidebar
  card from y 58, 48px rows, label x 58, sections at x 240; band only in the simple view).
  Code smell passes done: shared C++ helpers in `style/redesign.hpp`, QML colour tokens in `VLCStyle`, accent-dim follows the accent.
- In progress: Dialogs. Decided with the user: restyle only (keep VLC's Open Media dialog and its behaviour, no playlist-name
  field, no multi-URL) and keep the system title bar (band drawn inside the window, like Settings). Started with Open Network
  Stream (Network tab of Open Media; Figma `05 Dialogs/Open network stream`: 50px #090909 band, title 14px #8F8F8F at x 34,
  "Network URL" heading #C6C6C6 16px, #6B6B6B hint, #090909 field with #404040 placeholder, dim Cancel pill). Nothing edited yet;
  `scenarios.txt` has uncommitted `open-network`/`open-network-day` scenes (Menu, then click 200,156: Ctrl+N does not reach
  the window in the harness). Fix on the way: the "Clear History" button text is clipped.
  Then: Keyboard Shortcuts, onboarding; then phase 5 (push, Linux + Windows CI, docs, refresh COMPARISON.md).
- Done 2026-10-27 (second batch): video items play on one click (list rows took no clicks: a root HoverHandler);
  Keyboard Shortcuts menu opens the Controls page; empty library pages offer Add Folder (the Video page lists only
  indexed folders, Home's Continue Watching also played files); Figma transport glyphs; side panels as stage cards;
  appearance applies live; empty list submenus say "Not available"; a folder plays its own files before its
  subfolders (core `rdh_compar_type`, keep when rebasing). The seek preview was checked on the user's HEVC episodes and follows the cursor (~90 ms a frame).
- Done 2026-10-27 (third batch): one click opens everything in the library (`GridItem`/`TableViewExt.activateOnClick`,
  default true); right-side bar buttons toggle (`TracksMenu.toggle`, a press outside closes the popup before the
  button's click); pause icon in the right-click menu; seek bar with chapters keeps the field look (chapter breaks), the
  handle is always shown; Languages and tracks opens the Figma tracks picker (`player/qml/TracksPicker.qml`, from the
  user's Subtitles SVGs: Video/Audio/Subtitles tabs, None, output devices with refresh, external tracks with edit/add,
  Show Preferences opens the side panel on the same tab; `TrackListModel` "external" role, `AudioDeviceModel.refresh`,
  `edit` glyph); right-click on the video opens every time (`VideoSurfaceProvider` reports mouse releases on
  `DialogsProvider::releaseMouseEvents`, upstream 64e6301a6c lost in the QML move).
- Audio button vs picker: the bar's audio button still opens the prototype's small menu (tracks + output devices); the
  picker's Audio tab covers the same, ask the user before merging them.
- Done 2026-10-26/27 (user requests): collapsed sidebar centred 48px card; Settings opens on General and is widened to 1078px;
  menu-button Figma Icon Wrapper hover; play button has no press effect; player-bar audio button (AUDIO_BUTTON, popup of
  tracks + output devices); seek bar preview card (`player/seek_preview.*`, preparser thumbnailer); smooth unhinted icons
  (curve rendering); hand cursor on clickable things; no play overlay on library items (`MediaCover.showPlayCover`);
  AT-SPI accessibility audit in the harness; effects as Figma side-panel cards (`player/effects_controller.*`; decided with
  the user: Equalizer, Compressor, Video Essential/Colors/Crop in the panel, the gear opens the panel, the old Effects window
  stays under Open Advanced Settings for Spatializer, Stereo Widener and the rest).
- Smells left on purpose (user chose not to fix): `SPrefsPanel` constructor is ~1140 lines (splitting it would make a large diff
  against upstream), several Widgets stylesheets repeat rules, the `VolumeWidget` gradient colours are inline.
- Left on purpose: sidebar entries / Home rows that need new pages or models (Network, Playlists, Recent, Listen Again),
  side-panel features VLC lacks (sleep timer, reverse), the fullscreen button order in the title bar,
  Figma dialogs with no VLC backend (Add Subtitles to Playlist, New Playlist, Profiles, Setting Preset), menu drop shadows,
  the right-click menu's separators and entry order.

## Windows machine notes (original setup)

## Repos and remotes

- Local tree: `C:\Users\Sab\Documents\Code\vlc-original` (shallow clone, depth 1; upstream is the GitHub mirror `videolan/vlc`).
- `origin` = `https://github.com/videolan/vlc.git` (read-only). `fork` = `https://github.com/sabaoongfx/vlc-qt-redesign-fork` (push here).
- Push only to `fork`, branch `redesign`. A shallow clone can only be pushed to a real fork (the server already has the parent objects).
- Commit identity: `sabaoongfx` / `sabaoongfx@gmail.com`. `gh` and `git` are not on PATH in this shell: add `C:\Program Files\Git\cmd`
  and call `C:\Program Files\GitHub CLI\gh.exe`.
- Large transfers to GitHub/VideoLAN often drop (`early EOF`, HTTP 408). Use `git -c http.version=HTTP/1.1 ...`.
- Add `[skip ci]` to the commit message for docs-only commits so they do not start a build.

## Never run anything locally

Do not build, test or launch VLC on this machine. Everything is verified in GitHub Actions on the fork.
Local edits are text only (QML/C++/YAML/Markdown).

## CI: `.github/workflows/redesign-build.yml`

- Runs on push to `redesign` and on manual dispatch. About 15 minutes now (about 6 with a warm ccache in the early runs).
- Builds inside `registry.videolan.org/vlc-debian-unstable:...` (the image upstream CI uses; it has Qt 6.10 and all deps).
  The container runs `--user root` and needs `git config --global --add safe.directory "$GITHUB_WORKSPACE"`.
- Uploads two artifacts: `vlc-linux-install` (the install tree) and `screenshots`.
- Screenshots (xvfb, 1920x1080, run as an unprivileged `shotuser` because VLC refuses to run as root):
  `day`, `night` (home screen, window resized to 1280x800) and `player-day`, `player-night` (plays a generated 854x480 test video).
  Theme is chosen by writing `[MainWindow] color-scheme-index` (0 system, 1 day, 2 night) to `~/.config/vlc/vlc-qt-interface.conf`.
  VLC is started with `--no-media-library --no-qt-privacy-ask`.
- Typical loop: push, `gh run watch <id>`, `gh run download <id> -n screenshots`, then look at the PNGs.
  Judge UI changes from the screenshots, not from a green check: QML errors usually do not fail the build.
- Library screenshots (`lib-home-*`, `lib-video-*`, `lib-music-*`): the Debian image has no `medialibrary`, so CI builds it as a contrib
  (`contrib/src/medialibrary`, cached) before configuring VLC. Sample media is generated into the XDG Videos/Music dirs; the script
  clicks through the first-run wizard (Next x3, Finish at 979,587 on a 1280x800 screen), which adds those dirs, waits for the scan, then
  relaunches per theme. Nav click targets (1280x800): Home y=62, Video y=108, then All 154 / Playlists 200 / Music 246 / Browse 292.
- Dialog shots: `{day,night}-open.png` (clicks the home Open File button) and `{day,night}-prefs.png` (clicks Preferences in the sidebar).
- Tracks panel shots: `player-*-tracks.png` (clicks the first bottom-left icon).
- Hover shots: `player-*-hover.png` (bottom-left control icon) and `lib-video-*-hover.png` (first video card).
- Extra state shots in the library loop: `lib-network-*`, `lib-sort-*`, `lib-search-*`, `lib-foldermenu-*`, `lib-music-folder(list)-*`, `lib-menu/help/tools-*`, `dlg-about/effects/messages/plugins-*`. Since 2026-10-30 the dialogs are reached with the keyboard: the '...' menu at 20,20 then Up (More, About, Settings, Customize Player from the bottom), Right into More, the Tool&s / &Effects / Plu&gins mnemonics, Ctrl+M, Ctrl+P (Settings sidebar: Controls y 269, Video 406, Audio 454 at 1280x800). Player shots resize to 1280x800: Languages and tracks at 1142,773, audio button 1108,773 (`player-*-tracks-audio` is the audio popup).
- Workflow decided with the user: work in batches. Make several independent changes as separate local commits, push them together once the previous CI run is done, then review all the screenshots from that one run. Build changes to shared pieces (palette, fonts, `ListLabel`) on their own.

## Where the Qt UI lives

- Colours: `modules/gui/qt/style/systempalette.hpp` (shared constants) and `systempalette.cpp`
  (`makeDarkPalette()` / `makeLightPalette()`, keyed by ColorSet x Bg/Fg/Decoration x Primary/Secondary x state).
  `Window` set = sidebar/top bar, `View` set = content area. Accent comes from the `qt-accent-color` option.
- Sizes, radii, spacing, font scale: `modules/gui/qt/style/VLCStyle.qml` (all through `MainCtx.dp()`).
- Main shell: `maininterface/qml/` (`MainDisplay`, `SideNavigationPane`, `SideNavigationDelegate`, `LocalTopbar`).
- Player: `player/qml/` (`Player`, `ControlBar`, `TopBar`, `SliderBar`, `controlbarcontrols/`).
- Library: `medialibrary/qml/`. Dialogs: `dialogs/`. Preferences window: `dialogs/preferences`.
- Icons are one font, `pixmaps/VLCIcons.ttf`, generated by `pixmaps/makeIconFont.py` (FontForge) from `pixmaps/VLCIcons.json`
  and `pixmaps/icons/*.svg`.
- Files use CRLF line endings. Edit with exact single-line string replacements and assert each matches once.

## Status

| Phase | State |
|---|---|
| 0 Foundation (fork, CI, token map) | done |
| 1 Tokens and theme | colours and radii done; Inter is bundled (`pixmaps/InterVariable.ttf`, OFL licence next to it, registered in `assets.qrc` + `Makefile.am`, set as the app font in `qt.cpp`; it registers as family "Inter Variable"; verified in QML and Widgets); icon set deferred on purpose |
| 2 Main window shell | sidebar done and verified in day+night screenshots (200px, 46px rows, 8px radius, 14px labels, accent icon + full-strength label mark the active row); floating rounded panel not done |
| 3 Media library | grid cards done and verified (10px covers, regular 14px titles, 2px accent hover/focus/selected ring in `widgets/qml/GridItem.qml`); library views captured for home, video (grid + list), music; list rows are rounded with regular-weight labels (`TableViewDelegateExt`, `ListLabel`; verified night+day); album detail and artist pages verified (artist list rows inset and rounded, `MusicArtistDelegate`); breadcrumb restyled to the prototype (16px crumbs, regular parents, semibold last, small dim separators, 6px radius; `network/qml/AddressbarButton.qml`, `NetworkAddressbar.qml`) |
| 4 Player | play button (accent pill, dark glyph, rect hit area), slider track colours and 8px seek bar done and verified; seek handle is now a narrow accent bar (`SliderBar.qml`, verified); elapsed/remaining time now sit left/right of the bar in one row (`Player.qml` forces `LeftRightSlider`; verified); icon-button hover is already a rounded square; top bar title is now small (14px, dim) and centered in every layout, falling back to `Player.name` when the media has no title meta (`TopBar.qml`, `Player.qml`) |
| 5 Settings sidebar | done for the chosen scope (Subtitles + Audio tabs, no new backend), verified: `TracksMenu` docks right (full height down to the seek bar); `TracksListPage` has Subtitles/Audio/Video tabs (accent pill for the active tab), an inline Delay row (spin box + Reset) on the Subtitles and Audio tabs, and a drawn playback-speed pill at the end of the tab row. Not done: Video/Playback tabs, equalizer, bookmarks (would need backend wiring; the equalizer dialog is Qt Widgets) |
| 6 Dialogs and preferences | done via palette, verified day+night for Preferences and the Open File dialog: `SystemPalette::updatePalette` builds a `QPalette` from the redesign tokens and applies it with `QApplication::setPalette` (only for the `themePalette` instance, in Day/Night). Category bar is now text pills with an accent active tab (`SPrefsCatList` stylesheet, verified day+night). About dialog fixed and verified day+night (`about.ui` hardcoded white/grey -> palette roles; `help.cpp` swaps the hardcoded rich-text colours for palette Text/Link; the overflow menu in the CI shots reaches it: click 1138,20 then Help then About). Effects/Equalizer, Messages and Plugins dialogs also verified day+night with no further changes (`dlg-*` shots; Escape does not close them, so they stack). Preferences tabs (Audio/Video/Hotkeys), the Effects, Messages and Plugins windows and the toolbar editor are verified day+night with the shared widgets stylesheet. Convert/Stream (Open Media), Media Information, Codec Information and Track Synchronization verified day+night; the Media Information cover placeholder is a palette tile with the faded cone (`CoverArtLabel`, `widgets/native/interface_widgets.cpp`) |
| 7 Polish and release | in progress: day+night review of home, library (grid, list, albums, tracks), player, tracks panel, Preferences and file dialog done; floating sidebar panel intentionally skipped (the content pane's rounded top-left corner over the sidebar is close enough and avoids layout risk). Artist page captured (`lib-artist-*`; album section backgrounds now follow the theme, were pure white in Day; the artist banner is a dark scrim over artwork on purpose). Open: icon set, macOS build, upstream patches. Windows x64 cross-build compiles and packages a portable zip (`.github/workflows/redesign-windows.yml`; artifact `vlc-win64-portable`, ~93 MB; the first run takes ~80-120 min because the prebuilt contrib URL 404s and contribs build from source, the contrib cache is saved right after the build; runs on every push to `redesign` since 2026-10-27; build dir is `win64`, not `x86_64`; a second job runs the portable build on `windows-latest` and uploads the `windows-screenshots` artifact via `.github/scripts/win-shots.ps1`: system/day/night main, Preferences tabs, player; 1024x768 runner; the desktop is captured, UI Automation clicks the tabs; verified System mode: accent palette, ticks, chevrons, start screen; Day/Night shots need the .ini fix, rerun pending) |

`redesign/TOKENS.md` holds the prototype-to-Qt token map and the Phase 1 decisions.

## Windows CI gotchas

- Contrib cache restore: touch every restored file with ONE timestamp (`touch -h -d "@$T"`), otherwise make sees random newer/older pairs and rebuilds all
  contribs (49 min wasted once). Cached build is about 30 min.
- `cargo-c` is installed by `cargo install` into the cargo home, which is not cached, but its `.cargo-c` marker is. rav1e then fails with
  `no such command: capi`. The touch step deletes `contrib/contrib-win64/.cargo-c` so it is rebuilt.
- A job failure skips the cache save and the cache key is immutable once saved; the v2 key holds a complete cache.
- The Windows shots job must start VLC with a fresh `%APPDATA%\vlc` each time or a "restore the playlist" prompt appears after a force-kill.
- The Windows Qt (contrib, static, trimmed) has no `Canvas`: `qrc:/.../Player.qml:972:19: Canvas is not a type` stopped the whole
  player from loading, so only the video showed (every compositor, `--qt-compositor=win7` a blank screen). Linux Qt has Canvas, so
  CI and the harness never showed it. Do not use `Canvas`, `getContext` or `QtQuick.Shapes` (upstream uses neither): corners are a
  `PIPPlayer`-style ring Rectangle, the volume cone thin columns, the crop link icon two rounded rects. Diagnose a Windows UI
  that does not appear with `vlc.exe -vv --file-logging --logfile=%TEMP%\vlc.log <file>` and look for `is not a type`.
- Windows installs live in `C:\Program Files\VLC juxtopposed`; the portable zip and the installer share `%APPDATA%\vlc`
  (`vlcrc`, `vlc-qt-interface.ini`), so settings from older builds carry over (see the control bar profiles gotcha).

## Decisions and gotchas

- `VLCIcons.ttf`: hmtx left side bearings must equal each glyph's xMin (FreeType places glyphs by the bearing); a tool that
  rewrites outlines (fontTools) must recompute them, or icons shift off centre (the menu dots were 6px right).
- Icon glyphs use `Font.PreferNoHinting` + `Text.CurveRendering` (IconLabel, IconToolButton/IconButton fonts, PlayButton):
  native rendering hinted them to sharp corners with subpixel fringes. A full `font:` assignment drops the hinting
  preference, so set it on the control's font too.
- Live palette changes (theme/accent switched in Settings): Widgets stylesheets with colours as text, `palette()`
  references and palette-coloured pixmaps are built once; use `Redesign::liveStyleSheet` / `onPaletteChange`
  (`style/redesign.hpp`, they listen on qApp: styled child widgets get no palette events; stylesheets are rebuilt
  first because re-setting one restores its widgets' palettes). `qt-accent-color` is a variable on the intf that
  each `SystemPalette` listens to; `prefs-live-day` checks the window matches one opened in Day.
- Transport glyphs (previous/next/play/pause) are the Figma fills grown by their 1.5px round stroke at the Figma
  sub-pixel positions in a 24px box (`pixmaps/icons/redesign/*.svg` hold the same outlines); the play button draws
  its glyph at 24px.
- The play queue and tracks panel are cards in `Player.panelArea` (8px inside the stage).
- Hand cursor: a `HoverHandler` on `TableViewDelegateExt`'s root kept every click from reaching the row's TapHandler (in a z:-1
  child); put it next to the TapHandler. Library video items activate on a plain click (`activateOnClick`), like the prototype.
- Qt Quick accessible nodes report no SHOWING/VISIBLE states; hidden ones have a 0x0 box (`at.py audit` relies on that).
  Qt gives every item SetFocus/ShowMenu actions; only Press/Toggle/Increase... mean a control. AT-SPI calls buttons "button".
- QMenu ignores its maximum width when laying out rows: `RedesignMenuStyle::sizeFromContents` caps them and labels elide.
  Sections (`addSection`) are drawn as 11px spaced caps (`SH_Menu_SupportsSections`).
- Contrast (check.py, information only): Figma greys below WCAG AA are kept on purpose (hint #6B6B6B ~3.3-3.6:1, inactive tab
  icons ~1.9:1).

- Settings (`dialogs/preferences/simple_preferences.cpp`): `SettingsRows` builds Figma rows bound to real options via
  `ConfigControl`; row controls go in `rowControls` and are written on Save only if their value differs from what they
  first showed (`rowInitial`), so they never undo the classic page under Advanced Options. Options the classic Save code
  writes itself (`volume-save`, `audio-filter`, `freetype-shadow-opacity`, `qt-fullscreen-screennumber`, `intf`) are not
  rows. Panels are applied in category order. The sidebar reacts to `toggled` (AT-SPI presses toggle, not click).
- Fixed upstream Save bugs (found by `prefs-save`): list combos showing the first choice for an out-of-list value, and
  font combos rewriting a generic family. Keep both fixes when rebasing.
- Video surfaces cannot be clipped: rounded video corners are covered by a ring/canvas in the surrounding colour
  (`PIPPlayer.cornerRadius/cornerColor/cornerSpill`, the player stage corners in `Player.qml`).
- `Player.qml` overrides the ControlBar's bottomPadding; `MainDisplay` overrides the sidebar pane's topPadding.
- Qt Quick Controls `indicator`/`background`/`contentItem` are deferred: a grouped override (`indicator.x:`) from a
  derived file is silently ignored. Add a property on the base component instead (`ComboBoxExt.indicatorRightMargin`).
- `SliderBar.showHandle` hides the handle via opacity (its `visible` is driven by hover states).
- Harness without a graphical login (machine at the SDDM greeter, shell env says XFCE): `run.sh` makes a private `XDG_RUNTIME_DIR`, `inner.sh` pins `XDG_CURRENT_DESKTOP=KDE` (else Qt loads the GTK theme and its ATK bridge hides the tree from `at.py`) and runs
  spectacle on Wayland (as an X11 client it hangs there).
- Harness: `at.py press` prefers on-screen matches; Widgets QMenu items are not reachable by AT-SPI (click by position).
  AT-SPI presses toggle without a click: controls wired to `clicked` (e.g. the Simple/All/Expert radios) need `click:x,y`
  (get positions with a `geom:` action first).

- TabButton palette is counter-intuitive: `Fg Primary` is the dimmed 60% colour, `Fg Secondary` is full strength. The active nav row is
  `highlighted` (set by a Binding), not `checked`.
- Stock `Widgets.ButtonExt` / `ActionButtonOverlay` rendered invisible inside `TracksListPage` (the old speed button and Reset); the tracks panel uses small
  hand-drawn `T.AbstractButton`s instead. The player overlay stays dark in the day theme.
- The player track panel is `player/qml/TracksMenu.qml` (a `T.Popup` hosting a `StackView`) opened by `controlbarcontrols/LangButton.qml`;
  its pages are `TracksListPage` (tabs), `TracksPageAudio`, `TracksPageSubtitle`, `TracksPageSpeed`. The equalizer / video effects dialogs
  (`dialogs/extended`) are Qt Widgets `.ui` files, so QML tokens do not reach them.
- Widgets dialogs (Preferences, file pickers, message boxes) get their look from `makeWidgetsPalette()` in `style/systempalette.cpp`.
  `QStyleHints::setColorScheme` did nothing on this Fusion build. `VLCStyle.qml` has two `SystemPalette`s (`themePalette`, `darkPalette` = fixed Night);
  only `themePalette` may set the application palette or Day mode turns dark.
- QML Figma colours live in `VLCStyle.figmaDark`/`figmaDay` (`VLCStyle.figmaColors(isDark)`), the accent-dim in `VLCStyle.accentDim(accent, isDark)`;
  do not add colour literals to QML files.
- Shared Widgets helpers live in `style/redesign.hpp` (`Redesign::isDark`, `mix` and the fade amounts that turn the text colour into the Figma
  greys, `darkCard`/`darkRaised`, `accentDim`, `glyphPixmap` for VLCIcons glyphs); use them instead of new copies.
- Widgets `QMenu` popups (`VLCMenu`, `QmlMenuBarMenu` in `menus/`) are drawn by `RedesignMenuStyle` (`menus/menus.hpp`, code in `menus.cpp`), a
  QProxyStyle: a stylesheet cannot colour or right-align the shortcut. A style does not cascade to submenus like a stylesheet; `apply()` installs
  an event filter (ChildPolished) and also applies to existing child menus (children are polished before their parent reports them).
  Hotkey hints are appended to action text after a tab (`hotkeyHint()`), never set as QAction shortcuts (the hotkeys module handles the key).
- Fonts: Inter ships as static Light/Regular/Medium/SemiBold/Bold (`pixmaps/Inter-*.ttf`), not the variable font (Qt exposed only its Regular
  instance). Qt resolves every weight correctly (checked with a diagnostic in CI), but Qt Quick Controls do not always follow
  `QApplication::setFont()`: some DemiBold/Bold labels inside Controls (Home section headings, the Open File button) kept the platform font.
  The base components (`LabelExt`, `ButtonExt`, `TextToolButton`, `ComboBoxExt`, `TextFieldExt`, `SpinBoxExt`) therefore set
  `font.family: VLCStyle.fontFamily` explicitly (verified: Home headings and the Open File button are Inter in the CI screenshots).
- Widgets windows: `redesignWidgetsStyleSheet()` in `widgets/native/qvlcframe.cpp` styles every `QVLCDialog` and `QVLCFrame` (rounded buttons and
  line edits, accent pill tabs, group boxes, thin scroll bars, accent sliders). Combo/spin boxes, check boxes, radio buttons, item views and group titles are styled too (the tick and chevrons are PNGs,
  `pixmaps/prefs/redesign-*.png`: SVG `image:` urls did not render in CI). The About dialog has its own stylesheet in `about.ui`.
- The Widgets palette is applied in System mode too (dark/light from `QStyleHints::colorScheme`), not only Day/Night: Windows defaults to System and
  showed native blue/white before. On Windows the Qt settings file is `%APPDATA%\vlc\vlc-qt-interface.ini`.
- `NoMedialibHome.qml` must keep the `ConeNButtons` component: the media library `HomePage.qml` uses it for the cone + Open File row. The start screen rewrite dropped it once and Home rendered blank whenever the media library was on (QML load errors do not fail the build).
- A page whose root is `PageExt` (or any custom root without one) needs its own `ColorContext` at the root: the CI shot of the
  new Network page drew no `ButtonExt` at all (no palette, transparent fill and text) while a label with a fixed colour showed.
  Popups are not items, so their context never finds the window palette: set `palette: VLCStyle.palette` on it and give the
  `contentItem` its own context (`ModalDialog.qml`, `TracksMenu.qml`). Fixed 2026-10-28 in the Network page and both Figma dialogs.
- `ControlRepeater` rebinds every control bar widget's `visible` to its loader, so a control cannot hide itself with `visible:` on its root; hide a child instead (see the idle cover in `ArtworkInfoWidget.qml`).
- Start screen (no media library): `NoMedialibHome.qml` is a dim cone plus the "Drop a video... Ctrl+O" hint like the prototype; `MiniPlayer` is always
  in view (control bar visible while idle), `ArtworkInfoWidget` is hidden until something plays. The cone SVG does not render in the Linux CI shots.
- Windows build: `.github/workflows/redesign-windows.yml` (release, cross-built, artifact `vlc-win64-portable`). `build.sh` names the build dir `win64`.
  The Home page "Open File" row is clipped under the header in CI screenshots, also in old runs; probably a layout artefact of resizing the window after launch.
- Library shell follows the Figma frames: the sidebar is a floating rounded card (`SideNavigationPane` background, a plain
  `Rectangle`: `AcrylicBackground` cannot round its corners, so the sidebar has no Windows blur any more; the top bar keeps it).
  The library has no full-width mini player bar (`MiniPlayer` state is `outViewport`); `maininterface/qml/FloatingMiniPlayer.qml`
  is the bottom-right card and `MainDisplay` places the PIP video over its preview. Page headers (`PageExt`) have back/forward
  (`History.next()` / `nextEmpty` were added in `util/navigation_history.*`), the page crumb, the item count and an always-visible
  search field (`GridSortFilterControls`).
- Control bar profiles are written to the settings file (`[ControlbarProfileModel]`) on the first run and never refreshed, so a
  machine that ran an older build keeps the old bar whatever the code default says (a Windows install showed upstream's centred
  skip/previous/play/next in two rows, not the Figma one-row bar with play at the left after previous). `ControlbarProfileModel::
  reload` migrates the known old Default Styles (audio button; upstream's centred transport); change a built-in default there too.
  Linux CI and the harness start from a clean config and hide this. Quick reset: rename `vlc-qt-interface.ini`.
- Prototype accent `#D37918` is used for both themes; `orange800` (the light-theme accent) is set to the same value.
- Text on accent buttons is dark (`#1A0E02`), as in the prototype.
- Icons: Qt's set is already filled Fluent-style outlines close to the prototype's; only 18 of 97 names match. Add individual glyphs
  when a phase needs one instead of replacing the font.
- Out of scope: macOS (`macosx/`), skins2, ncurses, and the prototype's mock-ups (spatializer, stereo widener, OpenSubtitles search).
- Keep the branch rebase-able onto upstream VLC; prefer small, QML-only changes.
