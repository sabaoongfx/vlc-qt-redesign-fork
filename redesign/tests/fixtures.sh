#!/bin/bash
# Generate test media and a scanned media-library profile into $FIX (default redesign/tests/out/fixtures).
set -e
T=$(cd "$(dirname "$0")" && pwd)
FIX=${FIX:-$T/out/fixtures}
export VLC=${VLC:-$(cd "$T/../.." && pwd)/build/vlc}
mkdir -p "$FIX"
cd "$FIX"
ff() { ffmpeg -loglevel error -y "$@"; }

[ -f sample.mp4 ] || ff -f lavfi -i testsrc2=size=854x480:rate=25 -f lavfi -i sine=frequency=440 -t 120 \
    -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac sample.mp4
[ -f short.mp4 ] || ff -f lavfi -i testsrc2=size=640x360:rate=25 -f lavfi -i sine=frequency=330 -t 4 \
    -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac short.mp4
[ -f "A_very_long_title_that_should_be_elided_somewhere_in_the_interface.mp4" ] || \
    cp short.mp4 "A_very_long_title_that_should_be_elided_somewhere_in_the_interface.mp4"
# two audio tracks and two subtitle tracks
if [ ! -f multi.mkv ]; then
    printf '1\n00:00:00,500 --> 00:00:30,000\nEnglish subtitle line\n' > en.srt
    printf '1\n00:00:00,500 --> 00:00:30,000\nLigne de sous-titre\n' > fr.srt
    ff -f lavfi -i testsrc2=size=854x480:rate=25 -f lavfi -i sine=frequency=440 -f lavfi -i sine=frequency=660 \
       -i en.srt -i fr.srt -t 30 -map 0 -map 1 -map 2 -map 3 -map 4 -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
       -c:a aac -c:s srt -metadata:s:a:0 language=eng -metadata:s:a:1 language=fra \
       -metadata:s:s:0 language=eng -metadata:s:s:1 language=fra multi.mkv
fi
# audio with cover art
if [ ! -f neon.mp3 ]; then
    magick -size 600x600 gradient:'#3b1d4a'-'#d37918' cover.jpg
    ff -f lavfi -i sine=frequency=262:duration=20 -i cover.jpg -map 0:a -map 1:v -c:a libmp3lame -b:a 96k -c:v mjpeg \
       -disposition:v attached_pic -id3v2_version 3 -metadata artist="Static Bloom" -metadata album="Night Drive" \
       -metadata title="Neon" neon.mp3
fi

# media library home
P=$FIX/profile
if [ ! -d "$P/home" ]; then
    mkdir -p "$P/home/Videos/Shows/The Wand/S01" "$P/home/Music" "$P/config"
    for i in $(seq -w 1 12); do
        ff -f lavfi -i "testsrc2=size=640x360:rate=25" -f lavfi -i "sine=frequency=$((200+10#$i*30))" -t 15 \
           -vf "hue=h=$((10#$i*30))" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac \
           "$P/home/Videos/Shows/The Wand/S01/The_Wand_S01E$i.mp4"
    done
    cp sample.mp4 "$P/home/Videos/Sample Movie.mp4"
    cp sample.mp4 "$P/home/Videos/long_movie.mp4"  # indexed, no spaces: resume tests
    for a in "Aurora Lane|Paper Lanterns|#2a3d5c-#8fb8de" "Static Bloom|Night Drive|#3b1d4a-#d37918"; do
        IFS='|' read artist album grad <<< "$a"
        magick -size 600x600 gradient:"$grad" "$FIX/cover-$album.jpg"
        for n in 1 2 3; do
            ff -f lavfi -i "sine=frequency=$((300+n*50)):duration=20" -i "$FIX/cover-$album.jpg" -map 0:a -map 1:v \
               -c:a libmp3lame -b:a 96k -c:v mjpeg -disposition:v attached_pic -id3v2_version 3 \
               -metadata artist="$artist" -metadata album_artist="$artist" -metadata album="$album" \
               -metadata track=$n -metadata title="Song $n" "$P/home/Music/$artist - $album - $n.mp3"
        done
    done
    # first run: the wizard adds the XDG Videos/Music folders and the library scans them
    WIZ=" " PROFILE=$P NAME=fixture-wizard THEME=2 MEDIA="" OUT=$FIX TIMEOUT=90 \
    ACTIONS="sleep:3 press:Allow_metadata_network_access sleep:0.3 press:Next_> sleep:1 press:Next_> sleep:1 press:Next_> sleep:1 press:Finish sleep:40" \
        "$T/lib/scene.sh"
fi
echo "fixtures in $FIX"
