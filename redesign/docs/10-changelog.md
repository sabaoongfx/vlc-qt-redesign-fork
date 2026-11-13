# 10 Changelog

User-facing changes per release. Tags on `redesign`; the release pages on GitHub have the assets.

## v0.1.14 (2026-11-14)
- **Play queue panel as in the design:** a 400 px card with the tabs **Queue**, **Bookmarks** and
  **Chapters**. Chapters lists the video's chapters with their start times; a click jumps there.
  Bookmarks lists your bookmarks with their times down to the millisecond: **+** adds one at the current
  time, **-** removes the selected one, a click jumps there, a double click renames it. Bookmarks are kept
  by the library, so a file outside it shows a note instead.
- **Ctrl+B** opens the queue panel on Bookmarks while a video plays (again to close it).
- **Home shows your playlists** in a row, like the other rows; a click opens the playlist and See All opens
  the Playlists page.
- **Resume on playlists:** hover a playlist you have started and press **Resume** to continue from the video
  you played last, where you stopped.
- **Audio visualizer:** a new Visualizer choice in the side panel's Audio tab (Disabled, Spectrometer,
  Scope, Spectrum, VU Meter) with the design's icons.
- **Music player as in the design:** a large rounded cover with the blurred cover behind it and one line
  "title - artist" under it.
- **Mini player:** a square cover is no longer stretched; it sits in the middle over its own blurred copy.
- **Fullscreen:** jumping 10 seconds (buttons, keys, the seek bar) no longer draws the time and a bar
  over the picture.

## v0.1.13 (2026-11-13)
- **Videos continue where you left them** without asking: a small "Continued from 00:12:34" note shows
  for 10 seconds with a **Start over** button.
- **New version notice:** VLC (juxtopposed) checks once a week for a newer release and shows a small card
  you can close (Settings > "Check for updates automatically" turns it off). This is the first version
  that checks, so you will first see it when the next one comes out.
- **Subtitles button** opens the tracks picker on Subtitles; the **audio button** opens the same picker on
  Audio (it had its own small menu).
- **Audio output:** the device in use is ticked, and choosing another device while playing switches to it
  at once (PipeWire on Linux).
- **Normal window:** the bars hide after 10 seconds of no mouse movement and the video fills the window,
  like fullscreen. Open panels and menus keep them up.
- **Left menu and library card** open over the video instead of pushing it aside.
- **Play queue:** one click plays a row. **Add to Queue** puts the playing episode in its place in the
  list (episode 47 of 1-100 stays between 46 and 48).
- **Right-click menu on the video** is a little smaller (280 px wide, 44 px rows).
- **Equalizer presets** have the design's curve icon in front of each name.
- **Fixed:** the side panel closing by itself after 10 seconds; the player's library card showing videos
  under Music; audio or video tracks added with Edit Audio/Video Tracks missing from the picker; Convert
  opening with an empty profile box (the delete icon is now readable too).

## v0.1.12 (2026-11-11)
- **Volume bar:** it shows the real volume as soon as VLC opens or a video starts; before, it stayed
  empty until you touched the volume.
- **U key:** shows or hides the library menu beside the video. Both library buttons say "(U)" in their
  tooltip.
- **Volume control:** the cone has no grey outline any more, as in the design.
- **Hand pointer** on the play/pause button and on the rows of the play queue (double-click a row still
  plays it).

## v0.1.11 (2026-11-11)
- **Right-click menu on the video** now matches the design: Previous Item, Next Item, the Playback,
  Video, Audio and Subtitle submenus, More Settings (was Tools), Playlist (was View) and Quit VLC, with
  thin lines between the groups. The Fullscreen entry is gone from it; double-click, F or Enter still
  switch to fullscreen.
- **Menu sizes as in the design:** menus are 265 px wide (the right-click menu 292 px) and their icons
  are drawn at the design's size.
- **Player top bar:** the "..." menu button is now first on the left, the library button after it.
- **Next and Previous** show their keyboard key in the tooltip, for example "Next (N)".
- **Playlist cards:** the video count is readable in the dark theme, and files the library has not
  read yet are counted as videos instead of "others".
- **Playlists:** a video clicked inside a playlist plays with the whole playlist in the queue, starting
  at that video.
- **List view:** a video you started shows its progress bar under the thumbnail, like the grid.

## v0.1.10 (2026-11-11)
- **Menus drawn from the design:** every menu now follows the redesign's menu frames, with their
  orange-and-grey icons.
  - **Right-click on a video or song in the library:** Play, Mark as Watched, Favorite, Stream,
    Convert, Add to Queue, Add to Playlist, Show in File Manager (File Explorer on Windows, Finder on
    macOS), Properties & Metadata. Stream and Convert are new here: they open VLC's Stream and Convert
    windows with the file filled in.
  - **Right-click on a playlist:** Play, Shuffle, Export Playlist, Add to Queue, Rename, Delete, now
    also from the library beside the video while something plays (Playlists in the left rail).
  - **Right-click on the video:** a new **Hide UI** entry (Ctrl+H) hides the bars and the side menu;
    Ctrl+H brings them back.
  - **Sort:** the current order has an orange tick; Videos and Music folders tick Title A-Z when you
    never chose one. Music folders can also sort by Artist, Album and Track Number.
  - **Grid or list:** the view button opens a small menu (Grid View, List View) instead of switching
    at once.
- **Playlists page:** a playlist saved with only a name (and a playlist of only songs) now shows up;
  before, it was saved but never listed.
- **Volume control:** the fill colours are a little darker, as in the design.
- **One VLC logo:** the cone in VLC's top bar is gone when the window has the system title bar, which
  shows the VLC icon already.

## v0.1.9 (2026-11-09)
- **Subtitles for foreign-language audio:** when the audio track is tagged with a language other than
  English and no subtitle is on, the first subtitle track turns on by itself (also when you switch to
  another non-English audio track). Untagged audio is left alone. Off switch: Settings, All (bottom
  left) > Interface > Main interfaces > Qt, "Subtitles on for non-English audio" (`qt-auto-subtitles`).

## v0.1.8 (2026-11-03)
- **Play queue:** the file opened from the file manager no longer shows "Unknown Title" (an empty
  title tag blanked its name once it played).
- **Open Recent** opens beside the menu instead of over it: at most 480 px wide, long paths are
  shortened in the middle, the full path is the tooltip.
- **Bars over the video** stay hidden when you seek or change the volume with the keyboard (also in
  fullscreen); Tab still shows them for keyboard navigation.

## v0.1.7 (2026-11-02)
- **Resync** picks up files that failed to be read before (e.g. still downloading when the library
  first saw them); before, they never entered the library.
- **Qt's own file dialog** (AppImage and packages on KDE): the toolbar buttons (back, forward, up, new
  folder, list and detail view) are visible in the dark theme and 28 px targets.
- **Play queue:** files with an empty title tag show their file name instead of "Unknown Title";
  the player's Play Queue panel has a + button to add files (as the mini player's Queue card).
- **Enter toggles fullscreen** in the player, like F (keypad Enter too). On a DVD/Blu-ray menu Enter
  still selects; in a text field, the side panels and the library card it keeps its usual meaning.
- **Volume control** drawn as the smooth Figma wedge (it had stair-stepped sides and was ~20% small).
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
