# CLAUDE.md

Working notes for the VLC Qt redesign. This repo is a fork of `videolan/vlc`; the work happens on the `redesign` branch.

## Goal

Port the HTML prototype (`sabaoongfx/vlc`, local `..\vlc`) into VLC's real Qt/QML interface (`modules/gui/qt`).
The prototype is the visual reference only; do not copy its data layer. Back the new look with VLC's real models.

## Backlog (user requests, 2026-10-29)

Bugs and changes the user asked for after v0.1.3. All five were done the same day (after v0.1.3) and
checked only by CI: items 1-4 by the screenshots and the Network checks, item 5 (drag) tested by hand
by the user on 2026-10-31 (works). Notes kept for context:

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

## Done 2026-11-10/11 (Linux, harness-checked, pushed as `a67f9c82f9`)

The Figma "07 Menus" frames are all built now:
- Volume cone fill under Figma's 20% black layer (stops x 0.8); the grey outline stays (contrast, 2026-11-02).
- Playlists page lists every playlist (`PLAYLIST_TYPE_ALL`; name-only and music-only ones were hidden); Music >
  Playlists keeps the audio filter. Playlist menu: Figma duotone icons (Rename/Delete take VLCIcons glyphs).
- The player's library card (rail > Playlists) opens the same playlist menu on a right-click (rows and tiles).
- Right-click menu: Hide UI (= `MainCtx.minimalView`, Ctrl+H) after Fullscreen; the Figma shows Ctrl+\ but VLC's
  key is Ctrl+H. Fullscreen kept (not in the frame), with a plain glyph.
- Sort menu: accent tick on the hover band for the current choice (any exclusive QMenu list); menus without icons
  put labels at x 18 (`plainLabelX`, by `maxIconWidth`); folder trees tick Title A-Z when no sort is saved
  (`isDefault` in a SortControl entry); the music tree adds Artist/Album/Track Number (Disc Number: no criterion).
