#!/bin/bash
# Runs inside the nested kwin session. Env: THEME NAME MEDIA ACTIONS OUT CFG
export QT_QPA_PLATFORM=${QPA:-xcb} QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1
# pin the desktop: an inherited non-KDE one (e.g. XFCE) makes Qt load the GTK theme and its ATK bridge,
# which registers a second, empty "vlc" accessible app
export XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 DESKTOP_SESSION=plasma
xdotool() { env -u WAYLAND_DISPLAY /usr/bin/xdotool "$@"; }
# spectacle as an X11 client hangs when there is no logind session: keep it on Wayland
# its errors go to <scene>.spectacle.txt (in CI no shot was ever written; the reason was thrown away)
spectacle() { QT_QPA_PLATFORM=wayland timeout 20 /usr/bin/spectacle "$@" 2>>"$OUT/$NAME.spectacle.txt"; }
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
# sound:null: a private PipeWire (+ WirePlumber, + its PulseAudio server) with two silent null outputs,
# "Test Speakers" (the default) and "Test Headphones", for the scenes about output devices and volume.
# Its own runtime folder (never the desktop's sound server), no ALSA/Bluetooth monitors (no real device),
# null sinks discard the audio: nothing reaches the speakers. VLC picks its audio output itself, like a
# normal start (--aout=any: on a PipeWire system that is VLC's PipeWire output); SNDAOUT=pulse forces one.
SOUNDARGS=""; SNDPIDS=""
case " $ACTIONS " in *" sound:null "*)
    SND=$(mktemp -d /tmp/vlcsnd.XXXX)   # short: a socket path must stay under 108 characters
    mkdir -p "$CFG/pipewire/pipewire.conf.d" "$CFG/wireplumber/wireplumber.conf.d"
    cat > "$CFG/pipewire/pipewire.conf.d/test-sinks.conf" <<'PW'
context.objects = [
    { factory = adapter
      args = { factory.name = support.null-audio-sink node.name = "test-speakers"
               node.description = "Test Speakers" media.class = "Audio/Sink"
               audio.position = [ FL FR ] priority.session = 2000 priority.driver = 2000 } }
    { factory = adapter
      args = { factory.name = support.null-audio-sink node.name = "test-headphones"
               node.description = "Test Headphones" media.class = "Audio/Sink"
               audio.position = [ FL FR ] priority.session = 1000 priority.driver = 1000 } }
]
PW
    cat > "$CFG/wireplumber/wireplumber.conf.d/no-hardware.conf" <<'WP'
wireplumber.profiles = {
    main = {
        monitor.alsa = disabled
        monitor.alsa-midi = disabled
        monitor.bluez = disabled
        monitor.bluez-midi = disabled
        monitor.libcamera = disabled
        monitor.v4l2 = disabled
    }
}
WP
    for p in pipewire wireplumber pipewire-pulse; do
        env XDG_RUNTIME_DIR="$SND" PIPEWIRE_RUNTIME_DIR="$SND" XDG_CONFIG_HOME="$CFG" $p > "$OUT/$NAME.$p.txt" 2>&1 &
        SNDPIDS="$SNDPIDS $!"; sleep 1
    done
    for i in $(seq 20); do [ -S "$SND/pulse/native" ] && break; sleep 0.25; done
    VENV="$VENV PULSE_SERVER=unix:$SND/pulse/native PIPEWIRE_RUNTIME_DIR=$SND"
    SOUNDARGS="--aout=${SNDAOUT:-any}"
    ;;
esac
# start in the output folder: a scene that turns on "Save a log" makes VLC write vlc-log.txt into its working
# directory (it was the repository root)
cd "$OUT"
setsid env $VENV "$VLC" ${VLCARGS} $SOUNDARGS $ML ${WIZ:---no-qt-privacy-ask} --no-qt-backdrop-blur $MEDIA > "$OUT/$NAME.log" 2>&1 &
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
    values:*) "$LIB/at.py" values > "$OUT/$NAME-${a#values:}.values" 2>/dev/null ;;
    audit:*) "$LIB/at.py" audit > "$OUT/$NAME-${a#audit:}.a11y" 2>/dev/null ;;
  esac
done
kill -- -$VPID 2>/dev/null; sleep 0.5; kill -9 -- -$VPID 2>/dev/null
[ -n "$SNDPIDS" ] && { kill $SNDPIDS 2>/dev/null; sleep 0.3; kill -9 $SNDPIDS 2>/dev/null; rm -rf "$SND"; }
