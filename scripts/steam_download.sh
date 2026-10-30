#!/usr/bin/env bash
# Download Europa Universalis V (Windows depots) with steamcmd.
#
# Usage:  scripts/steam_download.sh <steam_username> [install_dir]
# Default install_dir: ~/dev/game-data/eu5
#
# steamcmd will prompt for your Steam password and a Steam Guard code the
# first time. After a successful login the session is cached, so re-runs
# (e.g. after a game patch) only need the username.
set -euo pipefail

STEAM_USER="${1:?usage: $0 <steam_username> [install_dir]}"
INSTALL_DIR="${2:-$HOME/dev/game-data/eu5}"
APP_ID=3450310   # Europa Universalis V

mkdir -p "$INSTALL_DIR"

# Order matters: platform type and install dir must be set before login.
exec steamcmd \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir "$INSTALL_DIR" \
  +login "$STEAM_USER" \
  +app_update "$APP_ID" validate \
  +quit
