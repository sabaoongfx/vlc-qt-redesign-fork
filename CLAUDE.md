# CLAUDE.md

Working notes for the VLC Qt redesign. This repo is a fork of `videolan/vlc`; the work happens on the `redesign` branch.

## Goal

Port the HTML prototype (`sabaoongfx/vlc`, local `..\vlc`) into VLC's real Qt/QML interface (`modules/gui/qt`).
The prototype is the visual reference only; do not copy its data layer. Back the new look with VLC's real models.

## Linux machine (current, Manjaro KDE) — read this first

- Tree: `~/Documents/vlc-qt-redesign-fork`, LF line endings. Remotes differ from the Windows notes below:
  `origin` = the fork (`sabaoongfx/vlc-qt-redesign-fork`, push here), `upstream` = `videolan/vlc`. `git`/`gh` are on PATH.
- Here VLC IS built and tested locally (the Windows "never run locally" rule does not apply): `make -C build -j$(nproc)`
  (~25 s for QML/C++ changes in the Qt module; QML is compiled into the binary, so rebuild before every capture).
  `contrib/native/` (local medialibrary build) is untracked on purpose.
- Test harness: `redesign/tests/run.sh [scene-regex]` runs each scene of `scenarios.txt` in a headless nested KWin
  (xdotool clicks, AT-SPI `press:Name`, `shot`/`shotwin`/`geom`), then `check.py` (QML warnings, colours and geometry
  measured on the Figma frames, unchanged vlcrc after Settings Save). Output in `redesign/tests/out/run/` (`report.html`);
  each run wipes the previous PNGs. Full run ~25 min (run it in the background), last full run: 0 failures.
- Figma export: `~/Downloads/VLC Redesign (Community)/` (per-screen folders with `figma.png`, `notes.md`; `COMPARISON.md`)
  and `~/Downloads/VLC Redesign (Community) (1)/` (Subtitles side-panel SVGs, render with `rsvg-convert -w 400`).
- Plan and status: `redesign/PLAN.md` (phases 1-5); settings option map: `redesign/SETTINGS-MAP.md`.
- Nothing is pushed since 2026-10-25: `redesign` is 69+ commits ahead of `origin/redesign`. Push and run CI is phase 5.
- Commit per fix, `Co-Authored-By` trailer, `[skip ci]` for docs/harness-only commits.

## Where we are (2026-10-26)

- Phases 1-3 of `PLAN.md` done (harness; Customize Player modal, rounded mini-player video, Browse folder header,
  ML folder buttons; Settings rebuilt as Figma row pages, 13 categories, search, classic pages kept under Advanced Options).
- Phase 4 (pixel polish against Figma, measure with crops, fix, add a `check.py` guard) in progress. Done: player bars
  (40px top / 55px bottom, #1B1B1B, centred controls, 15px times, grey 12-14px window buttons, 10px stage radius),
  library layout (sidebar card x 8-208, rows at x 30/63, page margins 28/24, 20px grid gaps, 16:9 covers, header field
  y 60-93 / separator 110), mini player card (391x338, framed preview, no progress handle), side panel (colours, content-sized tabs, 220x48
  dropdowns, 138x34 fields, 1px #222222 section lines; measured on the `(1)` SVGs), menus (`RedesignMenuStyle`: #181818 card,
  48px rows, label x 52 #8F8F8F, right-aligned spaced shortcuts #6B6B6B, hotkey hints in the right-click menu).
  Next: settings window chrome, dialogs, onboarding; then phase 5 (push, Linux + Windows CI, docs, refresh COMPARISON.md).
- Left on purpose: sidebar entries / Home rows that need new pages or models (Network, Playlists, Recent, Listen Again),
  side-panel features VLC lacks (sleep timer, reverse, EQ in the panel), the fullscreen button order in the title bar.

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

- Runs on push to `redesign` and on manual dispatch. About 6 minutes with a warm ccache (about 14 cold).
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
- Extra state shots in the library loop: `lib-browse-*`, `lib-discover-*` (the Discover click can land on Browse), `lib-sort-*`, `lib-search-*`, `lib-playlist-*` (Play Queue pane), `lib-albums/album/tracks/artist-*`, `lib-menu/help/tools-*`, `dlg-about/effects/messages/plugins-*`.
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
| 7 Polish and release | in progress: day+night review of home, library (grid, list, albums, tracks), player, tracks panel, Preferences and file dialog done; floating sidebar panel intentionally skipped (the content pane's rounded top-left corner over the sidebar is close enough and avoids layout risk). Artist page captured (`lib-artist-*`; album section backgrounds now follow the theme, were pure white in Day; the artist banner is a dark scrim over artwork on purpose). Open: icon set, macOS build, upstream patches. Windows x64 cross-build compiles and packages a portable zip (`.github/workflows/redesign-windows.yml`; artifact `vlc-win64-portable`, ~93 MB; the first run takes ~80-120 min because the prebuilt contrib URL 404s and contribs build from source, the contrib cache is saved right after the build; runs on push to that file; build dir is `win64`, not `x86_64`; a second job runs the portable build on `windows-latest` and uploads the `windows-screenshots` artifact via `.github/scripts/win-shots.ps1`: system/day/night main, Preferences tabs, player; 1024x768 runner; the desktop is captured, UI Automation clicks the tabs; verified System mode: accent palette, ticks, chevrons, start screen; Day/Night shots need the .ini fix, rerun pending) |

`redesign/TOKENS.md` holds the prototype-to-Qt token map and the Phase 1 decisions.

## Windows CI gotchas

- Contrib cache restore: touch every restored file with ONE timestamp (`touch -h -d "@$T"`), otherwise make sees random newer/older pairs and rebuilds all
  contribs (49 min wasted once). Cached build is about 30 min.
- `cargo-c` is installed by `cargo install` into the cargo home, which is not cached, but its `.cargo-c` marker is. rav1e then fails with
  `no such command: capi`. The touch step deletes `contrib/contrib-win64/.cargo-c` so it is rebuilt.
- A job failure skips the cache save and the cache key is immutable once saved; the v2 key holds a complete cache.
- The Windows shots job must start VLC with a fresh `%APPDATA%\vlc` each time or a "restore the playlist" prompt appears after a force-kill.

## Decisions and gotchas

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
- Harness without a graphical login (machine at the SDDM greeter, shell env says XFCE): `run.sh` makes a private `XDG_RUNTIME_DIR` and uses
  `--aout=adummy`, `inner.sh` pins `XDG_CURRENT_DESKTOP=KDE` (else Qt loads the GTK theme and its ATK bridge hides the tree from `at.py`) and runs
  spectacle on Wayland (as an X11 client it hangs there).
- Harness: `at.py press` prefers on-screen matches; Widgets QMenu items are not reachable by AT-SPI (click by position).

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
- Prototype accent `#D37918` is used for both themes; `orange800` (the light-theme accent) is set to the same value.
- Text on accent buttons is dark (`#1A0E02`), as in the prototype.
- Icons: Qt's set is already filled Fluent-style outlines close to the prototype's; only 18 of 97 names match. Add individual glyphs
  when a phase needs one instead of replacing the font.
- Out of scope: macOS (`macosx/`), skins2, ncurses, and the prototype's mock-ups (spatializer, stereo widener, OpenSubtitles search).
- Keep the branch rebase-able onto upstream VLC; prefer small, QML-only changes.
