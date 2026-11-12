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
| The player's library card, Music section, lists the **Videos** folder instead of the Music folder (the library's own Music page is right: Music, 6 songs) | `card-sections`: "music: card lists Music", "the Videos folder is not listed under Music" | `MLVideoFolderTreeModel::setAudio` only emits `resetRequested`, which refreshes with the existing loader; the loader holds a copy of the `audio` flag from when it was made (`createMLLoader` copies the model). The card sets `audio` after `ml`, so the first loader is a video one. `setSearchPattern` and the others call `resetCache()`, which makes a new loader. |

## Not testable in the harness yet

| What | Why |
|---|---|
| Volume bar level when a video starts | The harness plays through `--aout=adummy` (silent), which has no volume: the Volume slider reads 0 and Ctrl+Up does not change it. Needs a silent output with a volume (e.g. a PulseAudio null sink in the nested session). |
| Window resizing | The harness KWin rules maximise the main window; `resize:` is overridden. Needs a run with `KWINRULES` set to an empty file (a separate run). |
| New-version toast | Needs a build whose revision stamp is a release tag and network access to GitHub's API. |
| Equalizer contrast in `effects-audio` (fails: "1 KHz" slider 2.67:1) | The slider is scrolled out of sight inside the panel but AT-SPI still reports it on screen, so contrast.py measures it under the control bar. A harness limit, not an app bug; it did not fail on 2026-11-11 (the panel scrolled differently). |
| Audio button menu (`audio-menu*`) | A Qt Widgets QMenu: its items are not reachable through AT-SPI, so only the screenshot is judged. |
