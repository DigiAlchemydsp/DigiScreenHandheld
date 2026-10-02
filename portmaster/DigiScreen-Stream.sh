#!/bin/bash
# PORTMASTER: DigiScreen-Stream.zip, DigiScreen-Stream.sh
# DigiScreen-Stream -- the FatmaVision screen stream plus the DigiScreen
# Elektron mirror. The stream starts FIRST (fb0 -> H.264 over TCP:5555, watch
# in the FatmaVision app), then DigiScreen takes the display; when DigiScreen
# ends, the stream stops. Needs ffmpeg (ships with Knulli) and the DigiScreen
# port installed -- DigiScreen.sh does its own PortMaster setup, gptokeyb and
# tunings, so this script only orchestrates the two.

GAMEDIR="$(dirname "$(readlink -f "$0")")/DigiScreen-Stream"

# 1) the FatmaVision screen stream (bundled here, or an installed FatmaVision)
STREAM=""
for c in "$GAMEDIR/stream.sh" /userdata/screenstream/stream.sh \
         /userdata/roms/ports/screenstream/stream.sh; do
  [ -f "$c" ] && STREAM="$c" && break
done
if [ -z "$STREAM" ]; then
  echo "DigiScreen-Stream: no stream.sh found (bundle it or install FatmaVision)" >&2
  sleep 4
  exit 1
fi

echo "DigiScreen-Stream: starting screen stream on tcp:5555 ..."
setsid nohup sh "$STREAM" 5555 </dev/null >/tmp/screenstream.log 2>&1 &
STREAM_PID=$!
sleep 2

# 2) then DigiScreen (launch after the stream is up)
if [ -x /userdata/roms/ports/DigiScreen.sh ]; then
  bash /userdata/roms/ports/DigiScreen.sh
  RC=$?
else
  echo "DigiScreen-Stream: DigiScreen not installed -- run the DigiScreen port once" >&2
  RC=1
fi

# stop the stream with DigiScreen
kill -TERM -"$STREAM_PID" 2>/dev/null
sleep 1
exit $RC