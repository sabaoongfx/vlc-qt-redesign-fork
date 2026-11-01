# 05 Build and packaging

## Local build (Linux)

Development happens on Manjaro (KDE). The tree is configured into `build/` with a local medialibrary
contrib (`contrib/native/`, untracked on purpose) and installs into `install/`.

```bash
make -C build -j$(nproc)          # ~25 s for a Qt-module change; QML is compiled in, rebuild before testing
./build/vlc --verbose=1           # QML errors only reach the log at verbosity 1
make -C build install             # refresh install/ (prefix of the configure)
```

- New QML/C++ files go in `modules/gui/qt/Makefile.am` AND `meson.build`.
- Test runs are muted (`--aout=adummy`). Never kill or restart a VLC the user is running; rebuilding
  under it is safe (the running process keeps the old plugin).
- If `lua51` disappears, the Lua plugin is recompiled against Lua 5.4 headers and fails to link:
  reinstall `lua51` and delete its objects.

## CI workflows (`.github/workflows/`)

All run on every push to `redesign`, except a push whose head commit says `[skip ci]`. One run per
workflow at a time; a newer push replaces a still-pending run (shown as cancelled), never a running one.

| Workflow | Runner | Output | Notes |
|---|---|---|---|
| `redesign-build.yml` | Debian unstable VideoLAN image (container) | `vlc-linux-install`, `screenshots` (xvfb 1920x1080, Day/Night, library, player, dialogs), QML warnings annotations | medialibrary built as a contrib (cached); runs VLC as `shotuser` (VLC refuses root) |
| `redesign-linux-packages.yml` | Ubuntu 24.04 + Qt 6.10 (install-qt-action) | `vlc-linux-packages` (AppImage, tarball), `vlc-linux-distro-packages` (deb, rpm, Arch with a CI version) | job `install-test` installs on 5 distros |
| `redesign-windows.yml` | cross-build, then `windows-latest` for shots | `vlc-win64-portable` (exe, zip), `windows-screenshots` | first run 80-120 min (contribs from source), cached ~30 min |
| `redesign-macos.yml` | macOS arm64 | `vlc-macos-arm64` (dmg), `macos-screenshots` | see `redesign/MACOS-PLAN.md` |
| `redesign-release.yml` | on `v*` tags | the GitHub release, Pages repos | see 06 |

Judge UI changes from the screenshots and the QML warning list, not from a green check: QML errors
do not fail a build.

## Linux packages

### AppImage and tarball (`extras/package/redesign/appimage.sh`)

`appimage.sh <installed prefix> <src> <qmake6> <out>` relocates the install into an AppDir, gives
binaries/libs/plugins `$ORIGIN` rpaths (a `/usr` build has none), runs linuxdeploy with the Qt plugin,
strips with system binutils, builds the plugin cache after linuxdeploy rewrote the plugins, and makes
`VLC-juxtopposed-x86_64.AppImage` plus the same tree as `.tar.gz`.

Requirements and traps (each cost a broken build or release once):

- **Wayland:** VLC's configure needs wayland-scanner >= 1.23; Ubuntu 24.04 has 1.22. The workflow
  builds 1.23.1 from source (scanner only, sha256-checked) and configures with `--enable-wayland`;
  `appimage.sh` refuses a tree without `libegl_wl_plugin.so`/`libxdg_shell_plugin.so`.
- **Qt plugins linuxdeploy skips:** `wayland-graphics-integration-client` (Wayland EGL; without it the
  window never opens on Wayland) and `iconengines` (SVG icons) are copied by the script itself.
- linuxdeploy's strip fails on `.relr.dyn` (`NO_STRIP=1`, system strip after).
- Qt's TIFF/WebP/MNG image plugins need `libtiff.so.5`: deleted after the Qt install.
- `apt-get build-dep` sometimes hangs: apt calls retry 3 times with an 8 min timeout.
- Locally: use a `qmake6` wrapper whose `QT_INSTALL_PLUGINS` has no KDE `kimg_*` plugins; a tree built
  against Manjaro libraries may crash `vlc-cache-gen` inside the AppDir (seen 2026-11-01); CI is the
  reference.

### deb, rpm, Arch (`extras/package/redesign/linux-packages.sh`)

`linux-packages.sh <tarball> <version> <out>` (nfpm from `get-nfpm.sh`, pinned v2.47.0 with sha256):

- Tree in `/opt/vlc-juxtopposed`, command `/usr/bin/vlc-juxtopposed` (symlink), menu entry
  `vlc-juxtopposed.desktop` (the tree's mime types, "VLC (juxtopposed)"), icons in hicolor.
- Dependencies: deb by package name, rpm by soname (`libGL.so.1()(64bit)`, works on Fedora and
  openSUSE), Arch by package name. They cover what the tree leaves to the system (linuxdeploy's
  exclude list: GL/EGL, X11/xcb, Wayland client, fontconfig/freetype/harfbuzz/fribidi, ALSA, zlib,
  libgpg-error, gmp, com_err, libusb, xcb-dri3). pipewire is recommended (audio plugins only).
- `RPM_SIGNING_KEY_FILE` signs the rpm (release only).
- Output: `VLC-juxtopposed-amd64.deb`, `VLC-juxtopposed-x86_64.rpm`, `vlc-juxtopposed-<v>-1-x86_64.pkg.tar.zst`.

Install test (`install-test` job): Ubuntu 24.04, Debian 13, Fedora, openSUSE Tumbleweed, Arch; runs
VLC as `nobody` via `setpriv`; checks `--version`, the Qt interface in `--list`, no stale plugin cache,
no "not found" in `ldd` of the core, the Qt plugin, the Wayland/X11 video outputs and Qt platforms.

### Repositories

Built by the release workflow for full releases (06): apt (reprepro, `stable main`,
`extras/package/redesign/apt-distributions`) and pacman (`make-arch-repo.sh`, repo `vlc-juxtopposed`,
`/arch/x86_64`), with `KEY.gpg`, on https://sabaoongfx.github.io/vlc-qt-redesign-fork/ (Pages, build
type "workflow"; the `github-pages` environment allows `master` and `v*` tags).

## Windows

Cross-built in the VideoLAN Windows image (`extras/package/win32/build.sh -r` runs `make package-win32`:
zip, 7z, NSIS exe). Gotchas: restore the contrib cache with one timestamp for every file (else make
rebuilds everything); delete `contrib/contrib-win64/.cargo-c` after a restore; the contrib Qt has no
`Canvas` and no `QtQuick.Shapes` (a single `Canvas` stopped the whole player from loading). Diagnose a
missing UI with `vlc.exe -vv --file-logging --logfile=%TEMP%\vlc.log` and look for "is not a type".

## macOS

`redesign-macos.yml` with `extras/package/redesign/macos-build.sh` and `macapp.sh` (bundle, codesign
ad-hoc, plugin cache after signing, dmg `VLC-juxtopposed-arm64.dmg`). Not notarized. Status and open
decisions: `redesign/MACOS-PLAN.md`.
