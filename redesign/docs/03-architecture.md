# 03 Architecture

How the redesign fits into VLC. For general VLC architecture see upstream's docs; this covers what
the redesign touches.

## Layers

```
 QML pages and controls          modules/gui/qt/**/qml/*.qml       (look and behaviour)
        |  properties, signals, Q_INVOKABLE
 C++ models and controllers      modules/gui/qt/{medialibrary,player,util,maininterface,...}/*.cpp
        |  vlc_ml_* / vlc_player_* / vlc_playlist_* C API
 VLC core and modules            src/, modules/misc/medialibrary (wraps the medialibrary library)
```

The Qt interface is one VLC module (`libqt_plugin.so`). QML is compiled into it (qmlcachegen), so a
QML change needs a rebuild. QML load errors do not fail the build: they show as warnings at
`--verbose=1` (the harness and CI collect them).

## Where things live (`modules/gui/qt/`)

| Area | QML | C++ |
|---|---|---|
| Shell, sidebar, top bar | `maininterface/qml/` (`MainDisplay`, `SideNavigationPane`, `LocalTopbar`, `FloatingMiniPlayer`, `MiniPlayerQueue`) | `maininterface/mainctx.*`, `navigationmodel.cpp`, `videosurface.*` |
| Library | `medialibrary/qml/` (`VideoFolderTreeDisplay`, `CompactLibrary`, `HomeDisplay`, `MLContextMenu`, dialogs) | `medialibrary/medialib.*`, `mlvideofoldertreemodel.*`, `mlrecent*model.*`, `mlurlmodel.cpp` |
| Network | `network/qml/NetworkStreamsDisplay.qml` | `medialibrary/mlurlmodel.cpp` |
| Player | `player/qml/` (`Player`, `TopBar`, `ControlBar`, `TracksPicker`, `LibraryRail`, `controlbarcontrols/`) | `player/effects_controller.*`, `player/seek_preview.*`, `player/control_list_model.hpp` |
| Settings | (Widgets) | `dialogs/preferences/simple_preferences.*`, `preferences.cpp` |
| Menus | `menus/qml/GlobalShortcuts.qml` | `menus/menus.*` (`RedesignMenuStyle`), `qml_menu_wrapper.*` |
| Shared widgets | `widgets/qml/` (`PageExt`, `Breadcrumbs`, `LibraryMenuButton`, `DialogTitleBand`...) | `widgets/native/qvlcframe.*` (stylesheet, stock dialogs) |
| Style | `style/VLCStyle.qml` (sizes, `figmaDark`/`figmaDay` colours) | `style/systempalette.*`, `style/redesign.hpp` |
| Icons, fonts | `pixmaps/VLCIcons.ttf` (from `pixmaps/icons/*.svg` via `makeIconFont.py`), `pixmaps/Inter-*.ttf` | registered in `qt.cpp` |

New QML/C++ files must be listed in both `modules/gui/qt/Makefile.am` and `meson.build`.

## Key flows

### Folder tree (Videos/Music)

`VideoFolderTreeDisplay.qml` loads `MLVideoFolderTreeModel` (derives from `MLVideoGroupsModel`).
Level 0: `vlc_ml_list_entry_points`. Level n: `vlc_ml_list_subfolders(id)` (added to
`include/vlc_media_library.h`; not paginated) filtered by the search pattern and sorted by name in
C++, followed by `vlc_ml_list_video_of(folder)` (paginated, A to Z by default). Paging spans both.
The page carries a `trail` of `{id, title}`; back/forward walk the branch (`PageExt.treeNavigation`).

### Playing from the library

- Click on a video: `MediaLib.addAndPlay(id)` then `MainCtx.playerView = true`.
- Context menu Play (`MLContextMenu.addAndPlay`): `model.ml.addAndPlay(ids)`; menus with
  `showPlayAsAudioAction` (the video ones) also set `playerView`.
- `MediaLib::addAndPlay` converts ids on the ML thread (`convertMLItemToPlaylistMedias`): a media id
  becomes one input item; a folder id goes through `convertMLFolderToPlaylistMedias` (own media A to
  Z, then subfolders by name, recursively, depth limit 32); other parents use `vlc_ml_list_media_of`.
  The UI thread appends to the playlist and starts playback.

### Player bars

`Player.qml` owns `PlayerToolbarVisibilityFSM` (auto-hide after `MainCtx.mouseHideTimeout`, locks for
hover/panels). Over the video (`_edgeBars`), `_activeBar` (top/bottom/none/both) chooses which bar
the FSM may show: the `VideoSurface` reports its own pointer moves (`mouseMoved(x, y)`, device pixels)
because it takes the hover events; a `HoverHandler` covers the other items; the pointer in an edge
zone also holds an auto-hide lock (`_edgeLock`).

### Video output

`VideoSurface` (QML item) gives VLC a window through the `qt` vout window module; VLC picks an
OpenGL provider for the platform (`egl_gbm_wl`/`egl_wl` on Wayland, `egl_x11`/`glx` on X11). Builds
without Wayland support (wayland-scanner < 1.23) put the video in an X11 window, which a Wayland
Qt interface cannot keep embedded: packaging now refuses such builds.

### Theme and palette

`VLCStyle.qml` holds two `SystemPalette`s: `themePalette` (follows System/Day/Night; the only one
that sets the application palette) and `darkPalette` (fixed Night, the player). Widgets get
`makeWidgetsPalette()` plus `redesignWidgetsStyleSheet()`; live changes go through
`Redesign::liveStyleSheet`/`onPaletteChange`. Menus are drawn by `RedesignMenuStyle` (a QProxyStyle).

### Settings

`SettingsRows` (in `simple_preferences.cpp`) builds Figma rows bound to VLC options through
`ConfigControl`; a row is written on Save only if its value differs from what it first showed.

## Build and packaging pipeline

```
push to redesign
 ├─ redesign-build.yml            Debian unstable image, medialibrary contrib, screenshots (xvfb), QML warnings
 ├─ redesign-linux-packages.yml   Ubuntu 24.04 + Qt 6.10 -> AppImage + tarball -> deb/rpm/Arch -> install tests (5 distros)
 ├─ redesign-windows.yml          cross-build (contribs cached) -> NSIS exe + zip -> screenshots on windows-latest
 └─ redesign-macos.yml            arm64 -> .app + dmg -> screenshots
tag v*
 └─ redesign-release.yml          waits for those runs -> fixed-name assets, signed rpm, SHA256SUMS, attestations
                                  -> GitHub release -> (full releases) signed apt + pacman repos on GitHub Pages
```

Details in 05 and 06.
