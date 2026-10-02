#!/bin/bash
# Removes the Screendump port from a Knulli device over SSH.
#
# Usage: ./uninstall-ssh.sh [user@host]
set -euo pipefail

HOST="${1:-root@knulli}"

echo ">> removing Screendump from $HOST"
ssh "$HOST" '
  rm -rf /userdata/roms/ports/Screendump
  rm -f  /userdata/roms/ports/Screendump.sh
  echo ">> removed. Restart EmulationStation (or reboot) to refresh the Ports menu."
'