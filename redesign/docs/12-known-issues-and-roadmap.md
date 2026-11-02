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
| K14 | Day theme: accent text on the accent-dim pill (selected Settings choices such as Day and Simple, the Save button of Customize Player) is 1.8-2.2:1 | Day | `contrast.py`; WCAG 1.4.11/1.4.3 need 3/4.5:1. Owner to decide (darker accent for text in Day) |
| K15 | Grey slider handles and the Off switch knob on the dark panels (equalizer, compressor, video colours) are #404040 on #090909-#1A1A1A, 1.7-1.9:1 | Night | `contrast.py`; Figma greys |
| K16 | The volume slider's track is #191919 on #090909 (1.13:1): at low volume the control is barely visible | Night | `contrast.py`; Figma track colour |
| K17 | "Advanced Options" in Settings (Day) is 2.7:1 | Day | `contrast.py` |

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
5. **Player:** subtitle timeline, waveform seek bar, bookmarks panel (Ctrl+B), shortcut hints in the OSD.
6. **Mini player:** hover overlay (close, pop-out, previous/play/next), drag to reorder the queue.
7. **Settings presets/profiles; Add Subtitles to Playlist.**
8. **Audio:** visualizer, EQ presets frames; HDR, spatializer and stereo widener frames as far as VLC
   supports them.
9. **Library card:** Podcasts/Radio, sort/view/pop-out buttons.
10. **macOS:** Intel build, notarization, window controls, polish (`redesign/MACOS-PLAN.md`).
11. **Upstream:** propose the small generic patches (04: subfolder wrappers, folder play order).
