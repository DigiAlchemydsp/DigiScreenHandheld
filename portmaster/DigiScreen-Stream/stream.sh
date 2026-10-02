#!/bin/sh
# screenstream - fb0 -> raw H.264 ES -> paced delivery over TCP (read-only, no
# tunings, no muxing on the device). stage1 encodes as fast as possible to a
# pipe; stage2 -re paces delivery to real time. One client per connection.
# Bundled from FatmaVision (device/stream.sh).
PORT="${1:-5555}"
DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
FFMPEG="$(command -v ffmpeg 2>/dev/null)"
[ -x "$DIR/ffmpeg" ] && FFMPEG="$DIR/ffmpeg"
if [ -z "$FFMPEG" ]; then
  echo "screenstream: no ffmpeg available" >&2
  exit 1
fi

# No frontend watchdog: when a game/app launches it intentionally stops the
# frontend (ES/muOS) to yield the display; the stream must keep encoding fb0
# without ever starting a duplicate frontend session.
FPS="${SCREENSTREAM_FPS:-30}"
while true; do
  "$FFMPEG" -hide_banner -loglevel warning \
    -f fbdev -framerate "$FPS" -i /dev/fb0 \
    -vf "settb=AVTB,setpts=N/${FPS}/TB,realtime,fps=${FPS},format=yuv420p" \
    -c:v libx264 -preset ultrafast -tune zerolatency -bf 0 -g 12 -r "$FPS" \
    -profile:v baseline -pix_fmt yuv420p \
    -f h264 - 2>/tmp/screenstream_stage1.log |
  "$FFMPEG" -hide_banner -loglevel warning \
    -re -fflags nobuffer -f h264 -i - -c:v copy \
    -f h264 "tcp://0.0.0.0:${PORT}?listen=1"
  sleep 1
done