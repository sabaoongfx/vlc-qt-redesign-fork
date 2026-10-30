# macOS plan (written 2026-10-30)

Status: M1 started 2026-10-30 (`dcddb4f`): `.github/workflows/redesign-macos.yml` + `extras/package/redesign/macos-build.sh`
(steps tools / contribs / vlc; triplet `aarch64-apple-darwin19` like upstream's CI; minimum macOS 13; `--enable-qt`,
because configure turns Qt off on darwin by default; no Rust contribs, rustc is not on the reset PATH). Decisions taken
with the recommendations below (ad-hoc signing, arm64 only, native title bar, CI only, macOS 13).

Goal: ship VLC (juxtopposed) for macOS with the same Qt/QML interface as Windows and Linux, next to the
Windows installer and the AppImage. Not the Cocoa `VLC.app` (`modules/gui/macosx`), which stays out of scope.

## Where things stand

Upstream VLC 4 already supports its Qt interface on macOS, so this is mostly build and packaging work:

- `modules/gui/qt/qt.cpp:636`: the Qt main loop runs on the Cocoa main thread (`CFRunLoopPerformBlock`);
  `bin/darwinvlc.m` stops the run loop when Qt quits.
- `maininterface/compositor_platform.cpp`: the `platform` compositor gives the video an NSView
  (`VLC_WINDOW_TYPE_NSOBJECT`); it is the only compositor on macOS (Windows also has dcomp/win7, Linux x11/wayland).
- `Makefile.am`: shaders are also compiled for Metal (`QSB_PARAMS += --msl=12`), the plugin links Cocoa,
  moc gets `-DQ_OS_MAC`. `meson.build` passes the Qt framework path to moc.
