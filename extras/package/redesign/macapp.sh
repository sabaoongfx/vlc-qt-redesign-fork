#!/bin/bash
# Builds "VLC juxtopposed.app" and VLC-juxtopposed-arm64.dmg from an installed VLC tree
# (redesign-macos.yml; the macOS counterpart of appimage.sh).
# usage: macapp.sh <installed prefix> <vlc source dir> <qmake6> <output dir>
# The layout is upstream's VLC.app (extras/package/macosx/package.mak), which libvlccore finds in a
# bundle (src/darwin/dirs.m): libvlc, libvlccore and the plugins (flat) in Contents/Frameworks, data in
# Contents/Resources/share. macdeployqt adds the Qt frameworks, the cocoa platform plugin and the QML
# modules. Ad-hoc signed: arm64 runs no code with an invalid signature, and every install_name_tool
# change invalidates the linker's.
set -euo pipefail
PREFIX=$(cd "$1" && pwd); SRC=$(cd "$2" && pwd); QMAKE6=$3
mkdir -p "$4"; OUT=$(cd "$4" && pwd)
QT_BINS=$("$QMAKE6" -query QT_INSTALL_BINS)
QT_LIBS=$("$QMAKE6" -query QT_INSTALL_LIBS)
NAME="VLC juxtopposed"
DMG=VLC-juxtopposed-arm64
WORK=$(mktemp -d)
APP=$WORK/$NAME.app
C=$APP/Contents
# the bundle version from LIBVLC_VERSION_MAJOR/MINOR/REVISION (4.0.0; the release tag is the fork's own)
v() { sed -n "s/^# *define LIBVLC_VERSION_$1 *(\([0-9]*\)).*/\1/p" "$PREFIX/include/vlc/libvlc_version.h"; }
VERSION=$(v MAJOR).$(v MINOR).$(v REVISION)
[ "$VERSION" != ".." ] || VERSION=4.0.0

mkdir -p "$C/MacOS" "$C/Frameworks/plugins" "$C/Resources/share"

# binaries, looking for their libraries in Contents/Frameworks
cp "$PREFIX/bin/vlc" "$C/MacOS/VLC"
install_name_tool -rpath "$PREFIX/lib" "@executable_path/../Frameworks/" "$C/MacOS/VLC"
# helpers live next to the executable in a bundle (VLC_PKG_LIBEXEC_DIR, src/darwin/dirs.m); without
# vlc-qt-check the Qt interface declines to open and VLC falls back to skins2
for x in vlc-preparser vlc-qt-check; do
    f=$(find "$PREFIX/libexec" "$PREFIX/lib" -name "$x" -type f 2>/dev/null | head -1)
    [ -n "$f" ] || continue
    cp "$f" "$C/MacOS/"
    install_name_tool -rpath "$PREFIX/lib" "@executable_path/../Frameworks/" "$C/MacOS/$x" 2>/dev/null || \
        install_name_tool -add_rpath "@executable_path/../Frameworks/" "$C/MacOS/$x"
done

cp -a "$PREFIX"/lib/libvlc*.dylib "$C/Frameworks/"
# flat, like upstream (plugins one directory deeper, access/rtp/, end up next to the others)
find "$PREFIX/lib/vlc/plugins" -maxdepth 3 -name 'lib*_plugin.dylib' -exec cp -a {} "$C/Frameworks/plugins/" \;
[ -d "$PREFIX/lib/vlc/lua" ] && cp -R "$PREFIX/lib/vlc/lua" "$C/Frameworks/"
[ -d "$PREFIX/libexec/vlc/lua" ] && cp -R "$PREFIX/libexec/vlc/lua" "$C/Frameworks/"
# pkgdatadir (share/vlc) is Resources/share in a bundle
cp -R "$PREFIX/share/vlc/." "$C/Resources/share/"
cp "$SRC/modules/gui/macosx/Resources/App-Icons/VLC.icns" "$C/Resources/VLC.icns"
printf "APPLVLC#" > "$C/PkgInfo"

