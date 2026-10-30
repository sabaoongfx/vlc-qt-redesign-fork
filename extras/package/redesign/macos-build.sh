#!/bin/bash
# Builds VLC (juxtopposed) for macOS with the Qt interface: no Cocoa interface and no VLC.app from
# extras/package/macosx/build.sh (that one is the Cocoa app). Run from the source root, one step at a
# time so CI can cache what the earlier steps made:
#   macos-build.sh tools                 extras/tools (autoconf, meson, pkg-config...)
#   macos-build.sh contribs              contrib/contrib-<host> -> contrib/<host> (from source: VideoLAN
#                                        has no prebuilt macOS contribs, the URL 404s)
#   macos-build.sh vlc <qmake6>          build/ -> build/install (prefix), Qt found through qmake6
# VLC_CCACHE_BINS_PATH (a dir with cc/c++ links to ccache) is used by the vlc step if set.
set -e

STEP=$1
SRC=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$SRC"

. "$SRC/extras/package/macosx/env.build.sh" none

# what Qt 6.10 supports, not VLC's 10.13
MINIMAL_OSX_VERSION=13.0
# a fixed triplet like upstream's CI, so the contrib cache does not depend on the runner's kernel
export VLC_FORCE_KERNELVERSION=${VLC_FORCE_KERNELVERSION:-19}
SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export SDKROOT
BUILD_TRIPLET=$(vlcGetBuildTriplet)
HOST_TRIPLET=$(vlcGetHostTriplet)
JOBS=$(($(getconf NPROCESSORS_ONLN) + 1))

echo "macOS $STEP: host $HOST_TRIPLET, SDK $SDKROOT, minimum macOS $MINIMAL_OSX_VERSION, $JOBS jobs"

case "$STEP" in
tools)
    vlcSetBaseEnvironment
    python3 --version
    cd extras/tools
    ./bootstrap
    make -j"$JOBS"
    ;;

contribs)
    vlcSetBaseEnvironment
    vlcSetSymbolEnvironment
    vlcSetContribEnvironment "$MINIMAL_OSX_VERSION"
    mkdir -p "contrib/contrib-$HOST_TRIPLET"
    cd "contrib/contrib-$HOST_TRIPLET"
    ../bootstrap --build="$BUILD_TRIPLET" --host="$HOST_TRIPLET" --enable-sections
    make list
    make -j"$JOBS" fetch
    make -j"$JOBS" -k || make -j1
    # the library pages need it
    [ -e "../$HOST_TRIPLET/lib/pkgconfig/medialibrary.pc" ] || { echo "medialibrary contrib missing"; exit 1; }
    ;;

vlc)
    QMAKE6=$2
    [ -x "$QMAKE6" ] || { echo "usage: $0 vlc <qmake6>"; exit 1; }
    vlcSetBaseEnvironment
    vlcUnsetContribEnvironment
    vlcSetLibVLCEnvironment
    export CFLAGS CXXFLAGS
    [ -e configure ] || ./bootstrap
    mkdir -p build
    cd build
    if [ ../configure -nt Makefile ]; then
        # configure.sh passes --enable-macosx and --prefix=/ first; the later options win.
        # Qt is off by default on darwin, so it is asked for.
        ../extras/package/macosx/configure.sh \
            --build="$BUILD_TRIPLET" \
            --host="$HOST_TRIPLET" \
            --with-contrib="../contrib/$HOST_TRIPLET" \
            --with-macosx-version-min="$MINIMAL_OSX_VERSION" \
            --with-macosx-sdk="$SDKROOT" \
            --prefix="$PWD/install" \
            --disable-macosx \
            --disable-sparkle \
            --disable-nls \
            --enable-qt \
            QMAKE6="$QMAKE6"
    fi
    grep -E "^(HAVE_QT|ENABLE_QT|QT_LIBS)" config.log | head || true
    make -j"$JOBS"
    make install
    ;;

*)
    echo "usage: $0 tools|contribs|vlc <qmake6>"
    exit 1
    ;;
esac
