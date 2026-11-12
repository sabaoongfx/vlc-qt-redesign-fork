# 12 Known issues and roadmap

Status 2026-11-02. Move an item to 10 (changelog) when it ships, to 08 when a decision is taken.

## Known issues

| # | Issue | Where | Notes |
|---|---|---|---|
| K1 | Ctrl+N does not open the network dialog on Windows | Windows | Not the X11-compositor shortcut bug (fixed in `006bec0`); cause unknown |
| K2 | Right-click on the video opened the menu only every other time on Wayland | Linux, `QPA=wayland` | Seen in the harness (CLAUDE.md); not re-checked since |
| K3 | Settings top bar is the system one plus Save/Cancel; Figma has a frameless window with a close x | all | Owner chose to leave it for now |
| K4 | No way into View/Tools/Help/Quit from the library top bar other than the "..." menu | all | Decide whether that is enough |
| K5 | "Mark as watched" on a folder row may hit an `MLVideo` cast | library | Unverified (FR-LIB-012) |
| K6 | A folder with only subfolders shows no video count | library | The ML has no recursive count |
| K7 | `MLVideoFolderTreeModel` loads the subfolder list twice per refresh | library | Performance smell |
| K8 | In the Windows Day shots the title and bottom bars look mid-grey | Windows | Probably the Windows blur over the desktop; unchecked |
| K9 | Windows and macOS builds are not code-signed / notarized | Windows, macOS | 09 |
| K10 | GitHub Issues are off on the repository | project | Users have no public place to report bugs |
| K11 | `test_navigation_model` is not built or run | tests | 07 |
| K12 | Discover pages (Services, URL) are unreachable code | Qt module | Dead code kept for rebase-ability (04) |
| K13 | Local AppImage packaging on Manjaro crashes `vlc-cache-gen` in the AppDir | dev machine | CI (Ubuntu) is the reference build |

## Open questions for the owner

- **Folder Play: append or replace the queue?** Today Play appends the folder to the queue (VLC's
  default); after several Plays the queue had 120 items. Options: replace on Play and keep Enqueue for
  appending, or a setting.
- **Unpinned window behaviour:** should a window also hide both bars until the pointer is near an edge
  (video under the bars), or keep pinned bars as the default?
- **AUR:** publish `vlc-juxtopposed-bin` on the AUR (like Open Task Manager's prepared job) in addition
  to the pacman repository?
- **rpm repository:** add a signed dnf/zypper repository (Fedora/openSUSE updates), or keep the rpm as a download?

## Roadmap

Not built yet (Figma frames exist; status per frame in `redesign/remaining/index.html`):

1. **Testing debt:** scenes for every uncovered screen, action checks, per-setting round trip (07).
2. **Onboarding** (11 frames).
3. **Keyboard Shortcuts dialog.**
4. **Home rows:** Listen Again, Frequently Visited folders.
5. **Player:** subtitle timeline, waveform seek bar, shortcut hints in the OSD; the queue panel's Bookmarks and
   Chapters tabs (planned below).
6. **Mini player:** hover overlay (close, pop-out, previous/play/next), drag to reorder the queue.
7. **Settings presets/profiles; Add Subtitles to Playlist.**
8. **Audio:** HDR, spatializer and stereo widener frames as far as VLC supports them; the visualizer
   (planned below). EQ preset icons: being built (2026-11-13).

### Planned: queue panel with Bookmarks and Chapters tabs (Figma "Queue", planned 2026-11-13)

- **What the Figma has** (`VLC Redesign (Community) (5).zip`: `Queue.svg`, `Queue-1.svg`, 400 x 946): the
  play queue panel gets a tab bar, Queue | Bookmarks | Chapters (icon + label, accent underline and accent
  icon on the current tab, dark bar). The Queue tab is not drawn: it is today's queue list.
  - **Bookmarks:** a header "N Bookmarks" with - (remove the selected one) and + (add one at the current
    time); rows: name left ("DON'T BLINK 1"), time with milliseconds right ("00:00:42:023").
  - **Chapters:** rows: accent number, chapter name, start time right (00:02:15); no header.
- **Backend (exists):** bookmarks: the player's bookmark functions (add, remove, rename, jump; today only in
  the old Widgets Bookmarks dialog); chapters: the player's chapter list (`Player` chapters model, already used
  by the seek bar's chapter marks).
- **Behaviour to build:** a click on a bookmark or a chapter seeks there; double-click renames a bookmark (as
  in VLC's dialog); + adds at the current time; - removes the selected one; Ctrl+B opens the panel on
  Bookmarks. The tabs replace the panel's "Play Queue" title; the queue's sort/search/add buttons stay on the
  Queue tab.
- **Tests first:** a fixture video with chapters (ffmpeg metadata chapters) and a scene per tab: the chapter
  rows and their times, a click seeks (seek bar time), + adds a bookmark at the current time, - removes it,
  rename, the accent tab underline follows the tab; the queue tab still passes the queue scenes.
- **Effort:** ~1 day.

### Planned: audio visualizer picker (Figma "Audio Visualizer", planned 2026-11-13)

- **What the Figma has:** a dropdown (Disabled, Spectometer, Scope, Spectrum, Waveform, each with a
  duotone icon; `~/Downloads/Audio Visualizer.svg`, also in the Figma export under 06 Player side
  panels). No frame places it: it is a lone component at the side panel card width (362 px).
- **Where it goes:** a "Visualizer" row in the side panel's Audio tab, next to Stereo Mode and Mix Mode
  (`TracksListPage.qml`). It sets VLC's `audio-visual` option for the current playback
  (`effects_controller`), like the "..." menu > Audio > Visualizations entries do today.
- **Where it shows:** VLC draws a visualization as a video, so it fills the player's video area while
  audio plays, in place of the cover art of `Player - Music`. Turning it off brings the cover back.
- **Mapping:** Spectometer = `visual` effect `spectrometer`; Scope = `scope`; Spectrum = `spectrum`;
  Waveform has no exact match (VLC's scope already draws the waveform; the closest separate one is
  `vuMeter`), to be decided. VLC's Goom, 3D spectrum and projectM stay out unless asked (the Figma
  has none of them). Spelling: "Spectrometer" in the interface.
- **Open decisions:** the Waveform entry; whether the choice is remembered (the option is global in
  vlcrc) or only for the current playback.
- **Tests first:** a scene plays an mp3 with sound:null (a real, silent audio output), picks each entry
  and checks the video area shows the visualization (not the cover) and the dropdown ticks it; picks
  Disabled and checks the cover is back.
- **Effort:** ~1 day (the row and dropdown with icons reuse the EQ preset dropdown's work).
9. **Library card:** Podcasts/Radio, sort/view/pop-out buttons.
10. **macOS:** Intel build, notarization, window controls, polish (`redesign/MACOS-PLAN.md`).
11. **Upstream:** propose the small generic patches (04: subfolder wrappers, folder play order).
