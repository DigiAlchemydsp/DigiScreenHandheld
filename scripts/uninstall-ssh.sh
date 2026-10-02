#!/bin/bash
# Removes the DigiScreen port from a Knulli device over SSH.
#
# Usage: ./uninstall-ssh.sh [user@host]
set -euo pipefail

HOST="${1:-root@knulli}"

echo ">> removing DigiScreen from $HOST"
ssh "$HOST" '
  rm -rf /userdata/roms/ports/DigiScreen
  rm -f  /userdata/roms/ports/DigiScreen.sh
  echo ">> removed. Restart EmulationStation (or reboot) to refresh the Ports menu."
'