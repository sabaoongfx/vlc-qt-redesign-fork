# Redesign test, fix and polish plan

Goal: every screen in the Figma export (`VLC Redesign (Community)`, plus the `(1)` Subtitles panel frames)
matches the build, verified by automated captures instead of by eye, with no regressions.

Order: 1 harness, 2 fix everything it finds, 3 settings UI, 4 pixel polish, 5 CI and docs.
Each phase ends with a full harness run; nothing moves to the next phase with a failing check.

## Status (2026-10-26)

- Phase 1: done. `redesign/tests/run.sh` covers 40+ scenes, with checks for QML warnings, colours,
  sizes, hover growth, rounded mini-player video corners, the Customize Player colours, the Browse
  folder header, settings search, and an unchanged config after Save.
- Phase 2: done for the visual bugs. Fixed: -1 ms durations, the resume prompt, first-run pinned
  controls, Customize Player (now the Figma modal), square mini-player video corners, the Browse
  folder header (back/forward, path crumbs, count, + button), and the tiny media-library folder
  buttons. Menu icons were already 20px. Not done, and these are content changes rather than bugs:
  the sidebar entries (Network, Playlists, Recent, Add item) and the Home rows (Listen Again,
  Frequently Visited Folders) need new pages or models.
- Phase 3: done. There are 13 categories in App / Media / System groups, each a Figma row page
  backed by real options, with the classic pages whole under Advanced Options. There is also a
  search, a segmented Simple / All / Expert switch, and a theme and accent row. Mapping and
  omissions: `redesign/SETTINGS-MAP.md`. The harness found and fixed two upstream Save bugs (list
  combos and generic fonts silently rewrote options).
- Phase 4: next.

## 1. Test harness (`redesign/tests/`)

Turn the ad-hoc scratchpad scripts into a checked-in tool, run with one command.

- **Runner**: headless nested KWin (`kwin_wayland --virtual`), VLC from the build tree, a fresh config per
  run, xdotool for pointer/keys, AT-SPI to press named controls and dump geometry. Fixture media generated
  on the fly (video with/without audio, audio with cover, 4 s clip, long title, multi-track MKV with
  subtitles and two audio tracks, a library of 30+ items).
- **Matrix**: every screen x theme (System, Day, Night) x state, at 1920x1080 and 1280x800, plus 125 % and
  150 % scale for menus and dialogs. Native-Wayland runs for rendering checks (popups, video embedding).
- **States**: idle / no media library, home with library, video and music grids and lists, album, artist,
  browse with breadcrumbs, search typed, sort applied, playing / paused / ended, hover over every bar
  control and the seek bar, every menu and submenu, right-click menus, every side-panel tab, every
  Preferences category, every Widgets dialog, first-run wizard, window resized small, theme switched at
  runtime, fullscreen.
- **Automatic checks** (a run fails on any of these):
  - QML warnings or errors in the log (binding loops, ReferenceError, "unavailable").
  - Colour assertions at known points (play pill and seek handle `#D37918`, seek fill `#371F06`, panel and
    field colours from the Figma frames) per theme.
  - Geometry from AT-SPI against a spec table taken from the Figma frames (bar heights, pill 54x28,
    icon 24 px, sidebar 200 px, gaps), tolerance 1 px for sizes, 2 px for positions.
  - Hover regressions: an element's bounding box must not grow by more than its hover spec
    (catches the "big square" seek handle class of bug).
  - Clipping: no text elided where Figma shows it whole; no icon touching its label in menus.
  - Figma similarity score per screen region (crop both, scale to the same size, SSIM); scores are tracked
    so a change that makes a screen worse is visible.
- **Output**: `report.html` with Figma | build | diff overlay per screen and the failed checks, refreshed
  comparison folders in the Figma export directory.

## 2. Fix the known and found problems

Known before the harness runs:

- `-1 ms` duration under Continue Watching cards.
- The resume prompt replaces the player top bar; it should sit inside the bar layout or as a toast.
- Customize Toolbar (toolbar editor) still has the old look; Figma has a "Customize Player" modal.
- Preferences: horizontal scrollbar on Interface, toggles on the left of labels, Simple / All / Expert
  radios at the bottom.
- Menu icons render at 16 px (Figma 20 px).
- Video in the floating mini player card has square corners.
- Library header crumbs show only the page, not the folder path; no + and more buttons.
- Sidebar items differ from Figma (Network, Playlists, Recent, Add item); Discover has no filled icon.
- Home rows differ (Listen Again, Frequently Visited Folders).
- Windows build: day/night screenshot rerun pending.

Everything the harness flags is added here and fixed, one commit per problem, harness re-run each time.

## 3. Settings UI

Rebuild Preferences as the Figma settings window (sidebar with search, 13 categories, label + info + control
rows with toggles, segmented values and dropdowns on the right, Advanced toggle).

- Map each Figma row to a real VLC option (table in `redesign/SETTINGS-MAP.md`); rows with no option are
  left out, not faked.
- Categories with no Simple page today (General, Privacy, Network, Performance, Recording, Extensions)
  are built from the options that exist in "All" preferences.
- Search filters rows across all categories.
- Implemented in Qt Widgets (same as the current Preferences) so Save / Cancel / Reset keep working.

## 4. Pixel polish

Per screen, in this order: player, library, side panel, menus, settings, dialogs, onboarding.

1. Capture the build in the exact Figma state and size.
2. Crop matching regions, view both at 200-400 %, and list every difference: position, size, spacing,
   radius, font size and weight, colour, icon size, line height.
3. Fix, re-capture, re-measure; repeat until the region passes the tolerance.
4. Add the measured values to the spec table so the harness guards them.

Acceptance: colours exact, sizes within 1 px, positions within 2 px, same font weights, both themes.

## 5. CI and docs

- Push the branch; run Linux and Windows CI; review their screenshots.
- Update `CLAUDE.md` (status, gotchas) and refresh `COMPARISON.md` in the Figma export.
