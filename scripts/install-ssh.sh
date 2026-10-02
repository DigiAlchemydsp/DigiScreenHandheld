#!/bin/bash
# Installs release/DigiScreen.zip onto a Knulli device over SSH.
#
# Usage:
#   ./install-ssh.sh [user@host] [path/to/DigiScreen.zip]
#
# Examples:
#   ./install-ssh.sh root@<knulli-ip>
#   ./install-ssh.sh root@knulli /tmp/DigiScreen.zip
set -euo pipefail

HOST="${1:-root@knulli}"
ZIP="${2:-$(cd "$(dirname "$0")/.." && pwd)/release/DigiScreen.zip}"

[ -f "$ZIP" ] || { echo "ERROR: $ZIP not found (build it first: scripts/build-port.sh)" >&2; exit 1; }

echo ">> wrong-device guard (MUST be silent)"
ssh "$HOST" "grep -q knulli /etc/os-release || echo WRONG-DEVICE"

echo ">> copying $ZIP to $HOST:/userdata/"
scp "$ZIP" "${HOST}:/userdata/DigiScreen.zip"

echo ">> extracting into /userdata/roms/ports/"
ssh "$HOST" '
  set -e
  cd /userdata
  rm -rf /userdata/roms/ports/DigiScreen /userdata/roms/ports/DigiScreen.sh
  unzip -o /userdata/DigiScreen.zip -d /userdata/roms/ports/
  chmod +x /userdata/roms/ports/DigiScreen.sh /userdata/roms/ports/DigiScreen/pair.sh
  rm -f /userdata/DigiScreen.zip
  echo ">> installed. Restart EmulationStation (or reboot) and launch DigiScreen from the Ports menu."
'