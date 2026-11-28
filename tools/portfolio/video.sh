#!/bin/bash
# Joins the PNG segments rendered by tools/portfolio/video.gd into MP4 (H.264, yuv420p, no audio).
# Usage: tools/portfolio/video.sh <frames dir> <out dir>
# V2-01: reward → battle (pause, order) → victory → after the battle; 0.4 s crossfades, the last segment ends on
#        the same screen and cursor position as the first, so the loop has no jump to black.
# V2-02, V2-03: single segments, a short crossfade from the end back to the start makes them loop smoothly.
set -e
F=$1; O=$2; mkdir -p "$O"
X=0.4
enc="-c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -movflags +faststart -an"

seg() { ffmpeg -y -v error -framerate 30 -i "$F/$1/%05d.png" -c:v libx264 -preset veryfast -crf 14 -pix_fmt yuv420p "$F/$1.mp4"; }
dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$F/$1.mp4"; }

for s in v1_reward v1_battle v1_win v1_after v2_ability v3_order; do [ -d "$F/$s" ] && seg $s; done

# V2-01
if [ -f "$F/v1_after.mp4" ]; then
  a=$(dur v1_reward); b=$(dur v1_battle); c=$(dur v1_win)
  o1=$(echo "$a - $X" | bc); o2=$(echo "$o1 + $b - $X" | bc); o3=$(echo "$o2 + $c - $X" | bc)
  ffmpeg -y -v error -i "$F/v1_reward.mp4" -i "$F/v1_battle.mp4" -i "$F/v1_win.mp4" -i "$F/v1_after.mp4" -filter_complex \
    "[0][1]xfade=transition=fade:duration=$X:offset=$o1[a];[a][2]xfade=transition=fade:duration=$X:offset=$o2[b];[b][3]xfade=transition=fade:duration=$X:offset=$o3[v]" \
    -map "[v]" $enc "$O/V2-01.mp4"
fi

# V2-02, V2-03: loop crossfade (the last 0.4 s fade into the first frames)
loop() {
  d=$(dur $1); o=$(echo "$d - 2*$X" | bc)
  ffmpeg -y -v error -i "$F/$1.mp4" -filter_complex \
    "[0]split[m][h];[h]trim=0:$X,setpts=PTS-STARTPTS[head];[m]trim=$X:$d,setpts=PTS-STARTPTS[body];[body][head]xfade=transition=fade:duration=$X:offset=$o[v]" \
    -map "[v]" $enc "$O/$2.mp4"
}
[ -f "$F/v2_ability.mp4" ] && loop v2_ability V2-02
[ -f "$F/v3_order.mp4" ] && loop v3_order V2-03
ls -la "$O"/*.mp4
