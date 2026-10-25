#!/bin/bash
# Run one scene in a headless nested KWin. Env: NAME THEME MEDIA ACTIONS OUT [PROFILE] [RES_W RES_H] [QPA] [WIZ]
L=$(cd "$(dirname "$0")" && pwd)
export LIB=$L
if [ -n "$PROFILE" ]; then export CFG=$PROFILE/config; mkdir -p "$CFG"; else export CFG=$(mktemp -d -p "$OUT" cfg.XXXX); fi
export XDG_DATA_HOME=${PROFILE:+$PROFILE/data}; XDG_DATA_HOME=${XDG_DATA_HOME:-$CFG/data}; mkdir -p "$XDG_DATA_HOME"
export XDG_CONFIG_HOME=$CFG
sed "s/__W__/${RES_W:-1920}/;s/__H__/${RES_H:-1080}/" "$L/kwinrulesrc" > "$CFG/kwinrulesrc"
cp "$L/kwinrc.seed" "$CFG/kwinrc"
env -u WAYLAND_DISPLAY -u DISPLAY -u XAUTHORITY timeout ${TIMEOUT:-120} dbus-run-session kwin_wayland --virtual --xwayland \
    --width ${RES_W:-1920} --height ${RES_H:-1080} --socket wl-vlc-$NAME --exit-with-session "$L/inner.sh" >/dev/null 2>&1
[ -z "$PROFILE" ] && rm -rf "$CFG" 2>/dev/null
exit 0
