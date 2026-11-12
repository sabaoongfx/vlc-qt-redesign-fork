#!/bin/bash
# Runs inside the nested kwin session. Env: THEME NAME MEDIA ACTIONS OUT CFG
export QT_QPA_PLATFORM=${QPA:-xcb} QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1
# pin the desktop: an inherited non-KDE one (e.g. XFCE) makes Qt load the GTK theme and its ATK bridge,
# which registers a second, empty "vlc" accessible app
export XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 DESKTOP_SESSION=plasma
xdotool() { env -u WAYLAND_DISPLAY /usr/bin/xdotool "$@"; }
# spectacle as an X11 client hangs when there is no logind session: keep it on Wayland
spectacle() { QT_QPA_PLATFORM=wayland timeout 20 /usr/bin/spectacle "$@"; }
# Arch has the AT-SPI helpers in /usr/lib, Debian (CI) in /usr/libexec
ATLIB=/usr/lib; [ -x $ATLIB/at-spi-bus-launcher ] || ATLIB=/usr/libexec
$ATLIB/at-spi-bus-launcher --launch-immediately &
sleep 1
export AT_SPI_BUS_ADDRESS=$(busctl --user call org.a11y.Bus /org/a11y/bus org.a11y.Bus GetAddress | sed 's/^s "//;s/"$//')
$ATLIB/at-spi2-registryd --use-gnome-session=false >/dev/null 2>&1 &
sleep 0.5
mkdir -p "$CFG/vlc"
if [ -n "$PROFILE" ]; then export HOME=$PROFILE/home; ML=""; else ML=--no-media-library
export HOME=$CFG/home; mkdir -p "$HOME/Videos/Shows/The Wand/S01" "$HOME/Videos/Movies" "$HOME/Music/Albums" "$HOME/Desktop"; for e in 01 02 03 04 05 06; do ln -s "$FIX/sample.mp4" "$HOME/Videos/Shows/The Wand/S01/The_Wand_S01E$e.mp4"; done; ln -s "$FIX/sample.mp4" "$HOME/Videos/Movies/Sample Movie.mp4"
fi
Q="$CFG/vlc/vlc-qt-interface.conf"
# theme "-": keep the profile's own (a Settings test checks the theme it saved)
if [ "$THEME" = "-" ]; then :
elif grep -q '^color-scheme-index=' "$Q" 2>/dev/null; then sed -i "s/^color-scheme-index=.*/color-scheme-index=$THEME/" "$Q"; else printf '[MainWindow]\ncolor-scheme-index=%s\n' "$THEME" >> "$Q"; fi
# env:NAME=value actions are set for VLC only (e.g. Qt's own file dialog instead of the desktop's)
VENV=""; set -f; for a in $ACTIONS; do case "$a" in env:*) VENV="$VENV ${a#env:}" ;; esac; done; set +f
# start in the output folder: a scene that turns on "Save a log" makes VLC write vlc-log.txt into its working
# directory (it was the repository root)
cd "$OUT"
setsid env $VENV "$VLC" ${VLCARGS} $ML ${WIZ:---no-qt-privacy-ask} --no-qt-backdrop-blur $MEDIA > "$OUT/$NAME.log" 2>&1 &
VPID=$!
for i in $(seq 40); do W=$(xdotool search --onlyvisible --class vlc 2>/dev/null | tail -1); [ -n "$W" ] && break; sleep 0.25; done
sleep 1
sleep 2.5
xdotool mousemove 900 500; sleep 0.5; xdotool mousemove 905 505; sleep 0.3
set -f  # actions may contain * (prefix matches)
n=0
for a in $ACTIONS; do
  case "$a" in
    # every shot also lists the enabled controls on screen (at.py controls) for contrast.py; CONTRAST=0 skips it
    shotwin:*) f="$OUT/$NAME-${a#shotwin:}.png"; spectacle -b -n -f -o "$f" >/dev/null 2>&1
       [ "$CONTRAST" = 0 ] || "$LIB/at.py" controls > "${f%.png}.ctl" 2>/dev/null
       eval $(xdotool getactivewindow getwindowgeometry --shell 2>/dev/null)
       [ -n "$WIDTH" ] && magick "$f" -crop ${WIDTH}x${HEIGHT}+${X}+${Y} +repage "$f" && [ -f "${f%.png}.ctl" ] && sed -i "1i # offset $X $Y" "${f%.png}.ctl" ;;
    shot*) f="$OUT/$NAME-${a#shot:}.png"; spectacle -b -n -f -o "$f" >/dev/null 2>&1
       [ "$CONTRAST" = 0 ] || "$LIB/at.py" controls > "${f%.png}.ctl" 2>/dev/null ;;
    sleep:*) sleep ${a#sleep:} ;;
    term) kill -TERM -- -$VPID 2>/dev/null; for i in $(seq 40); do kill -0 $VPID 2>/dev/null || break; sleep 0.25; done ;;
    click:*) xy=${a#click:}; LXY=$xy; xdotool mousemove ${xy%,*} ${xy#*,} click 1 ;;
    rclick:*) xy=${a#rclick:}; xdotool mousemove ${xy%,*} ${xy#*,} click 3 ;;
    dclick:*) xy=${a#dclick:}; xdotool mousemove ${xy%,*} ${xy#*,} click --repeat 2 --delay 60 1 ;;
    move:*) xy=${a#move:}; LXY=$xy; xdotool mousemove ${xy%,*} ${xy#*,} ;;
    down:*) xy=${a#down:}; LXY=$xy; xdotool mousemove ${xy%,*} ${xy#*,} mousedown 1 ;;
    up) xdotool mouseup 1 ;;
    # ptr:<tag> a 96x96 shot around the last pointer position, pointer drawn (works for Wayland clients too, unlike cursor:)
    ptr:*) f="$OUT/$NAME-ptr-${a#ptr:}.png"; spectacle -b -n -f -p -o "$f" >/dev/null 2>&1
       X=${LXY%,*}; Y=${LXY#*,}  # the last click/move/down: xdotool cannot read the pointer over a Wayland window
       magick "$f" -crop 96x96+$((X > 32 ? X - 32 : 0))+$((Y > 32 ? Y - 32 : 0)) +repage "$f" ;;
    cursor:*) printf '%s\t%s\n' "${a#cursor:}" "$("$LIB/cursor.py" 2>&1)" >> "$OUT/$NAME.cursor" ;;
    resize:*) wh=${a#resize:}; W=$(xdotool search --onlyvisible --class vlc | head -1); xdotool windowmove $W 0 0 windowsize $W ${wh%,*} ${wh#*,} ;;
    type:*) xdotool type --delay 20 "${a#type:}" ;;
    key:*) xdotool key ${a#key:} ;;
    press:*) "$LIB/at.py" press "${a#press:}" >> "$OUT/$NAME.at" 2>&1 ;;
    setrow:*) "$LIB/at.py" setrow "${a#setrow:}" >> "$OUT/$NAME.at" 2>&1 ;;
    rows:*) "$LIB/at.py" rows > "$OUT/$NAME-${a#rows:}.rows" 2>/dev/null ;;
    tree) "$LIB/at.py" tree > "$OUT/$NAME.tree" 2>&1 ;;
    geom:*) "$LIB/at.py" geom > "$OUT/$NAME-${a#geom:}.geom" 2>/dev/null ;;
    audit:*) "$LIB/at.py" audit > "$OUT/$NAME-${a#audit:}.a11y" 2>/dev/null ;;
  esac
done
kill -- -$VPID 2>/dev/null; sleep 0.5; kill -9 -- -$VPID 2>/dev/null
