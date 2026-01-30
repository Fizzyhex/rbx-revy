#!/bin/sh
# ref: https://github.com/grilme99/roblox-project-template/blob/main/scripts/dev.sh

# This script is for working on Revy with Roblox Studio by syncing scripts into the testing game.
#
# After updating Revy's source, make sure to stop this script and re-run it to get the latest
# changes.

# Stop execution if any tasks fail
set -e

# If Packages aren't installed, install them
if [ ! -d "roblox_packages" ]; then
    sh pesde install
fi

BOLD_GREEN='\033[1;32m'
NC='\033[0m' # No Color

export REVY_ENGINE="prison"

printf "${BOLD_GREEN}Processing latest Revy changes${NC}\n"

# Build darklua revy output first
rojo sourcemap dev.project.json -o sourcemap.json
darklua process --config .darklua.json src/ dist/

printf "${BOLD_GREEN}Serving game${NC}\n"
rojo serve game/build.project.json \
    & rojo sourcemap game/default.project.json -o game/sourcemap.json --watch \
    & ROBLOX_DEV=true darklua process --config game/.darklua.json --watch game/src game/dist