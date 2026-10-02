#!/bin/bash
# Installs release/Screendump.zip onto a Knulli device over SSH.
#
# Usage:
#   ./install-ssh.sh [user@host] [path/to/Screendump.zip]
#
# Examples:
#   ./install-ssh.sh root@<knulli-ip>
#   ./install-ssh.sh root@knulli /tmp/Screendump.zip
set -euo pipefail

HOST="${1:-root@knulli}"
ZIP="${2:-$(cd "$(dirname "$0")/.." && pwd)/release/Screendump.zip}"

[ -f "$ZIP" ] || { echo "ERROR: $ZIP not found (build it first: scripts/build-port.sh)" >&2; exit 1; }

echo ">> wrong-device guard (MUST be silent)"
ssh "$HOST" "grep -q knulli /etc/os-release || echo WRONG-DEVICE"

echo ">> copying $ZIP to $HOST:/userdata/"
scp "$ZIP" "${HOST}:/userdata/Screendump.zip"

echo ">> extracting into /userdata/roms/ports/"
ssh "$HOST" '
  set -e
  cd /userdata
  rm -rf /userdata/roms/ports/Screendump /userdata/roms/ports/Screendump.sh
  unzip -o /userdata/Screendump.zip -d /userdata/roms/ports/
  chmod +x /userdata/roms/ports/Screendump.sh /userdata/roms/ports/Screendump/pair.sh
  rm -f /userdata/Screendump.zip
  echo ">> installed. Restart EmulationStation (or reboot) and launch Screendump from the Ports menu."
'