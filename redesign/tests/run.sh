#!/bin/bash
# Run the redesign scenarios and the checks.  usage: run.sh [scenario-name-regex]
# Needs a built tree (../../build), kwin_wayland, spectacle, xdotool, ImageMagick, python3-gi (Atspi).
T=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$T/../.." && pwd)
export VLC=${VLC:-$R/build/vlc}
export OUT=${OUT:-$T/out/run}
export FIX=${FIX:-$T/out/fixtures}
FILTER=${1:-.}
mkdir -p "$OUT"
"$T/fixtures.sh" >/dev/null
# fresh copy of the library profile per run, so scenes do not leak state into each other
rm -rf "$OUT"/*.png "$OUT"/*.log "$OUT"/*.at "$OUT"/*.geom "$OUT"/*.tree "$OUT"/profiles "$OUT"/profile
grep -v '^\s*#' "$T/scenarios.txt" | grep -v '^\s*$' | while IFS='|' read -r name theme kind media actions; do
    name=$(echo $name); [[ "$name" =~ $FILTER ]] || continue
    media=$(echo $media | sed "s|@|$FIX/|g")
    unset PROFILE
    if [ "$(echo $kind)" = ml ]; then
        # a fresh copy per scene (the nested session can keep writing to the previous one for a moment)
        P=$OUT/profiles/$name; mkdir -p "$OUT/profiles"; cp -a "$FIX/profile" "$P"
        sed -i '/^\[ControlbarProfileModel\]/,/^\[/{/^\[ControlbarProfileModel\]/d;/^\[/!d}' "$P/config/vlc/vlc-qt-interface.conf" 2>/dev/null
        export PROFILE=$P
    fi
    echo "scene $name"
    NAME=$name THEME=$(echo $theme) MEDIA="$media" ACTIONS="$actions" "$T/lib/scene.sh"
done
python3 "$T/check.py" "$OUT"
