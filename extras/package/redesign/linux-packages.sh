#!/bin/bash
# Builds the redesign's .deb, .rpm and Arch package from the Linux tarball (appimage.sh makes it).
# usage: linux-packages.sh <VLC-juxtopposed-x86_64.tar.gz> <version, e.g. 0.1.6> <output dir>
#   needs nfpm on PATH (or $NFPM). With $RPM_SIGNING_KEY_FILE (an armored private key) the rpm is
#   signed; the deb and Arch packages are signed by their repositories (linux-repos.sh).
# The tarball is a self-contained tree with $ORIGIN rpaths; it is installed as /opt/vlc-juxtopposed
# with a vlc-juxtopposed command, menu entry and icons, so it never touches the distribution's VLC.
set -euo pipefail
TARBALL=$(realpath "$1"); VERSION=$2; OUT=$(realpath -m "$3")
NFPM=${NFPM:-nfpm}
HERE=$(dirname "$(realpath "$0")")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
S=$WORK/stage
mkdir -p "$S/opt" "$S/applications" "$OUT"

tar xzf "$TARBALL" -C "$S/opt"
mv "$S/opt/VLC-juxtopposed-x86_64" "$S/opt/vlc-juxtopposed"
T=$S/opt/vlc-juxtopposed
# the AppImage's own entry points (AppRun, .DirIcon, vlc.desktop at the root) are not needed here
rm -f "$T/AppRun" "$T/.DirIcon" "$T/vlc.desktop" "$T/vlc.png" "$T/vlc-juxtopposed"
[ -x "$T/usr/bin/vlc" ] || { echo "no usr/bin/vlc in $TARBALL" >&2; exit 1; }

# menu entry: the tree's vlc.desktop (mime types, translated comments) under its own name
sed -e 's|^Exec=.*|Exec=vlc-juxtopposed --started-from-file %U|' -e '/^TryExec=/d' \
    -e 's|^Icon=.*|Icon=vlc-juxtopposed|' -e 's|^Name=.*|Name=VLC (juxtopposed)|' -e '/^Name\[/d' \
    "$T/usr/share/applications/vlc.desktop" > "$S/applications/vlc-juxtopposed.desktop"

# icons: every hicolor size of vlc.png/svg, renamed
ICONS=""
for f in "$T"/usr/share/icons/hicolor/*/apps/vlc.png "$T"/usr/share/icons/hicolor/*/apps/vlc.svg; do
    [ -f "$f" ] || continue
    size=$(basename "$(dirname "$(dirname "$f")")")
    ext=${f##*.}
    ICONS+="  - src: $f
    dst: /usr/share/icons/hicolor/$size/apps/vlc-juxtopposed.$ext
    file_info: {mode: 0644}
"
done

SIGN=""
if [ -n "${RPM_SIGNING_KEY_FILE:-}" ]; then
    SIGN="rpm:
  signature:
    key_file: $RPM_SIGNING_KEY_FILE
"
fi

cat > "$WORK/nfpm.yaml" <<EOF
name: vlc-juxtopposed
arch: amd64
platform: linux
version: $VERSION
release: 1
section: video
priority: optional
maintainer: Sabaoon <sabaoongfx@users.noreply.github.com>
vendor: Sabaoon (unofficial, not VideoLAN)
homepage: https://vlc.sabaoon.dev
license: GPL-2.0-or-later
description: |-
  VLC media player with Juxtopposed's redesigned interface
  An unofficial build of VLC 4 with the redesigned Qt interface, installed in
  /opt/vlc-juxtopposed next to the distribution's VLC. Not made or endorsed by VideoLAN.
contents:
  - src: $T
    dst: /opt/vlc-juxtopposed
    type: tree
  - src: /opt/vlc-juxtopposed/usr/bin/vlc
    dst: /usr/bin/vlc-juxtopposed
    type: symlink
  - src: $S/applications/vlc-juxtopposed.desktop
    dst: /usr/share/applications/vlc-juxtopposed.desktop
    file_info: {mode: 0644}
$ICONS
overrides:
  deb:
    depends:
      - libc6 (>= 2.39)
      - libstdc++6
      - libgl1
      - libegl1
      - libgbm1
      - libdrm2
      - libfontconfig1
      - libfreetype6
      - libharfbuzz0b
      - libfribidi0
      - libx11-6
      - libx11-xcb1
      - libxcb1
      - libwayland-client0
      - libasound2t64 | libasound2
      - zlib1g
  rpm:
    # sonames, so the same rpm resolves on Fedora and openSUSE (their package names differ)
    depends:
      - libGL.so.1()(64bit)
      - libEGL.so.1()(64bit)
      - libgbm.so.1()(64bit)
      - libdrm.so.2()(64bit)
      - libfontconfig.so.1()(64bit)
      - libfreetype.so.6()(64bit)
      - libharfbuzz.so.0()(64bit)
      - libfribidi.so.0()(64bit)
      - libX11.so.6()(64bit)
      - libX11-xcb.so.1()(64bit)
      - libxcb.so.1()(64bit)
      - libwayland-client.so.0()(64bit)
      - libasound.so.2()(64bit)
      - libz.so.1()(64bit)
  archlinux:
    depends:
      - glibc
      - gcc-libs
      - libglvnd
      - mesa
      - libdrm
      - fontconfig
      - freetype2
      - harfbuzz
      - fribidi
      - libx11
      - libxcb
      - wayland
      - alsa-lib
      - zlib
$SIGN
EOF

cd "$WORK"
"$NFPM" package -f nfpm.yaml -p deb -t "$OUT/VLC-juxtopposed-amd64.deb"
"$NFPM" package -f nfpm.yaml -p rpm -t "$OUT/VLC-juxtopposed-x86_64.rpm"
"$NFPM" package -f nfpm.yaml -p archlinux -t "$OUT/vlc-juxtopposed-$VERSION-1-x86_64.pkg.tar.zst"
ls -l "$OUT"