- The redesign itself added no Windows- or Linux-only code (the `_WIN32`/`__linux__` blocks in its files are upstream's).

Missing:

- Qt: VideoLAN does not build Qt for macOS (`contrib/src/qt/rules.mak`: `#PKGS += qt`). Use a prebuilt Qt from
  `install-qt-action`, like `redesign-linux-packages.yml`. `configure` finds Qt through qmake (`QMAKE6`), so a
  framework build without pkg-config files works.
- Packaging: `extras/package/macosx/build.sh` builds the Cocoa app through Xcode; nothing bundles a Qt build.
- CI: no redesign workflow runs on macOS; upstream's GitLab macOS jobs configure without Qt.

## Phases

### M1. It compiles in CI

New workflow `.github/workflows/redesign-macos.yml` on `macos-15` (arm64), on push to `redesign` like the others.

- Contribs for `aarch64-apple-darwin`: VideoLAN's prebuilt tarball (`make prebuilt`), else build from source and
  cache it. Reuse the Windows lessons: touch restored files with one timestamp, immutable cache key, save the
  cache right after the contrib build. `medialibrary` must be in it (the library pages need it).
- Qt 6.10 for macOS from `install-qt-action` (modules: qtshadertools, qtsvg; qtdeclarative is in the base).
- `extras/package/macosx/configure.sh --disable-macosx --with-macosx-sdk=... ` (Qt as the only, default interface;
  `configure.sh` already disables xcb, pulse and X), `make`.
- Done when it links and `vlc --list` shows `qt`.

### M2. An app that starts

New `extras/package/redesign/macapp.sh <prefix> <src> <qmake6> <out>`, the counterpart of `appimage.sh`:

- `VLC juxtopposed.app/Contents/`: `MacOS/vlc` (the darwinvlc binary), `Frameworks/` or `lib/` (libvlc,
  libvlccore), `plugins/`, `Info.plist` (own bundle id so it sits next to VideoLAN's VLC, document types,
  usage descriptions), `Resources/` with an `.icns`.
- `macdeployqt` with `-qmldir=modules/gui/qt` (Qt frameworks, QML modules, the cocoa platform plugin); install
  names and rpaths of the VLC plugins fixed with `install_name_tool` (plugins one directory deeper need their own
  relative path, as in the AppImage).
- Plugin cache made after the plugins are rewritten (else every plugin is "stale", as on Linux).
- Ad-hoc signature for the whole bundle (`codesign --force --deep -s -`): arm64 refuses code with an invalid
  signature, and `install_name_tool` invalidates the linker's.
- `hdiutil create` -> `VLC-juxtopposed-arm64.dmg` (fixed name, no version).

### M3. See it in CI

- Launch the app on the runner, `screencapture -x`, clicks with `cliclick` (brew). Clicks may need the
  Accessibility permission the runner does not grant: start with home and player shots plus the
  `--verbose=1` log and a "QML warnings" step like the Linux workflow.
- Likely problems: Metal/RHI (`DualKawaseBlur`, the stage corner rings), font metrics, 2x HiDPI sizes.
- Upload artifacts `vlc-macos-arm64` (the dmg) and `macos-screenshots`.

### M4. macOS polish

- Window controls: `qt-titlebar` defaults to false (client-side decoration), so the redesign's window buttons sit on
  the right; macOS users expect the traffic lights on the left. Options: the native title bar on macOS, or
  our own buttons on the left.
- Shortcut hints: about 56 QML strings say "Ctrl+...". Qt maps Ctrl to Cmd for the shortcut itself, the text does
  not change: build hints with `QKeySequence::NativeText` (shows the Cmd symbol). Check the hotkey hints in menus
  (`hotkeyHint()`) show Cmd too.
- Global menu bar: the library top bar has no menu button any more. A native `QMenuBar` on macOS (Media,
  Playback, Audio, Video, View, Window, Help) brings View/Tools/Help back where Mac users look for them.
- Cmd+Q, Cmd+W, Cmd+, (Settings), Cmd+M (minimise; VLC uses Ctrl+M for Messages: decide).
- Files opened from Finder or dropped on the Dock icon (`QFileOpenEvent`; check what upstream already handles),
  Dock menu.
- Widgets dialogs (Settings, Open Media, message boxes) under the macOS style: check the redesign stylesheet and
  palette still apply (they were written against Fusion and the Windows style).
- No Windows acrylic blur on macOS; the sidebar is a plain card already, check the top bar fallback.

### M5. Release

- `redesign-release.yml` waits for the macOS run too and publishes `VLC-juxtopposed-arm64.dmg` with SHA256SUMS
  and an attestation.
- Website (`vlc-web`): a macOS download button and a no-JavaScript fallback link
  (`releases/latest/download/VLC-juxtopposed-arm64.dmg`); bump the `?v=N` of `main.js`/`style.css`.
- Release notes: how to open an unsigned app (below).
- Update CLAUDE.md and `redesign/remaining/index.html`.

## Decisions (open, recommendation first)

1. Signing: ship unsigned (ad-hoc) first, like the unsigned Windows build. Sequoia then says the app "cannot be
   verified" / "is damaged"; users open it with System Settings > Privacy & Security > Open Anyway, or
   `xattr -dr com.apple.quarantine "/Applications/VLC juxtopposed.app"`. Notarization needs the Apple Developer
   Program ($99/year), a Developer ID certificate and `notarytool` in the workflow.
2. Architectures: Apple Silicon only first. Intel later as a second build (`macos-13` runners are being retired;
   cross-building x86_64 on arm64 works with the contribs) or one universal app made with `lipo`.
3. Window controls: the native title bar on macOS (least work, matches the platform).
4. Testing: CI only unless a Mac is available. Without one, drag and drop, menus, Finder integration and real
   playback stay unchecked, as with the Windows build.
5. Minimum macOS: what Qt 6.10 supports (macOS 13), not VLC's 10.13.

## Risks

- VideoLAN's prebuilt arm64 contribs may be missing (the Windows URL was a 404): then the first contrib build
  takes 1-2 hours, then it is cached. macOS runner minutes cost 10x Linux minutes on a private repo; they are
  free on a public one.
- `macdeployqt` and VLC's plugin layout: plugins outside `Contents/PlugIns` need their own rpaths and a valid
  signature each; the first app will probably fail to start until these are right.
- The Qt and QML module set: the prebuilt Qt has `Canvas` and `QtQuick.Shapes`, the static Windows Qt does not;
  keep the "no Canvas" rule so one QML tree works everywhere.
