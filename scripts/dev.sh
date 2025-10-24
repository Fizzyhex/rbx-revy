#!/bin/sh
# ref: https://github.com/grilme99/roblox-project-template/blob/main/scripts/dev.sh

# Stop execution if any tasks fail
set -e

# If Packages aren't installed, install them.
if [ ! -d "roblox_packages" ]; then
    sh psede install
fi

rojo serve default.project.json \
    & rojo sourcemap dev.project.json -o sourcemap.json --watch \
    & ROBLOX_DEV=true darklua process --config .darklua.json --watch src/ dist/
    & ROBLOX_DEV=true darklua process --config .darklua.json --watch game/src game/dist