- File menu (`MLContextMenu`): Figma names/order/icons (NativeMenu actions take `icon`, a `:/menu/...` path; a
  `qrc:///` url does not load), Stream and Convert (`MediaLib::streamMedia`; `streamingDialog`'s flag is
  transcode-only despite the header's `b_stream` name). Not built: Go to Source, Add Subtitle/Audio Tracks.
  A QMenu label needs `&&` for a literal `&`.
- Folder "..." menu: Figma icons. View Options: the grid/list button opens a Grid View / List View popup
  (SortMenu with `icon_svg`); harness scenes click it at 1503,77 then List View at 1560,168 (`press:View` misses).
- No cone in the top bars unless VLC draws its own window buttons (`MainCtx.clientSideDecoration`), macOS too
  (user request); the "..." button is now at x 19 (CI's 20,20 click lands on it).
- Seen but not fixed: "0 ms" under a playlist card, "1 items" in the card header, the light playlist placeholder
  in the dark theme.
- Build tree: pacman moved automake to 1.19 and the tree was made with 1.18, so a `Makefile.am` edit broke `make`
  (`automake-1.18: command not found`). `./bootstrap` then `make` fixed it (incremental, a few files rebuilt).
  Shell note: zsh does not split `$VAR` into words in `for n in $N`.

## Working notes after v0.1.15 (2026-11-14; read with the sections below)

- **Release routine** (done three times on 2026-11-13/14; "release when done" / "go for it" from the user authorised
  that batch only, ask for the next): push the code commit (not `[skip ci]`), wait for all FOUR runs (Redesign build,
  Windows ~45 min, Linux packages, macOS ~1 h) with a `gh run list` loop (a Monitor `timeout_ms` is at most 3600000 and
  it expires after 30 min with no event: re-arm it, the watched job is not affected), tag that commit
  (`git tag -a vX -m ... <sha>`, push the tag), then the `[skip ci]` commit with the changelog (`redesign/docs/10-changelog.md`)
  and CLAUDE.md, `gh release edit vX --notes-file` (changelog first, then the generated body), and only after the
  release workflow is green push the blog post (`../vlc-web`: new `blog/whats-new-in-X/` made from the last one,
  `tools/posts.json` entry, `python3 tools/blog.py`) and check the apt/pacman repos serve it
  (`.../dists/stable/main/binary-amd64/Packages`, `.../arch/x86_64/vlc-juxtopposed.db`). Next version: v0.1.16.
- **Harness lessons**: page paths for `History.push` do not start with "mc" (`["playlists"]`, `["playlists","list"]`; the log
  said "unable to load view mc"); `MLBookmarkModel` is not registered without the media library and Ctrl+B only exists with it
  (`MLGlobalShortcuts.qml`): scenes for them use kind `fixture`; the Player module must not import `VLC.MediaLibrary`
  (load by `qrc:///qt/qml/VLC/MediaLibrary/...` url like `CompactLibrary`); `press:Road_Trip` turns the underscore into a
  space (click by position for names with one); `check.py` blocks that come before `def check` must use `ok`/`fail`;
  a scene whose geom row has the same name as a list ("Chapters" tab and list) needs the role filter; partial runs skip
  blocks whose scene is absent; build only when no harness run is going (`make` under a run corrupts it).
- **Audio track selection** (read in `src/input/es_out.c` `EsOutSelect`, 2026-11-14): `--audio-track-id` / `--audio-track` (default -1)
  first, then `--audio-language` (default empty: VLC does not follow the system language; Settings has no row for it, only
  "Default audio track" under Playback and "Preferred language" for subtitles; a row was offered, not answered), then the
  demuxer's default ES, then the container priority (mkv: forced > default flag > rest, disabled never; with no default flag the
  first audio track is made default), equal priority = the first one. The v0.1.9 auto-subtitles read the chosen track's language
  tag, so a wrongly tagged file gets no subtitle.
- **Episode 0966** (`~/Downloads/One Piece 1999 .../Season 20/[Anime Time] One Piece - 0966 ...mkv`): both audio tracks tagged `eng`,
  titles "Japanese" (default, 23:57) and "English" (24:04); 0961/0974 have English `eng` first and Japanese `jpn` second (23:50). The
  user hears English on both; VLC plays two different streams (checked by recording `--audio-track` 0/1 and correlating with the
  file's streams), so it is the release's tagging, not VLC. Track names are "title - [language]" ("Japanese - [English]").
- **Audio sync** (user question): audio late = negative delay: `J` (50 ms earlier per press), `K` later; macOS `F`/`G`; the side panel's
  Audio tab > Synchronization > Audio Track Delay (-10..+10 s, Reset).
- **Open**: durations "--:--" for unread videos (VLC's unknown), "0 ms" under an empty playlist card; the Settings runtime suite
  (`settings.txt`, 233 -> fewer scenes) was last run in full on 2026-11-11 (only `set-baseline` after the row changes of 2026-11-14);
  engine tests only planned; Mac video area unconfirmed on a real Mac; model default is now Sonnet 5.5 (user, `/model`).

## RELEASED 2026-11-14: **v0.1.15** on `63dc2e29de` (all four CI runs green; user: "once you are done, then go for it")

v0.1.15: progress bar under started playlist cards (`MediaLib::playlistProgress`, `VideoGridItem.progressValue`); dark video tile
for unread videos in list rows (`widgets/qml/VideoPlaceholderTile.qml`, shared with the grid card; `PlaylistMedia.videoPlaceholder`);
active bar buttons use `IconToolButton.activeColor` (accent darkened to 3:1 on the bar, asked 3.6:1 on the palette colour because the
bar is drawn darker than its palette: #ABAAAA on screen); Settings rows that cannot keep a value removed or platform-guarded
(`verbose`, `reset-plugins-cache` volatile; `spdif`, `http-proxy(-pwd)` `#if`), `settings_options.py` check 3b fails any new one. Last full
local run: 540 checks, 0 failures; unit tests 8/8. Changelog `redesign/docs/10-changelog.md`, blog `whats-new-in-0-1-15`.
Known, not fixed: durations "--:--" for unread videos (VLC's "unknown"); "0 ms" under an empty playlist card.

## After v0.1.13 (2026-11-13 evening): v0.1.14 RELEASED 2026-11-14 as **v0.1.14** on `bc1566bc92`

v0.1.14: tagged on `bc1566bc92` after all four CI runs passed (user: "when done, do the deed and release when done");
changelog in `redesign/docs/10-changelog.md`, blog `whats-new-in-0-1-14` (vlc-web). Also in it, after the list below:
the queue panel tabs + Ctrl+B (`541b803e28`), Home Playlists row + Resume pill on playlist cards (`bc1566bc92`:
`MediaLib::resumePlaylist` plays the playlist from the video with the latest played date, `playlistStarted` tells
whether to show the pill; the pill is a MouseArea so the card under it does not also open the playlist; Home opens a
playlist with `History.push(["playlists","list"], {parentId,title})`: page paths do not start with "mc").
The list below is what was pushed before it.

All tests first, run locally (tests never go into CI, user decision; memory `tests-local-only`).
- `712a1d0546` Visualizer row in the side panel's Audio tab (Figma "Audio Visualizer"): Disabled, Spectrometer,
  Scope, Spectrum, VU Meter (the Figma's "Waveform" = VLC's VU meter: VLC has no separate waveform), icons in
  `pixmaps/visual/` (Spectrum's dots are circles: Qt's SVG renderer skips zero-length round-cap lines). Drives the
  player's `audioVisualization` ("visual" var, rows 0-4 in core order) for the session, not saved. Dropdown rows
  without an icon keep the icon rows' height (`ComboBoxExt`). The row moved the Equalizer card down 68px: the EQ
  scenes click 1714,737 / Rock 1715,581 now. Scenes `visualizer`, `visualizer-day`.
- `0e0a210766` Music player = Figma "Player - Music": cover 75% of the area between the bars, 20px corners
  (`Widgets.ImageExt` sized by the picture's aspect: ImageExt draws its texture over its whole box whatever the
  fillMode), decoded at 0.75 x screen height; one line "title - artist" 24px `figmaColors().title`, centre 88px under
  the cover; no album/artist lines; the button row only for songs with lyrics (Lyrics is only reachable there).
  Floating mini player (user report, stretched square cover): cover fitted in the middle, the cover decoded at 24px
  and scaled up as the blur behind it, dimmed, a ring in the card colour keeps the corners round.
  Checks: `player-audio` (geometry), `lib-mini-audio(-night)`.
- `3498f115d0` Fullscreen: no position display (time + slider) over the video on a seek (user: "on using the ten
  second forward button, the ui shows"; it was VLC's OSD, not the bars). `src/player/osd.c`: core change, keep.
  `keys-fullscreen` counts the OSD's white text 0.3 s after Right.
- Finding, not fixed: Day theme, music playing, side panel open: the active subtitles button is 1.39:1 on the light
  bar (`visualizer-day` contrast; `test-findings.md`).
- Last full local run (before `3498f115d0`): 477 pass, 4 fail = that finding + `video-grid` (shot before the window
  drew) + `keys-fullscreen` (timing); both pass alone. `rail-move` now reads the picture edge on three lines.
- Dropped by the user: the player top bar work (music player's library button toggles nothing: the rail exists only on
  the video stage, `_libraryRail` needs `_videoStage`). Not done.
- DONE 2026-11-14 (user request "change the ui of the queue according to figma", then "do it" for Ctrl+B): the queue
  panel of the player has the Figma tabs Queue | Bookmarks | Chapters (`Queue.svg`/`Queue-1.svg` in `~/Downloads/VLC
  Redesign (Community) (5).zip`; 400x946 frames). `PlaylistPane.qml` (`tabs: true` only in `Player.qml`; the library's
  queue panel keeps the title) has the 50px #090909 bar (`QueueTab`, icons `pixmaps/queue/`, accent underline), the
  Queue tab keeps the list with the count line beside sort/search/add; pages are urls given by the player:
  `player/qml/QueueChaptersPage.qml` (accent number, name, HH:MM:SS; click seeks; VLC puts a space before mkv chapter
  names: trimmed; time rounds to the second) and `medialibrary/qml/QueueBookmarksPage.qml` (+ `QueueBookmarkModel.qml`:
  `MLBookmarkModel` is not registered without the media library, so it is loaded by url like `CompactLibrary`; the model
  got `timeMs`, `available`, invokable `add()`/`removeRow()`; `VLCTime.toMilliseconds` is invokable). Card width 400
  (`Player.qml`). Ctrl+B / Bookmarks > Manage in the player: `DialogsProvider::bookmarksDialog` emits
  `MainCtx::bookmarksRequested` (player view + docked queue), `Player.qml` opens the panel on Bookmarks / switches to it
  / closes it; the Widgets window stays in the library view. Ctrl+B only exists with the media library (the shortcut is
  in `MLGlobalShortcuts.qml`). Fixture `chapters.mkv`; scenes `queue-tabs(-day)`, `queue-bookmarks`, `queue-bookmarks-key`;
  `queue-open/click/reorder` re-measured. Full local run: 515 pass, 2 fail (the Day contrast finding and
  `keys-fullscreen`, which reads its times too early in full runs: now reads twice); unit tests 8/8.

## 2026-11-13: tests for every feature, then the bugs they found fixed (`271bfbe603`)

RELEASED 2026-11-13: **v0.1.13** on `271bfbe603` (Latest, 8 assets, release run 43403362980; changelog `d558120b1a`;
blog `whats-new-in-0-1-13` and the tests post marked fixed, vlc-web `241ef43`). Ships everything since v0.1.12 (toast,
resume by default, the user requests and fixes below). First build with the release toast.


- Harness: 124 scenes + `window.txt` (2, run with an empty `KWINRULES`), checks in `check.py` 13d-13f;
  last full local run 453/453, window 5/5; Qt unit tests 8/8 (`make -k -C build/modules/gui/qt check`,
  `QT_QPA_PLATFORM=offscreen`). Findings and their fixes: `redesign/tests/test-findings.md`. Engine tests are
  only planned: `redesign/tests/ENGINE-TEST-PLAN.md`. Blog post: `what-the-tests-found` (vlc-web `37a1e6b`, bugs
  marked fixed in 0.1.13 in `241ef43`).
- Harness rules learnt: `sound:null` scene action (private PipeWire, two null outputs, never the desktop's
  server); each scene's library copy is deleted when the next starts (/tmp is a RAM disk); `@FIX@`/`@OUT@` in
  actions; menus of Qt Widgets and the picker's tabs need real clicks (AT-SPI press does not select a Qt
  dropdown row either); look at the screenshots after every run.
- Tests run LOCALLY ONLY (user decision 2026-11-13): the harness, window pass, Settings suite and the Qt unit tests
  were removed from `redesign-build.yml`, then lint and the Network stream checks too (CI keeps the build, its
  screenshots and the information-only QML warning list; run `redesign/tests/lint.py` and `settings_options.py` locally).
  If they ever go back into CI: install the harness tools (and every Qt package at the same version) BEFORE the build,
  else VLC's AOT-compiled QML does not load ("compiled ahead of time with an incompatible version of Qt"); CI never
  produced harness screenshots (spectacle, cause unknown).
- Core/upstream changes to keep when rebasing: `modules/audio_output/pipewire.c` (reports the device its stream
  is linked to; a device change restarts the output, WirePlumber ignored the stream's own property update);
  `modules/gui/qt/dialogs/sout/profile_selector.cpp` (first profile when none saved);
  `modules/gui/qt/tests/test_ml_model_stubs.cpp`.
  Also `src/player/osd.c` (2026-11-13): no seek position display (time + slider) over a fullscreen video.
- User decisions today: the tracks picker opens on its button's tab (subtitles / audio button), the audio
  button opens that picker (no own menu); right-click menu 280 wide, 44px rows; bars of a normal window hide
  after 10 s and the video fills it; queue rows play on one click; Add to Queue places the playing item; video
  does not move when the left menu opens. Planned (roadmap): visualizer picker, queue panel Bookmarks/Chapters.
- The user asked for no local builds unless asked (memory), and tests before fixes.

## After v0.1.12 (2026-11-12)

Pushed, not released (next "what's new" material). CI green on both commits (Linux build, Linux packages, Windows,
macOS; the macOS run of `a1c8431d9f` needed a re-run for a runner, the one of `e0ef2a0cba` was still running at writing).
- `a1c8431d9f` "new version" toast (user request: weekly, on by default, a card with a close x). `ReleaseCheck`
  (`maininterface/release_check.*`, QML singleton registered in `mainui.cpp`) + `maininterface/qml/ReleaseToast.qml`
  (bottom left in `MainInterface.qml`, raised above the player bar while playing). 20 s after start, then hourly looks at
  `[ReleaseCheck] next` in the Qt settings: GitHub API `releases/latest`, then `tags` pages 1-5 (the fork carries upstream's
  100+ tags) to find which tag the build's commit is. The commit comes from `src/revision.txt` via the generated
  `maininterface/release_revision.cpp` (Makefile.am rule; meson `vcs_tag` written but untested). Builds not on a release
  tag never show the toast. Dismiss stores the version (`dismissed`); a newer one shows again. Packaged Linux installs
  (`/opt/vlc-juxtopposed/`) say "Your system's updater installs it" and open the release page; others open
  `https://vlc.sabaoon.dev/#download`. Off with `qt-updates-notif` (Settings "Check for updates automatically"; now
  declared outside `#ifdef UPDATE_CHECK` in `qt.cpp`). Checked in the harness with a faked revision stamp. Unverified:
  that the Windows/macOS CI builds write the commit into `revision.txt` (if not, the toast never shows there). Nobody
  sees it before v0.1.14 (v0.1.13 is the first build that checks).
- `e0ef2a0cba` videos resume where they were left by default (user request: no racing for the Continue button):
  core default `restore-playback-pos` = ALWAYS in `src/libvlc-module.c` (core change: keep when rebasing). `ResumeDialog.qml`
  then shows "Continued from HH:MM:SS" with a Start over button (seeks to 0) for 10 s, no focus taken, hover holds it;
  the old ask mode (option set to Ask) still shows Continue Watching. Harness `resume-prompt` checks for Start over.
  Existing installs follow the new default unless the option was changed by hand.

## After v0.1.11 (2026-11-11)

RELEASED 2026-11-11: **v0.1.12** on `f22d56e327` (Latest, 8 assets, release run 43078984261; changelog `477abebd3a`;
blog `whats-new-in-0-1-12` in `../vlc-web` `5f7d56b`). It ships everything listed in this section below.

v0.1.11 is released (Latest, on `7979c8a2fd`, 8 assets; changelog in `redesign/docs/10-changelog.md`; blog
`whats-new-in-0-1-11` live in `../vlc-web`). Everything below is pushed; `origin/redesign` = local head `3f6fd959cd`.
Not released yet (next "what's new" material):
- `6146c61639` volume bar empty when a video starts / VLC opens: `src/player/aout.c` sends the first known volume
  (upstream 6958b29519 dropped it). Core change: keep when rebasing. Checked with a PulseAudio null sink.
- `163ea641e7` U shows or hides the player's library menu (`MLGlobalShortcuts.qml`, `MainCtx.libraryPanel.visible`);
  both library buttons' tooltips say "(U)" (`LibraryButton.qml`, `TopBar.qml`). Smell left: "U" and the toggle line in 3 places.
- `cd585b1c3d` volume cone has no outline (user request); `contrast-allow.txt` allows its ~1.1:1 track. CI green (4/4).
- `f22d56e327` hand cursor on the play/pause button (its hover MouseArea hid the HoverHandler: the handler is now inside
  the MouseArea) and on play queue rows (`PlaylistDelegate`, next to the TapHandler; double-click still plays).
  Checked with `cursor:`/`ptr:` on X11 and `QPA=wayland`. CI started 2026-11-11 on it (4 workflows): check the result.
  Video/folder cards, list rows and the library card already showed the hand in the harness; the user also said "on
  clicking videos and items": if they still see an arrow, ask which page/list.
- Settings tests (section below): CI runs the static checks; the runtime suite is local (~75 min). Findings are
  collected in `redesign/tests/settings-findings.md`, not fixed until the user plans them (5 rows Save cannot keep:
  spdif, http-proxy, http-proxy-pwd obsolete; verbose, reset-plugins-cache never written).

## After v0.1.10 (2026-11-11 night; all of it shipped in v0.1.11)

CI: the user stopped all runs (2026-11-11 ~01:50) and has not asked for new ones. Nothing after v0.1.10 has a CI
build. Pushed to `origin/redesign` (head `cc471c6e8a`, a `[skip ci]` commit, so no runs) and harness-checked only:
- `13cc07bfb5` player top bar: "..." first, then the library switcher (user request).
- `6e5acad5f9` Next/Previous tooltips "Next (N)" / "Previous (P)": `MainCtx::hotkeyText(option)` (reads the
  configured key like the menus' `hotkeyHint`), `IconToolButton.shortcut` (tooltip only, accessible name unchanged).
- `ff52bc82ac` grid badges (playlist counts, quality tags) are a dark pill + white text in both themes (Night was 80%
  white + black text, plus an extra 0.5 opacity); playlist counts fold the library's "unknown" media (files added from
  outside the library folders, not parsed yet) into Videos when there are no songs, Tracks when no videos.
- `77daaecaad` a video clicked inside a playlist queues the whole playlist in the shown order and starts at it
  (`MediaLib::addAndPlayFrom`).
Local commits, later pushed (see below):
- `2c7b882be9` list views: `VideoProgressBar` under the thumbnail of a started video (`TableColumns.titleDelegate`).
- `0fdecb5730` + `65799a8e8e` right-click menu = the Figma frame: Previous Item, Next Item, More Settings (was
  Tools), Playlist (was View), Quit VLC; submenus Playback, Video, Audio, Subtitle; no Fullscreen entry; three 1px
  #1D1D1D group lines (menu property `redesignHairlineSeparators`) after Record, Hide UI, Subtitle: 292x683 like the
  frame; check.py measures the height and the lines.
- `48ca942f1e` menus are 265px wide by default (the Figma file, folder, playlist, sort and View Options frames, measured
  on the user's exports `VLC Redesign (Community) (4).zip`: cards 265 wide, 48px rows, 4px padding), `rightClickWidth`
  292 set in `PopupMenu`; the 40px label-to-shortcut gap only on rows with a shortcut or a submenu. Icons 1:1 with
  Figma: every `pixmaps/menu/redesign-*.svg` has a 24-unit viewBox around its old centre (they were 21/22.5/23 units
  drawn into 20px), `RedesignMenuStyle` iconX 18 / iconSize 24; Hide UI and Video, cut larger than the frame, use a
  26.67 viewBox (0.9); glyph icons are 24px pixmaps. Measured equal to the exports within 1-2px (Previous/Next differ
  in shape, not scale). 55/55 menu checks.
Pushed and CI started 2026-11-11 (the user asked).
Harness runs with `OUT=<scratchpad>` copy the profiles (media) each time: delete `<out>/profiles` after a run, /tmp
(tmpfs, 6.8 GB) filled up once.
Also seen, not fixed: `PageLoader.qml:99` "Cannot assign to non-existent property parentId/title/trail" when the
player returns to a Videos folder page (folder tree, since 2026-10-28; harmless); "0 ms" under a playlist card
subtitle when empty; "1 items" in the player card header; the light playlist placeholder in Night.
The user's daily VLC is an older package (still shows the second cone and no Hide UI): their screenshots of "current"
behaviour may predate v0.1.10.
Measuring a Figma menu: the exports carry a 15px shadow margin (card at 15,7 in a 295-wide PNG); compare at native
size (player frames are 1920x1080).

## Settings tests (2026-11-11; second full run 523 pass / 10 fail, the 10 = five rows Save cannot keep, see settings-findings.md)

- `redesign/tests/settings_options.py --write` reads every Settings row (`SettingsRows` in `simple_preferences.cpp`) into
  `redesign/tests/settings-options.tsv` (121 rows, 113 options: page, section, label, option(s), kind option/widget/action,
  under Advanced Options, #if guard). Without `--write` it runs static tests: the list matches the code, every option is
  declared in `src/`/`modules/` (obsolete declarations do not count), `SETTINGS-MAP.md` lists the same rows, no classic-only
  option, unique labels per page.
- `settings_scenes.py` writes `settings.txt` (233 scenes): `set-baseline` opens every page (+ Advanced Options where rows
  are), lists the rows (`rows:<page>`) and saves unchanged; per row (the Windows-only volume keys row has none) a change scene
  on an empty kept profile (run.sh kind `prefs`: Ctrl+P, page, `setrow:Label=value`, Save) and a `-reload` scene (kind `same`:
  restart on that profile, list the rows of every page showing the option; none for `qt-start-minimized`).
- at.py `rows` / `setrow` find a control through its row LABEL (label's parent = the row widget, the control is the sibling
  that is not the label or the info icon): a combo box is named after its current item, not the label (seen in an AT-SPI
  dump 2026-11-11). Facts from that dump: line edits are role "text"; spin boxes have the Value interface; combo boxes have a
  list child whose current item is SELECTED; Theme's segments and the Advanced Options bar are "check box"es; Theme and the
  swatches react to `clicked`, so setrow clicks them with xdotool; the colour button's dialog is modal (an AT-SPI action on it
  never returns), so setrow clicks it, sets "HTML:" to #123456 and clicks OK.
- `check_settings.py <out>`: load (baseline rows show the vlcrc values: check, spin, text), change (old != new), type (control
  matches the add_<type> declaration), save (only that option changed in vlcrc, to the value shown; colour 1193046, accent
  #8D721C, Theme = color-scheme-index), reload (every row with that option shows the new value after a restart). Report
  `<out>/settings-report.txt`.
- Run: `SKIP_FIXTURES=1 SCEN=redesign/tests/settings.txt OUT=<dir> redesign/tests/run.sh 'set-'` (~1 h) then
  `python3 redesign/tests/check_settings.py <dir>`. Still unproven: focus + Down reaching a combo box in the nested KWin, rows
  scrolled below the window, values of spin boxes with a special text (-1 = Automatic).

- Harness lessons from the first runs: in this gi binding `n.get_name(k)` / `n.get_text(...)` resolve to Accessible methods,
  call `Atspi.Action.get_action_name(n, k)` / `Atspi.Text.get_text(n, ...)`; Qt ignores AT-SPI SetTextContents on line edits
  and focus + key on a combo, so setrow types into fields (after clicking a label to activate the window) and opens combos
  with their own action + Down/Return; the theme is saved to vlc-qt-interface.conf only on a clean quit (scenes end with
  Ctrl+Q) and inner.sh forces the scene theme at launch unless the theme column is "-". VLC starts in OUT (file logging
  wrote vlc-log.txt into the repository root). Findings for the Settings code: `redesign/tests/settings-findings.md`
  (collect only; the user plans fixes later).
- Core change to keep when rebasing: `src/player/aout.c` sends the first known volume (upstream 6958b29519 dropped it).

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
- Still open: Ctrl+N
  on Windows; the v0.1.3-rc1 pre-release (keep or delete, not answered). CI run 41010529443 was cancelled
  in its screenshot step at the moment of the next push (concurrency is `cancel-in-progress: false`; cause
  not found).

## Done 2026-10-30 afternoon (Windows machine, nothing run by hand)

- macOS (see `redesign/MACOS-PLAN.md`, its status line): M1 `redesign-macos.yml` + `extras/package/redesign/macos-build.sh`,
  M2 `macapp.sh` (`VLC juxtopposed.app`, `VLC-juxtopposed-arm64.dmg`), M3 screenshots (`macos-screenshots`), M4 written blind:
  native title bar by default on macOS (`QT_TITLEBAR_DEFAULT` in `qt.hpp`), the start screen chip shows the Cmd key,
  Cmd+, opens Settings, files from Finder/Dock play (`FileOpenSpy`, `qt.cpp`), a native menu bar
  (`VLCMenuBar::createNativeMenuBar`). The first macOS run builds the contribs from source (hours), then they are cached.
- Linux packages: apt update/build-dep/install retried 3 times with an 8 minute timeout each (the hang that hit the
  20 min step timeout).
- Dead code removed (item 6 of the list below): `VideoAllDisplay`, `VideoAllSubDisplay`, `VideoGroupDisplay`,
  `MLVideoFoldersModel`, `SortMenuVideo`. Still there: `DiscoverDisplay` pages (unreachable). The `useGlobalShortcuts`
  smell is down to four redesign lines (CompactLibrary, NetworkStreamDialog x2, NewPlaylistDialog); left as is.
- Commit identity: the Windows shell has no git user; commit with `git -c user.name=sabaoongfx -c user.email=sabaoongfx@gmail.com`.

## macOS state (2026-10-30 evening, CI only, no Mac)

- Green end to end since `c86538d`: build, `.app`, dmg, app smoke test, screenshots. The Qt redesign opens (start
  screen, library sidebar, player bars, native menu bar). M4 code compiles; the menu bar shows "VLC juxtopposed".
- OPEN, the release blocker: the player's video area is blank white in the screenshots while playback runs
  (VideoToolbox decodes, seek bar moves). Qt logs `OpenGL (ES) 3.0 context creation failed`. The runner is a VM with
  a paravirtual GPU, so it may be the runner, not the app; skins2 did show video there. `CompositorPlatform` (cocoa)
  puts a child video QWindow under a transparent QQuickView; the redesign's Player.qml keeps the stage transparent like
  upstream. Needs someone to run the dmg on a real Mac before the dmg is released.
- Lessons from the fixes (do not undo):
  - `contrib/bin` (luac, protoc) is not in the v1 contrib cache paths; the "Contrib native tools" step rebuilds them on
    a cache hit. Do not edit `macos-build.sh` lightly: it is part of the contrib cache key (a change = ~45 min rebuild).
  - `macapp.sh`: `vlc-qt-check` must be in `Contents/MacOS` (bundle libexec dir, `src/darwin/dirs.m`), or Qt quietly
    declines and VLC falls back to skins2. CI now runs it and fails the shots if skins2 ran.
  - Signing order as upstream `codesign.sh`: every file in `Contents/Frameworks` outside a .framework (data too), then
    `vlc-cache-gen` (with `DYLD_LIBRARY_PATH`, it has no rpath), then sign `plugins.dat`; otherwise "stale plugins cache".
  - Qt's sqldrivers are deleted (they link ODBC/Postgres/Mimer libs nobody has).
  - macOS arm64 runners sometimes are not acquired ("capacity constraints"): just re-run. A long shortage happened on
    2026-11-02: six tries in a row (5 re-runs of 41463216512 on `9fe22a14dc`, then run 41490660300 on the empty commit
    `857cb1d3b6`) were all dropped after ~15 min with no runner, while GitHub's status said Actions was fine. Re-running and
    empty commits do not help then; wait hours. Options offered, not decided: a `runner` input on workflow_dispatch to try
    `macos-14` (would reuse the macos-15 contrib cache, untested), or let the release publish without the dmg when the macOS
    job got no runner (today `redesign-release.yml` fails if the macOS run failed).
- Small leftovers: font "Inter" missing (Qt substitutes), `Command+0` bound to two actions, the local network prompt
  (`NSLocalNetworkUsageDescription` added in `5b76e90`).
- Release: `redesign-release.yml` now waits for the macOS run and attaches `VLC-juxtopposed-arm64.dmg` (M5). Tag a
  commit that has CI runs (not a `[skip ci]` one). Ask before any tag.
- Website (`../vlc-web`, `afbe935`): download rows show label + size from the release, a "Your device" badge, and a
  macOS card that switches itself on once the newest release has `VLC-juxtopposed-arm64.dmg`.
- PUBLISHED (user's choice, 2026-10-30): the dmg from run 41158407145 (`5b76e90`) was attached by hand to the v0.1.4
  release (SHA256SUMS updated, notes say added later, no attestation), and the site (`8029b10`) says Windows, macOS
  and Linux. The white video area is still unchecked on a real Mac: watch for reports.
- Pushing a code change starts all four workflows; when only macOS files change, cancel the other three.
- The `player` macOS shot runs with `--no-media-library`, which hides the player's left menu (rail, `Player.qml`
  `_libraryRail`) and the bar's library button (`control_list_filter.cpp`): by design, not a macOS bug (user asked
  2026-10-31). `7d815fe` adds `player-library` (same video, library on); macOS run 41237600798, not looked at yet.
  The local network prompt may cover it.

## Title bar and v0.1.5 (2026-10-30 night)

- The system title bar is now the default on every platform (`QT_TITLEBAR_DEFAULT` is plain `true` in `qt.hpp`;
  `3b557c5` Windows, `4bc9f18` Linux): users said the drawn buttons ignored Windows' decorations. VLC's drawn window
  buttons in the top bar are the opt-in, Settings > Show window decorations (`qt-titlebar`). Existing installs follow
  the new default unless the option was changed by hand (the wizard only ever saved the old default, which VLC writes
  commented out). Not seen running yet on any desktop with a window manager: CI shots have no decorations.
- v0.1.5: the user asked for a release once CI passes on `4bc9f18` (Windows build, Linux packages, macOS; the
  Redesign build run was cancelled as not needed for the release). Tag `v0.1.5` on `4bc9f18`; the release workflow
  attaches the dmg too. RELEASED 2026-10-31 (run 41164371298): v0.1.5 is Latest with the exe, zip, AppImage,
  tar.gz, the dmg (from the workflow, with attestation) and SHA256SUMS.
- Runs needed for a release: Windows build, Linux packages, macOS. "Redesign build" (Linux dev check, shots, tests)
  is not; the user counts it as extra when only a release is wanted.
- `qt.hpp`'s comment no longer names snap layouts as a reason (`1b32ef8`): upstream's drawn buttons support them
  (`mainctx_win32.cpp`, `HTMAXBUTTON`).

## Library thumbnails (2026-10-30 late, `4b03aef`, CI running, not seen on a real library)

From a user screenshot of Home (`~/Downloads/Screenshot 2026-10-30 223916.png`):
- Videos without a thumbnail showed upstream's light grey `noart_videoCover.svg` in the dark theme. Now
  `VideoGridItem.qml` draws the prototype's `.thumb.is-gen` tile over it: hsl(hue, 22%, 16%) with a hsl(hue, 30%, 55%)
  `VLCIcons.topbar_video` icon (light theme 88% / 45%), hue hashed from the title; shown while
  `MediaCover.showingFallback` (new property). List rows, CompactLibrary and the ML models' cpp placeholders
  (`mlvideofoldertreemodel.cpp`, `mlvideogroupsmodel.cpp`) still use the light SVG.
- The orange "new" corner (`new_indicator.svg`, model `isNew`) is off in `VideoGridDisplay.qml`: not in the design,
  and it poked out of the rounded corner under the HD label.
- Thumbnailer timeout 3 s -> 15 s (`modules/misc/medialibrary/Thumbnailer.cpp`): the precise seek (v0.1.3, `80400fc`,
  against grey frames) decodes from the previous key frame in software; long HD/HEVC episodes likely ran past 3 s and
  kept the placeholder. Unproven without the user's files. The media library stops retrying after repeated failures
  (`VLC_ML_THUMBNAIL_STATUS_PERSISTENT_FAILURE`), so such files may need a rescan.
- Open: a flat grey thumbnail made before v0.1.3 stays (thumbnails are never regenerated); a "Refresh thumbnail"
  context menu action was offered, not built. Continue Watching showed no progress bars in the screenshot: asked the
  user whether those videos were stopped partway.
- Thumbnails are taken at 15% of the video (`vlc_ml_media_generate_thumbnail(..., 512, 320, .15)` in the Qt models).

## Website and blog (`../vlc-web`, updated 2026-10-31)

- Download section: label + size per file from the release API, a "Your device" badge, a macOS card (Apple
  Silicon .dmg, on by default since the dmg is on v0.1.4). The site says Windows, macOS and Linux everywhere
  except the social image `og.png` (needs a headless Chromium render, not done).
- Blog: 12 posts (`whats-new-in-0-1-10` 2026-11-11; earlier: `vlc-web` `22e0071`, `whats-new-in-0-1-9` 2026-11-09 also covers 0.1.6-0.1.8). Rules come from `../sabaoondev-main/sabaoondev-main/CLAUDE.md`
  (Content Strategy) and are copied into `vlc-web/CLAUDE.md`, with the rules for each kind of post.
  - Engineering (quote real code from this repo, end with what is open): porting the redesign, the folder tree
    design note and its follow-up, two bugs that lived elsewhere, building the Mac version without a Mac,
    giving the title bar back, `how-vlc-plays-a-file` (2026-10-31: VLC's pipeline, module scores, clock, an FFmpeg plan
    for your own player; the FFmpeg snippets are sketches, never compiled).
  - Comparison: mpv/IINA/MPC-HC/PotPlayer/Windows 11 Media Player/Celluloid/Haruna (11 numbered sources).
  - For non-technical readers (2026-10-31, the user asked for them): `whats-new-in-0-1-5` and `how-to-install`
    (which file, the SmartScreen/Gatekeeper warnings and how to get past them, the welcome window, removing it).
    Write a new "what's new" post for each release that users would notice.
- Posts that quote code here must be updated if it changes: the Mac post (`macapp.sh`, the CI checks, `qt.cpp`'s Qt
  check), the title bar post (`qt.hpp`, `src/config/file.c`), `how-vlc-plays-a-file` (`src/modules/modules.c`
  `vlc_module_load`, `src/input/demux.c`, `src/input/es_out.c` clock-master auto, `src/video_output/video_output.c`
  late-frame drop, the mkv probe in `modules/demux/mkv/mkv.cpp`, `player_controller.cpp` `jumpFwd`).
  The non-technical posts state behaviour, not code: update them when a fix they list as open ships (the grey
  thumbnail tile, the unsigned installers, the Mac video area) or when a release changes install steps.
  OPEN: `how-to-install` still offers only the AppImage on Linux; the deb/rpm/Arch packages and the apt/pacman
  repositories (v0.1.6) are missing from it (offered to the user 2026-11-09, not answered).
- Blog features (search with full text, tag chips, tags, contents, `#` heading links, Keep reading, Copy link,
  the home page's three newest posts, feed and sitemap) are generated by `vlc-web/tools/blog.py` from
  `tools/posts.json`; `blog/blog.js` runs search and filters. Adding a post: write the page, add it to
  `posts.json`, run the script. Never run in a browser here: the user is to check desktop and phone width
  (not done yet for the three 2026-10-31 posts).

## FIRST on Manjaro: work written on Windows, compiled in CI but not run by hand (2026-10-28)

Status 2026-10-30: steps 1-3 done on Manjaro. `550223c` builds clean; a full harness run has no QML warnings at all
(the blind fixes of the 2026-10-27 list hold) and passes 172/172 after the harness update (`60da4de`). Found and fixed:
global shortcuts that are Qt.ApplicationShortcut (Ctrl+P, Ctrl+N, Ctrl+M...) never fired with the X11 compositor
(offscreen interface window; Ctrl+O/F/Y are window shortcuts and worked): `ShortcutExt` defaults to
Qt.WindowShortcut now (`006bec0`). Only the X11 compositor is offscreen (Wayland, DirectComposition and Win7 use a
QQuickView), so the open "Ctrl+N on Windows" is probably a different bug. Harness: the fixture
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
  Quick player check without the harness: `HOME=<scratch>/home xvfb-run -a ./build/vlc -I qt --no-media-library
  --no-qt-privacy-ask --aout=adummy --vout=dummy --verbose=2 <file>` under `timeout -s INT`, then grep the log
  (`ES track selected`, your own msg_Dbg). `QT_QPA_PLATFORM=offscreen` dumps core here: use xvfb-run.
  `gh` defaults to `videolan/vlc` in this tree: pass `-R sabaoongfx/vlc-qt-redesign-fork` to `gh run`/`gh release`.
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
- Plan and status: `redesign/PLAN.md` (phases 1-5); settings option map: `redesign/SETTINGS-MAP.md`;
  macOS: `redesign/MACOS-PLAN.md` (phases M1-M5).
- Pushed 2026-10-29 (code head `a0d1a8b`, run 5 green; this CLAUDE.md commit sits on top): `origin/redesign` matches local. Three workflows run on every push to `redesign`
  (Linux build, Windows build, Linux packages); a push whose head commit says `[skip ci]` runs none, so push a code
  commit on its own first (`git push origin <sha>:redesign`) when a harness/docs commit sits on top. One run per
  workflow at a time; a newer push replaces a still-pending run (it shows as "cancelled"), it never stops a running one.
- Commit per fix, `Co-Authored-By` trailer, `[skip ci]` for docs/harness-only commits.
- Contrast and lint (2026-11-02): every harness shot also dumps the enabled controls (`at.py controls`) and
  `contrast.py` (run by check.py) fails any whose icon/text/face is under 3:1 (WCAG 1.4.11); report
  `out/run/contrast.html`, exceptions with a reason in `contrast-allow.txt`, re-score old shots with
  `python3 redesign/tests/contrast.py <out>`. The first run's findings (Day accent text, grey knobs and handles, volume
  track, Advanced Options) were fixed on 2026-11-02 at the user's request (`accentText`, `readableOn`, token `knob`). `redesign/tests/lint.py` (CI step) checks the redesign's added code: no Canvas/Shapes,
  no colour literals in QML (`VLCStyle`; `// lint: allow <rule> (reason)` for deliberate ones), QML files in
  both build files. `qtdlg-*` scenes use `env:` to get Qt's own file dialog (what the packages show on KDE).
- Cursor checks (2026-11-11): `cursor:<tag>` appends the X cursor (XFixes: size, hot spot, pixel hash; the hand is 32x32 hot
  16,4, the arrow hot 4,4) to `<scene>.cursor`; `ptr:<tag>` shoots 96x96 around the last pointer position with the pointer
  drawn (works with `QPA=wayland`, where the player window is not maximised: its bar is at y 547); `down:x,y` / `up` press and
  release. A hover-enabled MouseArea hides a HoverHandler's cursor on its parent: put the handler inside the MouseArea.
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
  First tag `v0.1.0`, a pre-release. Windows + Linux now, macOS later (the user's decision). Plan written 2026-10-30,
  nothing started: `redesign/MACOS-PLAN.md` (upstream's Qt interface already runs on macOS; the work is a prebuilt Qt
  from install-qt-action, a `redesign-macos.yml` on arm64, an `.app`/dmg script like `appimage.sh`, then macOS polish;
  its open decisions are signing, Intel, window controls and testing without a Mac). Ask the user before pushing a tag (it publishes the release).
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
- Released 2026-10-30: **v0.1.4** on `ccfb04a8d0` (full release, Latest; all three CI runs of that commit passed; the
  release workflow run 41073547617 published the five fixed-name assets). It has everything since v0.1.3 (`f77757e895`):
  the 2026-10-29 backlog (square music covers, Network page without Browse devices and with Add Stream in the "..."
  menu, drag from the player's library card into the queue), the evening batch (A-Z default sort in the folder trees,
  Back/Forward up and down, header gap over list column titles, themed stock dialogs), menus keeping the Day/Night
  palette on Windows, and the global shortcuts with the X11 compositor (`006bec0`). The drag into the queue was tested
  by hand by the user on 2026-10-31: it works.
- Released 2026-11-02: **v0.1.6** on `3b94336e64` (full release, Latest; four CI runs green; release run 41344525346).
  New: deb/rpm/Arch packages (`extras/package/redesign/linux-packages.sh`, nfpm; `/opt/vlc-juxtopposed`, command
  `vlc-juxtopposed`; job `install-test` installs them on Ubuntu 24.04, Debian 13, Fedora, openSUSE Tumbleweed, Arch) and
  signed apt (`stable main`) and pacman (`[vlc-juxtopposed]`, `/arch/x86_64`) repositories on the fork's GitHub Pages
  (https://sabaoongfx.github.io/vlc-qt-redesign-fork/, build type workflow, `github-pages` environment allows `v*` tags),
  key "VLC juxtopposed packages" F092723FE6C0D16999EB7F6019D03339EB84F8FB in secret `PACKAGES_GPG_PRIVATE_KEY` (backup:
  the user's keyring). AppImage fixes found on the user's Wayland session: Qt's wayland-egl client plugin and the SVG
  icon engine were never bundled (linuxdeploy-plugin-qt ignores EXTRA_QT_PLUGINS; the window never opened), and every
  Linux package was built WITHOUT VLC's Wayland video outputs (Ubuntu 24.04's wayland-scanner 1.22 < 1.23, configure
  only warned): the video went into an X11 window and vanished after a while. CI now builds wayland-scanner 1.23.1 and
  configures `--enable-wayland`; `appimage.sh` refuses a tree without `libegl_wl_plugin.so`. Also: right-click Play on a
  video folder opens the player and recurses into subfolders (`convertMLFolderToPlaylistMedias`), bars over the video
  show by edge proximity (`Player.qml` `_edgeBars`), no repeated title under the system title bar, player top bar 40px
  again with the system title bar (broken since `4bc9f18`). Project documents: `redesign/docs/` (FRS, runbook, ...).
- Released 2026-11-02: **v0.1.7** on `ded202e807` (Latest; four CI runs green; release run 41425836503; pacman repo
  serves 0.1.7-1). Resync retries failed files (medialibrary patch in `extras/package/redesign/`), Qt file dialog
  buttons, 3:1 contrast fixes, smooth volume wedge, Enter = fullscreen, queue titles + the queue panel + button.
  The workflow notes are generic: the changelog section was prepended with `gh release edit`.
- After v0.1.7 (2026-11-02, all pushed, not released): queue rows no longer blank when a file has an empty title tag
  (`src/input/es_out.c` EsOutUpdateMeta skips a blank title, `playlist_item.cpp` falls back to the file name; keep the
  core change when rebasing), Open Recent submenu capped at 480 px with middle-elided paths and tooltips
  (`custom_menus.cpp` RecentMenu; `menus.cpp` reads the `elideMode` property), seek/volume hotkeys keep the bars over
  the video hidden, Tab still shows them (`Player.qml` Keys.onPressed), `redesign/docs/13-feature-inventory.md`.
  Code head `857cb1d3b6` (empty commit on `9fe22a14dc`): Windows, Linux packages and Linux build green; macOS never got a
  runner (see the macOS state section).
- Released 2026-11-03: **v0.1.8** on `857cb1d3b6` (Latest; four CI runs green, the macOS run 41490660300 got a runner on
  its re-run the next morning; release run 41620701150; apt and pacman serve 0.1.8-1). The post-v0.1.7 fixes above.
- Released 2026-11-09: **v0.1.9** on `d20c028a3b` (four CI runs green; release run 42521771567). The first subtitle
  turns on when the selected audio track is tagged non-English and no subtitle is on (`PlayerControllerPrivate::
  applyAutoSubtitle`, 600 ms after the track events settle; untagged audio = no change; option `qt-auto-subtitles`).
  Checked by hand on Linux only (generated mkv with jpn/eng audio + two srt tracks: jpn turns on `spu/3`, the first;
  eng none). The option has no row in the Figma Settings pages: it shows only in Settings' All view (switch at the
  bottom left, next to Save) under Interface > Main interfaces > Qt. The blog post offers a Subtitles row if asked.
  Release notes, changelog and post were written with the wrong path at first ("Advanced Options" is the fold-out
  bar on each Settings page, not the All view); check UI paths in the code before writing them for users.
- Released 2026-11-11: **v0.1.10** on `a67f9c82f9` (four CI runs green; release run 42894038211). The Figma menus
  (file, playlist, right-click Hide UI, sort tick, View Options, folder menu icons), the Playlists page listing
  every playlist, the darker volume fill, no second cone. Blog `whats-new-in-0-1-10` (vlc-web).
- Released 2026-11-11: **v0.1.11** on `7979c8a2fd` (the changelog commit; the first tag sat on a `[skip ci]` commit, so
  no runs and no release: deleted and re-tagged). Post-v0.1.10 work (top bar order, Next/Previous tooltips, badges,
  playlist play order, list progress bars, Figma right-click menu, 265px menus). Blog `whats-new-in-0-1-11`.
- CI caches: the repo hit GitHub's 10 GB cache limit on 2026-11-01 (one ccache per commit per workflow) and the Windows
  contrib cache was evicted (a 2-hour rebuild). Each ccache workflow now has a `prune-ccache` job keeping only the
  current commit's ccache. If a Windows run takes over an hour, check `gh cache list` for the contrib key.
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
| 7 Polish and release | in progress: day+night review of home, library (grid, list, albums, tracks), player, tracks panel, Preferences and file dialog done; floating sidebar panel intentionally skipped (the content pane's rounded top-left corner over the sidebar is close enough and avoids layout risk). Artist page captured (`lib-artist-*`; album section backgrounds now follow the theme, were pure white in Day; the artist banner is a dark scrim over artwork on purpose). Open: icon set, macOS build (`redesign/MACOS-PLAN.md`), upstream patches. Windows x64 cross-build compiles and packages a portable zip (`.github/workflows/redesign-windows.yml`; artifact `vlc-win64-portable`, ~93 MB; the first run takes ~80-120 min because the prebuilt contrib URL 404s and contribs build from source, the contrib cache is saved right after the build; runs on every push to `redesign` since 2026-10-27; build dir is `win64`, not `x86_64`; a second job runs the portable build on `windows-latest` and uploads the `windows-screenshots` artifact via `.github/scripts/win-shots.ps1`: system/day/night main, Preferences tabs, player; 1024x768 runner; the desktop is captured, UI Automation clicks the tabs; verified System mode: accent palette, ticks, chevrons, start screen; Day/Night shots need the .ini fix, rerun pending) |

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
- Out of scope: the Cocoa macOS interface (`macosx/`; macOS gets the Qt interface, see `redesign/MACOS-PLAN.md`), skins2, ncurses, and the prototype's mock-ups (spatializer, stereo widener, OpenSubtitles search).
- Keep the branch rebase-able onto upstream VLC; prefer small, QML-only changes.
