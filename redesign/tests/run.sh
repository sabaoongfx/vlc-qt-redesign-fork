#!/bin/bash
# Run the redesign scenarios and the checks.  usage: run.sh [scenario-name-regex]
# Needs a built tree (../../build), kwin_wayland, spectacle, xdotool, ImageMagick, python3-gi (Atspi).
T=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$T/../.." && pwd)
export VLC=${VLC:-$R/build/vlc}
export OUT=${OUT:-$T/out/run}
export FIX=${FIX:-$T/out/fixtures}
FILTER=${1:-.}
# no logind session (e.g. over ssh): the nested kwin only needs a private runtime dir
if [ ! -d "$XDG_RUNTIME_DIR" ]; then export XDG_RUNTIME_DIR=$(mktemp -d -t vlc-xdg.XXXX); chmod 700 "$XDG_RUNTIME_DIR"; fi
# and no sound server then: an audio output error would show a toast over the scene
[ -S "$XDG_RUNTIME_DIR/pipewire-0" ] || [ -S "$XDG_RUNTIME_DIR/pulse/native" ] || export VLCARGS="--aout=adummy $VLCARGS"
mkdir -p "$OUT"
"$T/fixtures.sh" >/dev/null
# fresh copy of the library profile per run, so scenes do not leak state into each other
# the nested session's helpers can still be writing for a moment: retry
for i in 1 2 3 4 5; do rm -rf "$OUT"/*.png "$OUT"/*.log "$OUT"/*.at "$OUT"/*.geom "$OUT"/*.tree "$OUT"/profiles "$OUT"/profile 2>/dev/null && break; sleep 1; done
grep -v '^\s*#' "$T/scenarios.txt" | grep -v '^\s*$' | while IFS='|' read -r name theme kind media actions; do
    name=$(echo $name); [[ "$name" =~ $FILTER ]] || continue
    media=$(echo $media | sed "s|@|$FIX/|g")
    kind=$(echo $kind)
    # "same": keep the previous scene's profile (e.g. to get the resume prompt on a second launch)
    [ "$kind" = same ] || unset PROFILE
    # "fixture": the fixture profile itself (paths match its library database, e.g. for resume tests;
    # these scenes change it, keep them last)
    [ "$kind" = fixture ] && export PROFILE=$FIX/profile
    if [ "$kind" = ml ]; then
        # a fresh copy per scene (the nested session can keep writing to the previous one for a moment)
        mkdir -p "$OUT/profiles"; P=$(mktemp -d -p "$OUT/profiles" "$name.XXXX"); rmdir "$P"; cp -a "$FIX/profile" "$P"
        sed -i '/^\[ControlbarProfileModel\]/,/^\[/{/^\[ControlbarProfileModel\]/d;/^\[/!d}' "$P/config/vlc/vlc-qt-interface.conf" 2>/dev/null
        export PROFILE=$P
    fi
    # ~/ = the scene's library home (indexed media)
    [ -n "$PROFILE" ] && media=$(echo $media | sed "s|~/|$PROFILE/home/|g")
    echo "scene $name"
    NAME=$name THEME=$(echo $theme) MEDIA="$media" ACTIONS="$actions" "$T/lib/scene.sh"
done
python3 "$T/check.py" "$OUT"
