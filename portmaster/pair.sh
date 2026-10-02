#!/bin/sh
# Screendump pairing loop -- invoked by vaixterm -e (which execs a single path).
#
# Cycles the Elektron instruments, streams the first one that answers, and
# re-pairs whenever the stream ends -- so you can swap the box (or unplug it
# and plug in another) without relaunching the port.
GAMEDIR="/userdata/roms/ports/Screendump"
export HOME="$GAMEDIR/userdata"
mkdir -p "$HOME"
export TERM=xterm-256color
[ -d "$GAMEDIR/py" ] && export PYTHONPATH="$GAMEDIR/py${PYTHONPATH:+:$PYTHONPATH}"
[ -d "$GAMEDIR/py/python_rtmidi" ] && export LD_LIBRARY_PATH="$GAMEDIR/py/python_rtmidi${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$GAMEDIR" || exit 1

SD="$GAMEDIR/screendump"
# The box is the only Elektron device on the bus; "Elektron" names its ports.
export SCREENDUMP_MIDI_IN=Elektron SCREENDUMP_MIDI_OUT=Elektron

# Order matters: first to answer wins. dn and dt share the screenshot RPC id,
# so either machine is found under either name; the stream works regardless.
INSTRUMENTS="dn dt sy"

probe() {
  python3 "$SD" -x --timeout 1 --instrument "$1" >/dev/null 2>&1
}

printf '\n  SCREENDUMP -- Elektron screen stream\n'
printf '  q quits the stream back to pairing; the EmulationStation hotkey quits the port\n'
while true; do
  FOUND=""
  for inst in $INSTRUMENTS; do
    if probe "$inst"; then
      FOUND="$inst"
      break
    fi
  done
  if [ -n "$FOUND" ]; then
    printf '\n  connected to %s -- streaming\n' "$FOUND"
    printf '  A save  X mode  Y invert  R1 flip  L2 pause  B quit\n'
    python3 "$SD" -x --framerate 30 --instrument "$FOUND" --blocks
    printf '\n  stream ended -- watching for a machine again...\n'
    sleep 1
  else
    printf '\r  no machine found (digitone/digitakt/syntakt) -- retrying      '
    sleep 2
  fi
done