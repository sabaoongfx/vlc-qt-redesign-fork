#!/bin/bash
# Screenshots for the website: a library of good-looking generated media (soft colour gradients,
# albums with covers) instead of the test patterns, then the scenes of showcase.txt.
# usage: showcase.sh [scene-regex]   output: out/showcase-shots/*.png
set -e
T=$(cd "$(dirname "$0")" && pwd)
export FIX=${FIX:-$T/out/showcase}
export VLC=${VLC:-$(cd "$T/../.." && pwd)/build/vlc}
mkdir -p "$FIX"
cd "$FIX"
ff() { ffmpeg -nostdin -loglevel error -y "$@"; }
# grad <c0> <c1> <c2> <seed> <seconds> <out> [extra ffmpeg args]: a slowly moving 3-colour gradient
# (2 fps keeps long durations cheap), with a soft tone
grad() {
    local c0=$1 c1=$2 c2=$3 seed=$4 t=$5 out=$6; shift 6
    ff -f lavfi -i "gradients=s=1280x720:c0=$c0:c1=$c1:c2=$c2:n=3:speed=0.01:type=linear:seed=$seed:r=2" \
       -f lavfi -i "sine=frequency=220:sample_rate=22050" -t "$t" -vf "vignette=PI/4" \
       -c:v libx264 -preset ultrafast -tune stillimage -pix_fmt yuv420p -c:a aac -b:a 32k "$@" "$out"
}

P=$FIX/profile
if [ ! -d "$P/home" ]; then
    mkdir -p "$P/home/Videos" "$P/home/Music" "$P/config"
    V=$P/home/Videos
    i=0
    while IFS='|' read -r title c0 c1 c2 secs; do
        i=$((i+1))
        grad "$c0" "$c1" "$c2" $((i*7)) "$secs" "$V/$title.mp4" -metadata title="$title"
    done <<'EOF'
Golden Hour|0x200f0a|0xd37918|0xffd29d|2843
Deep Current|0x0b1d3a|0x2f80ed|0xf2994a|3512
Neon Bloom|0x1a0b2e|0xb5179e|0xf72585|1426
Low Tide|0x02111b|0x1b998b|0xe9c46a|5268
Polar Drift|0x0a1420|0x5aa9e6|0xe0f2ff|2210
Ember Coast|0x1b0505|0xc1121f|0xfdc500|3967
Night Garden|0x050f0a|0x2d6a4f|0xb7e4c7|1803
First Light|0x10131f|0x7f5af0|0xffd6a5|4421
Dusk Line|0x14080e|0x9d4edd|0xff9e00|2675
Glasshouse|0x081c15|0x40916c|0xd8f3dc|3120
EOF
    for a in "Aurora Lane|Paper Lanterns|#2a3d5c-#8fb8de|Lanterns,Harbour Lights,Slow Rain,Paper Moon" \
             "Static Bloom|Night Drive|#3b1d4a-#d37918|Neon,Overpass,Tail Lights,After Hours" \
             "Mira Vale|Glass Gardens|#0b3d2e-#e9c46a|Greenhouse,Morning Fog,Ivy,Sundial" \
             "Low Orbit|Salt & Static|#1a1a40-#f72585|Salt,Static,Satellite,Re-entry"; do
        IFS='|' read artist album grad tracks <<< "$a"
        magick -size 600x600 gradient:"$grad" -swirl 60 "$FIX/cover-$album.jpg"
        n=0
        IFS=',' read -ra TR <<< "$tracks"
        for title in "${TR[@]}"; do
            n=$((n+1))
            ff -f lavfi -i "sine=frequency=$((260+n*40)):duration=$((150+n*37))" -i "$FIX/cover-$album.jpg" \
               -map 0:a -map 1:v -c:a libmp3lame -b:a 32k -c:v mjpeg -disposition:v attached_pic -id3v2_version 3 \
               -metadata artist="$artist" -metadata album_artist="$artist" -metadata album="$album" \
               -metadata track=$n -metadata title="$title" "$P/home/Music/$artist - $album - $n.mp3"
        done
    done
    # first run: the wizard adds no folders (the library lists only what the user opened)
    WIZ=" " PROFILE=$P NAME=showcase-wizard THEME=2 MEDIA="" OUT=$FIX TIMEOUT=120 \
    ACTIONS="sleep:3 press:Allow_metadata_network_access sleep:0.3 press:Next_> sleep:1 press:Next_> sleep:1 press:Next_> sleep:1 press:Finish sleep:3" \
        "$T/lib/scene.sh"
    # Open Folder (Ctrl+F) adds Videos and Music to the library, which scans them (as fixtures.sh)
    PROFILE=$P NAME=showcase-folders THEME=2 MEDIA="" OUT=$FIX TIMEOUT=120 \
    ACTIONS="sleep:2 key:ctrl+f sleep:3 click:1050,680 key:ctrl+a type:$P/home/Videos sleep:0.5 key:Return sleep:1 key:s sleep:3 key:ctrl+f sleep:3 click:1050,680 key:ctrl+a type:$P/home/Music sleep:0.5 key:Return sleep:1 key:s sleep:60" \
        "$T/lib/scene.sh"
    # Open Folder also played the folders for a moment: the library starts with no history
    python3 -c 'import sqlite3, sys; db = sqlite3.connect(sys.argv[1]); db.execute("UPDATE Media SET play_count = 0, last_played_date = NULL, last_position = -1, last_time = -1"); db.commit()' "$P/data/vlc/ml/ml.db"
fi
# media for the player scenes (run.sh replaces @ with $FIX/)
[ -f golden.mp4 ] || cp "$P/home/Videos/Golden Hour.mp4" golden.mp4
if [ ! -f subs.mkv ]; then
    printf '1\n00:00:00,500 --> 00:10:00,000\nThe light came in low over the water.\n' > en.srt
    grad 0x0b1d3a 0x2f80ed 0xf2994a 14 600 deep.mp4 -metadata title="Deep Current"
    ff -i deep.mp4 -i en.srt -map 0 -map 1 -c copy -c:s srt -metadata:s:s:0 language=eng subs.mkv
fi

SCEN=$T/showcase.txt OUT=${OUT:-$T/out/showcase-shots} SKIP_FIXTURES=1 "$T/run.sh" "${1:-.}"
