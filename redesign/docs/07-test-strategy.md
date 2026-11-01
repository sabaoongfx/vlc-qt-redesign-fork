# 07 Test strategy and coverage

## Layers

| Layer | Where | What it catches | When |
|---|---|---|---|
| Compile | every workflow | C++ errors, QML syntax (qmlcachegen) | every push |
| QML warnings | harness `check.py`, CI "QML warnings" step | load errors, binding loops, undefined references (they never fail a build by themselves) | every scene / every push |
| Harness scenes | `redesign/tests/` (62 scenes) | behaviour and look in a real VLC, measured against Figma | locally, before pushing UI work |
| CI screenshots | Linux, Windows, macOS workflows | platform-specific breakage (Windows Qt without Canvas, Day/Night palettes) | every push |
| Package install tests | `redesign-linux-packages.yml` `install-test` | missing dependencies, broken relocation, stale plugin cache | every push |
| Manual checklist | 06 | drag and drop, Wayland, Windows installer | each release |
| Unit tests | `modules/gui/qt/tests/` | `test_navigation_model` (rewritten, never built or run) | not running |

## The harness

`redesign/tests/run.sh [scene-regex]` runs scenes from `scenarios.txt` in a headless nested KWin
(xdotool clicks, AT-SPI presses, screenshots, geometry), then `check.py` writes
`out/run/report.html`. A full run takes ~25 min (run it in the background; do not rebuild meanwhile).

- Scene line: `name | theme (0 system, 1 day, 2 night) | kind (ml, none) | media | actions`.
- Actions: `sleep: move: resize: click: rclick: dclick: key: type: press:Name shot: shotwin: geom: audit: tree`.
- `OUT=<dir>` keeps the main output; `SCEN=<file>` uses another scene list; `QPA=wayland` runs VLC as a
  native Wayland client; `KWINRULES=<file>` replaces the window rules (default: maximised).
- `check.py` checks: QML warnings in every log; colours, positions and sizes against the Figma frames;
  hover growth; vlcrc unchanged after Settings Save; accessibility audits.

Totals at v0.1.6: 62 scenes, about 59 measured checks plus the per-scene warning check (50/50 passing
in the player subset on 2026-11-01).

## Coverage matrix

**Measured** = `check.py` asserts values. **Shot** = screenshot only, judged by eye. **None** = no scene.

| Area | Scenes | Level |
|---|---|---|
| Home (Night/Day/System), no-library start | `home-*`, `start-nolib`, `a11y-home` | Shot + a11y |
| Videos grid, folder tree, search, sort | `video-grid`, `folder-tree`, `search`, `sort`, `a11y-video` | Measured (grid, tree) |
| Video hover/click/list click | `video-hover`, `video-click`, `video-list-click` | Shot |
| Context menu on video / folder Play | `video-ctx`, `folder-ctx-play` | Shot |
| Music albums | `music-albums`, `a11y-music` | Shot + a11y |
| Mini player, after end | `lib-mini-video`, `lib-mini-audio`, `lib-after-end` | Measured |
| Player bars, paused, Day/System | `player-playing`, `player-paused`, `player-day`, `player-system` | Measured |
| Seek preview | `player-seekhover` | Measured |
| Fullscreen edge bars | `edge-bars` | Shot |
| Side panel tabs, Day | `panel-tabs`, `panel-day`, `a11y-panel` | Measured |
| Play queue panel | `queue-open` | Measured |
| Tracks picker, effects | `tracks-picker`, `effects-video`, `effects-audio`, `effects-gear` | Shot |
| Resume prompt | `resume-first`, `resume-prompt` | Measured |
| Right-click menu, main menus, shortcuts in menus | `rclick-menu`, `main-menu*`, `menu-shortcuts`, `dots-hover*`, `audio-menu*` | Measured (rclick) |
| Settings | `prefs*` (8 scenes), `a11y-prefs` | Measured |
| Open network stream dialog | `open-network*` | Shot |
| Customize Player | `customize*` | Measured |
| Long titles | `player-longtitle` | Shot |

**Not covered (no scene):** Network saved streams list and Add Stream from the "..." menu; Playlists
page, New Playlist dialog, playlist "..." menu (Export, Rename, Delete); folder "..." menu (Add File,
Add Folder, Resync, Info); player library card and rail, drag into the queue; mini player Queue card;
Back/Forward up/down; Music artists/genres/songs lists; window resizing; unpinned controls in a window;
most keyboard shortcuts.

## Adding a test with a feature

1. Add an FRS requirement (02) with acceptance criteria.
2. Add a scene that performs it (`click`/`press`/`key`) and a `shot`.
3. If the outcome can be measured (a colour, a position, an element present in `geom:`), add a
   `check.py` block named after the scene. Prefer checks that prove the action had its effect (the
   player view opened, a row was added) over pixel checks.
4. Run `redesign/tests/run.sh '<scene>'`, then the related scenes, and keep the scene in `scenarios.txt`.

## Proposed next tests (priority order)

1. One scene per uncovered screen above (gives them the QML warning check at least).
2. Action checks: Play opens the player (video surface present), Add Stream adds a row, Delete
   removes a playlist, folder Play queues the expected first item.
3. Per-setting round trip: for each of the ~106 Settings rows change, Save, check exactly one vlcrc
   option changed, reopen, check the row shows it (~15-20 min as its own run).
4. Build and run `test_navigation_model` in CI.
