#!/bin/bash
# Builds DigiScreen.zip - a PortMaster port of screendump (Elektron screen
# viewer TUI) for Knulli / Batocera aarch64 handhelds.
#
# Best run ON the device (aarch64 Linux): pip then resolves the python-rtmidi
# wheel for the device's actual Python, so nothing version-matches by hand.
#
#   ssh root@<knulli-ip>
#   cd /tmp && bash build-port.sh       # or scp the repo's scripts over first
#
# Produces: release/DigiScreen.zip
#
# The zip bundles:
#   DigiScreen.sh        PortMaster launcher (PORTMASTER header)
#   DigiScreen/          port dir: metadata, the screendump script, pair.sh,
#                        the gptokeyb control layer, and vendored
#                        python-rtmidi (aarch64).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${ROOT}/release/work"
OUT="${ROOT}/release/DigiScreen.zip"

log()  { printf '\n[build] %s\n' "$*"; }
die()  { printf '\n[build] ERROR: %s\n' "$*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || die "need python3"
command -v unzip  >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || die "need unzip or python3"

zipdir() { # zipdir <out-zip> <dir>
  rm -f "$1"
  if command -v zip >/dev/null 2>&1; then
    ( cd "$2" && zip -qr "$1" . )
  else
    ( cd "$2" && python3 - "$1" <<'PY'
import sys, zipfile, os
zf = zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED)
for root, dirs, files in os.walk("."):
    for f in files:
        p = os.path.join(root, f)
        zf.write(p, p[2:] if p.startswith("./") else p)
zf.close()
PY
    )
  fi
}

# --- vendored python-rtmidi (aarch64) -------------------------------------
# python-rtmidi wheels statically link rtmidi, so one unpacked wheel in py/
# is the whole dependency.
vendor_rtmidi() { # vendor_rtmidi <dest-dir>
  local dest="$1"
  if [ "$(uname -m 2>/dev/null)" = "aarch64" ]; then
    log "on aarch64: pip install python-rtmidi --target (native wheel)"
    python3 -m pip install --target "$dest" python-rtmidi \
      || die "pip install python-rtmidi failed -- see above"
  else
    local PYVER="${RTPYTHON_VERSION:-}"
    [ -n "$PYVER" ] || PYVER="$(python3 -c 'import sys; print("%d%d" % sys.version_info[:2])')"
    log "host is not aarch64: downloading the manylinux_2_28_aarch64 cp${PYVER} wheel"
    log "verify the device python matches: ssh root@<ip> 'python3 --version'"
    python3 -m pip download -q --only-binary=:all: --no-deps \
      --platform manylinux_2_28_aarch64 \
      --python-version "$PYVER" \
      --abi "cp${PYVER}" \
      --implementation cp \
      --dest "$WORK" python-rtmidi \
      || die "no aarch64 cp${PYVER} wheel for python-rtmidi; try RTPYTHON_VERSION=<device-pyver> or build on the device"
    local wheel
    wheel="$(ls "$WORK"/python_rtmidi-*.whl 2>/dev/null | head -1 || true)"
    [ -n "$wheel" ] || die "no rtmidi wheel downloaded into $WORK"
    mkdir -p "$dest"
    # extract with RELATIVE paths: python -m zipfile cannot read Git Bash's
    # /c/... absolute paths, and the device is the same wheel layout.
    ( cd "$WORK" && python3 -m zipfile -e "$(basename "$wheel")" "${dest#$WORK/}" )
  fi
  test -d "$dest/rtmidi" || die "vendored rtmidi did not land where expected"
}

# --- stage ------------------------------------------------------------------
log "staging in ${WORK}"
rm -rf "$WORK"
mkdir -p "$WORK" "$ROOT/release"

PORTDIR="$WORK/DigiScreen"
mkdir -p "$PORTDIR" "$PORTDIR/userdata"

vendor_rtmidi "$PORTDIR/py"

# --- port files --------------------------------------------------------------
log "copying screendump + portmaster metadata"
cp "$ROOT/screendump"                      "$PORTDIR/screendump"
cp "$ROOT/portmaster/port.json"            "$PORTDIR/port.json"
cp "$ROOT/portmaster/gameinfo.xml"         "$PORTDIR/gameinfo.xml"
cp "$ROOT/portmaster/DigiScreen.gptk"      "$PORTDIR/DigiScreen.gptk"
cp "$ROOT/portmaster/pair.sh"              "$PORTDIR/pair.sh"
chmod +x "$PORTDIR/pair.sh"

# --- zip (PortMaster layout: DigiScreen.sh at root + DigiScreen/ dir) --------
log "packing release/DigiScreen.zip"
mkdir -p "$WORK/ziproot"
cp "$ROOT/portmaster/DigiScreen.sh" "$WORK/ziproot/DigiScreen.sh"
cp -r "$PORTDIR" "$WORK/ziproot/DigiScreen"
zipdir "$OUT" "$WORK/ziproot"

# --- DigiScreen-Stream: FatmaVision stream + DigiScreen, as its own port -----
log "packing release/DigiScreen-Stream.zip"
OUT2="${ROOT}/release/DigiScreen-Stream.zip"
mkdir -p "$WORK/ziproot2/DigiScreen-Stream"
cp "$ROOT/portmaster/DigiScreen-Stream.sh"         "$WORK/ziproot2/DigiScreen-Stream.sh"
cp "$ROOT/portmaster/DigiScreen-Stream/stream.sh"  "$WORK/ziproot2/DigiScreen-Stream/stream.sh"
cp "$ROOT/portmaster/DigiScreen-Stream/port.json"  "$WORK/ziproot2/DigiScreen-Stream/port.json"
cp "$ROOT/portmaster/DigiScreen-Stream/gameinfo.xml" "$WORK/ziproot2/DigiScreen-Stream/gameinfo.xml"
chmod +x "$WORK/ziproot2/DigiScreen-Stream.sh"
zipdir "$OUT2" "$WORK/ziproot2"
rm -rf "$WORK"

log "done: ${OUT} ($(du -h "$OUT" | cut -f1)) and ${OUT2} ($(du -h "$OUT2" | cut -f1))"
log "install: bash scripts/install-ssh.sh root@<knulli-ip>"
log "or: scp ${OUT} root@<knulli-ip>:/userdata/ && ssh root@<knulli-ip> 'cd /userdata && unzip -o DigiScreen.zip -d /userdata/roms/ports/ && chmod +x /userdata/roms/ports/DigiScreen.sh && rm DigiScreen.zip'"