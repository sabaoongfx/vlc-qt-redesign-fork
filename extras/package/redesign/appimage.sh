#!/bin/bash
# Builds the redesign's AppImage and tarball from an installed VLC tree (redesign-linux-packages.yml;
# also runs locally against the dev build's install/ to test the packaging).
# usage: appimage.sh <installed prefix> <vlc source dir> <qmake6> <output dir>
#   the prefix is relocated into AppDir/usr: VLC finds its plugins and data next to libvlccore.
# needs: linuxdeploy-x86_64.AppImage and linuxdeploy-plugin-qt-x86_64.AppImage on PATH or in $TOOLS
set -euo pipefail
PREFIX=$(realpath "$1"); SRC=$(realpath "$2"); QMAKE6=$3; OUT=$(realpath -m "$4")
TOOLS=${TOOLS:-$PWD}
WORK=$(mktemp -d)
A=$WORK/AppDir
NAME=VLC-juxtopposed-x86_64

mkdir -p "$A/usr" "$OUT"
cp -a "$PREFIX/." "$A/usr/"
# development files are not needed to run it
rm -rf "$A/usr/include" "$A/usr/lib/pkgconfig"
find "$A/usr" \( -name '*.la' -o -name '*.a' \) -delete

# one menu entry, with the release name, running the AppImage's own binary
D=$A/usr/share/applications/vlc.desktop
find "$A/usr/share/applications" -name '*.desktop' ! -name vlc.desktop -delete
sed -i -e 's/^Name=.*/Name=VLC (juxtopposed)/' -e '/^Name\[/d' \
    -e 's|^Exec=[^ ]*/vlc |Exec=vlc |' -e '/^TryExec=/d' "$D"

# a /usr build has no rpath to its own libraries (libvlc, libvlccore, the plugin helpers), so
# linuxdeploy could not find them ("Could not find dependency: libvlc.so.12"): point every VLC file
# at them relative to itself. (LD_LIBRARY_PATH into the AppDir is no good: qmake then loads the Qt
# copied there and reports the wrong QML path.) patchelf comes from linuxdeploy's own AppImage.
( cd "$WORK" && "$TOOLS/linuxdeploy-x86_64.AppImage" --appimage-extract usr/bin/patchelf >/dev/null )
PATCHELF=$WORK/squashfs-root/usr/bin/patchelf
setrpath() { # setrpath <rpath> <files...>: only ELF files
    local r=$1; shift
    for f in "$@"; do [ -f "$f" ] && head -c4 "$f" | grep -q ELF && "$PATCHELF" --set-rpath "$r" "$f"; done
    return 0
}
setrpath '$ORIGIN/../lib' "$A"/usr/bin/*
setrpath '$ORIGIN/../../lib' "$A"/usr/libexec/vlc/*
setrpath '$ORIGIN' "$A"/usr/lib/*.so*
setrpath '$ORIGIN/..:$ORIGIN' "$A"/usr/lib/vlc/*.so*
setrpath '$ORIGIN/../../..:$ORIGIN/../..' "$A"/usr/lib/vlc/plugins/*/*.so

# the VLC plugins and their helper libraries are loaded at run time: deploy their dependencies too
DEPS=()
for d in "$A"/usr/lib/vlc "$A"/usr/lib/vlc/plugins/*/; do DEPS+=(--deploy-deps-only "$d"); done

export QMAKE=$QMAKE6
export QML_SOURCES_PATHS=$SRC/modules/gui/qt
# Qt 6.10+ has a single Wayland platform plugin
export EXTRA_PLATFORM_PLUGINS="libqwayland.so"
export EXTRA_QT_PLUGINS="wayland-shell-integration;wayland-decoration-client;wayland-graphics-integration-client;iconengines;imageformats;xcbglintegrations"
export LDAI_OUTPUT=$OUT/$NAME.AppImage
export PATH=$TOOLS:$PATH
export APPIMAGE_EXTRACT_AND_RUN=1  # no FUSE needed for the tools themselves
# linuxdeploy's own strip cannot read newer binaries (.relr.dyn sections) and stops the build
export NO_STRIP=1
cd "$WORK"
linuxdeploy-x86_64.AppImage --appdir "$A" \
    -e "$A/usr/bin/vlc" -d "$D" \
    -i "$A/usr/share/icons/hicolor/256x256/apps/vlc.png" \
    "${DEPS[@]}" --plugin qt
# strip with the system's binutils (linuxdeploy's is off, see NO_STRIP): VLC's plugins keep their
# debug symbols otherwise (~380 MB)
find "$A/usr" -type f \( -name '*.so*' -o -perm -u+x \) -exec sh -c \
    'for f; do head -c4 "$f" | grep -q "ELF" && strip --strip-unneeded "$f" 2>/dev/null; done; true' sh {} +
# plugin cache for the relocated tree, made after linuxdeploy rewrote the plugins' library paths
# (made before, every plugin was "stale" and rescanned at each start)
"$A/usr/libexec/vlc/vlc-cache-gen" "$A/usr/lib/vlc/plugins"
linuxdeploy-x86_64.AppImage --appdir "$A" --output appimage

# the same tree as a tarball: extract, then run ./vlc-juxtopposed
mv "$A" "$WORK/$NAME"
ln -s AppRun "$WORK/$NAME/vlc-juxtopposed"
tar -C "$WORK" -czf "$OUT/$NAME.tar.gz" "$NAME"
rm -rf "$WORK"
ls -la "$OUT"
