# Test findings (collected, not fixed)

Bugs the harness tests found, kept here until the user plans the fixes (same practice as
`settings-findings.md`). Each entry: what is wrong, the failing check, the likely cause.

## Player (2026-11-13)

| What | Check | Likely cause |
|---|---|---|
| **The side panel closes by itself** (Settings panel / effects): the 10 s idle timer of the normal window keeps counting while the panel is open; used without moving the pointer (keyboard into it, a screen reader, AT-SPI) the bars hide after 10 s, the video fills the window and the panel goes with them. Added by `fd5a3fad96` (bars hide after 10 s). | `effects-video`: "no match: Collapse Colors / Expand Crop" (passes with `--no-qt-pin-controls`, and with a pointer move before those steps) | `windowIdleTimer` in `Player.qml` stops only for auto-hide locks (`lockCount <= 1`) and the library card; the side panel (`TracksMenu`) does not take a lock. AT-SPI actions are not counted as activity either. |
| QML warning when the card goes from Network to Playlists: `CompactLibrary.qml:550: Unable to assign MLUrlModel to MLPlaylistListModel` | `card-sections` (QML warning check) | a typed property in the card keeps the previous section's model for a moment |
| QML warnings when the player returns to a Videos folder page: `PageLoader.qml:99: Cannot assign to non-existent property "parentId" / "title" / "trail"` (known since 2026-10-28, harmless) | `queue-around` (QML warning check) | the folder page's properties are pushed to a page that does not declare them |
| QML warning on a queue drag: `PlaylistPane.qml:78: DragItem: grabToImage: item is not attached to a window` (the drag itself works) | `queue-reorder` (QML warning check) | the drag image is grabbed from an item outside the window |
| **Screen readers cannot tell which audio track is on**: in the tracks picker the Audio tab's radio buttons never report the checked state (the Subtitles tab's do); the tick is drawn | `audio-menu-switch` (checked by the tick's pixels instead) | the Audio tab's delegate does not set `checked`/`Accessible.checked` the way the Subtitles tab does |
| **The Convert window has no profile** (Profile box empty, so Start stays disabled), seen in the harness's fresh profile; not yet confirmed on a real install (the profiles may only be missing from a profile that never had them written) | `video-convert` ("Convert has a profile selected") | to check: where the default transcoding profiles come from (`sout/profile_selector.cpp`, Qt settings `codecs-profiles-*`) and whether the redesign's dialog styling or first-run path skips them |
| The Convert window's "Delete selected profile" button: red icon 2.88:1 on its dark face (under 3:1) | `video-convert` (contrast) | the Widgets profile toolbar keeps VLC's red delete icon |
| The player's library card, Music section, lists the **Videos** folder instead of the Music folder (the library's own Music page is right: Music, 6 songs) | `card-sections`: "music: card lists Music", "the Videos folder is not listed under Music" | `MLVideoFolderTreeModel::setAudio` only emits `resetRequested`, which refreshes with the existing loader; the loader holds a copy of the `audio` flag from when it was made (`createMLLoader` copies the model). The card sets `audio` after `ml`, so the first loader is a video one. `setSearchPattern` and the others call `resetCache()`, which makes a new loader. |

## Qt unit tests (2026-11-13, first CI run of `qt-unit-tests`, run 43298787021)

| What | Check | Likely cause |
|---|---|---|
| FIXED 2026-11-13 (`tests/test_ml_model_stubs.cpp`, stand-ins for the three functions; confirm in CI): `test_ml_model` did not link: undefined `MainCtx::settingValue`, `MainCtx::setSettingValue` (from `MediaLib::recordVisit` / `frequentVisits`) and `DialogsProvider::streamingDialog` (from `MediaLib::streamMedia`) | `make -C modules/gui/qt check` | the redesign added these calls to `medialibrary/medialib.cpp`; the test links `medialib.cpp` with stubs (`tests/vlc_stub_modules.cpp`) but without `MainCtx`/`DialogsProvider`. Fix options: move the calls behind an interface the test can stub, or add stubs for the three functions to the test. |

## Documentation (2026-11-13, found while writing the library tests)

| What | Where |
|---|---|
| The Music Albums, Artists, Genres and Tracks pages are listed as features, but nothing reaches them any more: the Music page is a folder tree (`MusicDisplay.qml`: "The artist, album, track and genre pages are no longer reached from here") and so is the player card's Music section. Tested instead: the Music folder tree (`music-folder`). | `redesign/docs/13-feature-inventory.md` (Library: Music), `07-test-strategy.md` |
| The folder "..." menu is listed as Add File, Add Folder, Resync, Info; Info (and Edit Subtitle/Audio Tracks) only appear while something is playing. | `13-feature-inventory.md` |

## Not testable in the harness yet

| What | Why |
|---|---|
| Volume bar level when a video starts | The harness plays through `--aout=adummy` (silent), which has no volume: the Volume slider reads 0 and Ctrl+Up does not change it. Needs a silent output with a volume (e.g. a PulseAudio null sink in the nested session). |
| Shuffle turning random on | `pl-shuffle` checks that the playlist plays with both items queued; the random state itself is not shown anywhere AT-SPI can read. |
| Windows and macOS behaviour | The harness needs KWin, xdotool and AT-SPI (Linux only); those platforms have screenshots in their own workflows. |
| New-version toast | Needs a build whose revision stamp is a release tag and network access to GitHub's API. |
| Equalizer contrast in `effects-audio` (fails: "1 KHz" slider 2.67:1) | The slider is scrolled out of sight inside the panel but AT-SPI still reports it on screen, so contrast.py measures it under the control bar. A harness limit, not an app bug; it did not fail on 2026-11-11 (the panel scrolled differently). |