# own bundle id, so it sits next to VideoLAN's VLC; opens any audio or video file (Open With)
cat > "$C/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>English</string>
	<key>CFBundleExecutable</key><string>VLC</string>
	<key>CFBundleIconFile</key><string>VLC</string>
	<key>CFBundleIdentifier</key><string>dev.sabaoon.vlc-juxtopposed</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>$NAME</string>
	<key>CFBundleDisplayName</key><string>$NAME</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleSignature</key><string>VLC#</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$VERSION</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.entertainment</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSPrincipalClass</key><string>NSApplication</string>
	<key>NSHumanReadableCopyright</key><string>Unofficial build of VLC (GPL), not affiliated with VideoLAN</string>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key><string>Media file</string>
			<key>CFBundleTypeRole</key><string>Viewer</string>
			<key>LSHandlerRank</key><string>Alternate</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>public.movie</string>
				<string>public.audio</string>
				<string>public.audiovisual-content</string>
				<string>public.m3u-playlist</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
EOF
plutil -lint "$C/Info.plist"

# Qt: frameworks, platform plugin, QML modules. The Qt interface plugin is dlopen'ed, so it is
# named with -executable for macdeployqt to see what it links.
QTPLUGIN=$C/Frameworks/plugins/libqt_plugin.dylib
[ -f "$QTPLUGIN" ] || { echo "libqt_plugin.dylib missing"; exit 1; }
[ -f "$C/MacOS/vlc-qt-check" ] || { echo "vlc-qt-check missing"; exit 1; }
"$QT_BINS/macdeployqt" "$APP" \
    -qmldir="$SRC/modules/gui/qt" \
    -executable="$QTPLUGIN"     -executable="$C/MacOS/vlc-qt-check" \
    -libpath="$QT_LIBS" \
    -libpath="$C/Frameworks" \
    -verbose=1
# macdeployqt links Qt into libqt_plugin through @loader_path/../ (Frameworks)
otool -L "$QTPLUGIN" | head -20
# Qt's SQL drivers (ODBC, PostgreSQL, Mimer) link libraries nobody has; VLC uses none of them
rm -rf "$C/PlugIns/sqldrivers"

# ad-hoc signature, inside out like extras/package/macosx/codesign.sh. Contents/Frameworks counts as
# code, so every file there outside a .framework is signed, data too (plugins.dat, the lua scripts);
# elsewhere the Mach-O files (Qt plugins, QML module libraries). The main executable comes with the bundle.
find "$C/Frameworks" -type f -not -path '*.framework/*' -print0 | xargs -0 -n 50 codesign --force -s -
# the plugin cache records each plugin's size and time, so it comes after their signatures (it is
# signed itself right after); vlc-cache-gen has no rpath, so libvlc comes from DYLD_LIBRARY_PATH
CACHEGEN=$(find "$PREFIX/libexec" "$PREFIX/lib" -name vlc-cache-gen -type f 2>/dev/null | head -1)
DYLD_LIBRARY_PATH="$C/Frameworks" VLC_LIB_PATH="$C/Frameworks" "$CACHEGEN" "$C/Frameworks/plugins"
codesign --force -s - "$C/Frameworks/plugins/plugins.dat"
find "$C" -type f \( -name '*.dylib' -o -perm -u+x \) -not -path "$C/Frameworks/*" -not -path "$C/MacOS/VLC" -print0 |
    while IFS= read -r -d '' f; do
        if file -b "$f" | grep -q Mach-O; then codesign --force -s - "$f"; fi
    done
find "$C/Frameworks" -maxdepth 1 -name '*.framework' -exec codesign --force -s - {} \;
codesign --force -s - "$APP"
codesign --verify --deep --strict "$APP"

rm -f "$OUT/$DMG.dmg"
mkdir "$WORK/dmg"
mv "$APP" "$WORK/dmg/"
ln -s /Applications "$WORK/dmg/Applications"
hdiutil create -srcfolder "$WORK/dmg" -volname "$NAME" -format UDBZ -fs HFS+ -o "$OUT/$DMG.dmg"
# also keep the .app next to the dmg for the CI smoke test and screenshots
ditto "$WORK/dmg/$NAME.app" "$OUT/$NAME.app"
rm -rf "$WORK"
ls -la "$OUT"
