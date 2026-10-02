#!/bin/bash
# PORTMASTER: Screendump.zip, Screendump.sh
# Elektron screendump TUI port for Knulli (Anbernic H700).
# Runs inside the vaixterm terminal emulator; gamepad mapped by Screendump.gptk.
# pair.sh cycles the Elektron machines, streams the first that answers, and
# re-pairs whenever the stream ends.

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
elif [ -d "/userdata/system/.local/share/PortMaster/" ]; then
  controlfolder="/userdata/system/.local/share/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/Screendump"
cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

export HOME="$GAMEDIR/userdata"
mkdir -p "$HOME"
export TERM=xterm-256color
# Ensure the controller database exists (ES creates it at boot; fall back to the bundled one)
if [ ! -f /tmp/gamecontrollerdb.txt ]; then
  cp -f "$controlfolder/knulli/gamecontrollerdb.txt" /tmp/gamecontrollerdb.txt 2>/dev/null
fi
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# MIDI over USB must not suspend under idle load -- Knulli's usbcore
# autosuspend (2 s idle) would otherwise drop the Elektron connection.
ORIG_USB_AUTOSUSPEND="$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)"
cleanup() {
    rc=$?
    [ -n "$ORIG_USB_AUTOSUSPEND" ] && echo "$ORIG_USB_AUTOSUSPEND" > /sys/module/usbcore/parameters/autosuspend 2>/dev/null
    exit $rc
}
trap cleanup EXIT
echo 0 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null

# vendored python-rtmidi (bundled by scripts/build-port.sh)
[ -d "$GAMEDIR/py" ] && export PYTHONPATH="$GAMEDIR/py${PYTHONPATH:+:$PYTHONPATH}"
# the rtmidi .so dlopens the wheel-bundled libjack from python_rtmidi/
[ -d "$GAMEDIR/py/python_rtmidi" ] && export LD_LIBRARY_PATH="$GAMEDIR/py/python_rtmidi${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# gamepad -> TUI keys (see Screendump.gptk)
$GPTOKEYB "vaixterm" -c "Screendump.gptk" &
pm_platform_helper "vaixterm"

# Size the terminal so the 128-column blocks screen fills the display width
# edge to edge. Half-block cells are solid, so this mirrors the machine at
# full size. vaixterm takes fractional points, so the font is computed (not
# rounded) to put exactly 5 px under each column on a 640-wide display; the
# advance factor (0.602 of the em at 96 dpi) is measured for DejaVu Sans Mono.
# SCREENDUP_FONT_PT overrides it if a font is swapped.
# (fbset's geometry line is indented -- no ^anchor.)
FB_W=$(awk -F, 'NR==1{print $1}' /sys/class/graphics/fb0/virtual_size 2>/dev/null)
FB_H=$(fbset 2>/dev/null | sed -n 's/^[[:space:]]*geometry[[:space:]]*[0-9]*[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
FB_W=${FB_W:-640}; FB_H=${FB_H:-480}
PT="${SCREENDUP_FONT_PT:-}"
if [ -z "$PT" ]; then
  PT=$(awk -v w="$FB_W" 'BEGIN{p=w/128/0.602/1.333; if(p<4)p=4; if(p>24)p=24; printf "%.2f", p}')
fi

/usr/bin/vaixterm -w "$FB_W" -h "$FB_H" -s "$PT" \
  -f /usr/share/fonts/dejavu/DejaVuSansMono-Bold.ttf \
  --fps 30 --no-credit --force-full-render \
  -e "$GAMEDIR/pair.sh"

pm_finish