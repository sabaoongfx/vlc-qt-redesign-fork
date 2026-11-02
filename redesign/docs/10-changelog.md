# 10 Changelog

User-facing changes per release. Tags on `redesign`; the release pages on GitHub have the assets.

## Unreleased
- **Resync** picks up files that failed to be read before (e.g. still downloading when the library
  first saw them); before, they never entered the library.
- **Qt's own file dialog** (AppImage and packages on KDE): the toolbar buttons (back, forward, up, new
  folder, list and detail view) are visible in the dark theme and 28 px targets.
- **Contrast:** every control stands out at least 3:1 (WCAG 1.4.11) and text 4.5:1: darker accent text
  on the selected pills in Day, lighter Off-switch knobs and inactive slider handles, an outline on the
  volume cone, a darker "Advanced Options" in Day.

## v0.1.6 (2026-11-02)
- **Linux packages:** `.deb` (Debian 13, Ubuntu 24.04+), `.rpm` (Fedora, openSUSE Tumbleweed) and an
  Arch package, installed in `/opt/vlc-juxtopposed` with the command `vlc-juxtopposed`, next to the
  distribution's VLC. Signed apt and pacman repositories for updates.
- **AppImage on Wayland:** the window opens (Wayland EGL plugin bundled) and the video no longer
  disappears after a while (VLC's Wayland video output is built in); SVG menu icons are coloured again.
- **Right-click Play on a video folder** opens the video player and plays the folder's videos and
  those of its subfolders (a series of season folders played nothing before).
- **Fullscreen:** the top bar shows only near the top edge, the control bar only near the bottom,
  nothing in between; each stays while the pointer is there.
- The window title is no longer repeated inside the window under the system title bar; the player's
  top bar is 40 px again with the system title bar.
- Library thumbnails: a dark tinted tile for videos without a thumbnail, no orange "new" corner,
  more time for slow videos.

## v0.1.5 (2026-10-30)
- The system title bar by default on Windows, Linux and macOS.
- First macOS release (`VLC-juxtopposed-arm64.dmg`, Apple silicon): native menu bar, Cmd+, for
  Settings, files opened from Finder or dropped on the Dock icon, ⌘O in the start hint.
- The old Video pages (All, groups) removed in favour of the folder tree.

## v0.1.4 (2026-10-30)
- Square music covers in the music folder tree and the player's library card.
- Network page: Add Stream moved to the "..." menu; no Browse devices button; spacing above the list header.
- Drag from the player's library card into the play queue.
- Folder trees sort A to Z by default; Back/Forward go up and down the folder tree.
- Column titles no longer sit on the header line; themed stock dialogs (e.g. Delete playlist) on Windows.
- Menus keep the Day/Night palette on Windows; global shortcuts work with the X11 compositor.

## v0.1.3 (2026-10-29)
- Videos and Music as folder trees with an address line; Playlists as a sidebar entry.
- The player's library card with an icon rail (Home, Videos, Music, Network, Playlists, Recent, Add).
- Network page with saved streams and the Figma "Open network stream" dialog (Play saves and plays).
- New Playlist dialog; playlist "..." menu (Play, Shuffle, Export Playlist, Add to Queue, Rename, Delete).
- Resume prompt "You already watched till HH:MM:SS" with Continue Watching.
- Control bar: library button, 10 s back/forward; the play button is grey while playing.
- Mini player Queue card; close button on the mini player cover.
- Many fixes found by CI's new QML warning list (crashes opening Music folders, missing buttons).

## v0.1.3-rc1 (2026-10-28, pre-release)
Release candidate of v0.1.3.

## v0.1.2 (2026-10-28)
- Same code as v0.1.1. First release with fixed asset names only, GitHub build attestations, and a
  full (not pre-) release so `releases/latest/download` links work.

## v0.1.1 (2026-10-28, pre-release)
- "Remove from list" in Continue Watching.
- Opening a tracks/audio/effects panel closes the play queue.
- The player is dark for every embedded video, also with pinned controls.
- Windows build without VideoLAN's update check.

## v0.1.0 (2026-10-27, pre-release)
- First release: redesigned shell, library, player, side panels, menus and Settings; Windows
  installer and portable zip; Linux AppImage and tarball. (The first v0.1.0 was withdrawn and re-tagged:
  its Windows build showed only the video, see ADR-009.)
