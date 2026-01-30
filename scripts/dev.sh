#!/bin/sh

# ref: https://github.com/grilme99/roblox-project-template/blob/main/scripts/dev.sh

# Stop execution if any tasks fail
set -e

# If Packages aren't installed, install them
if [ ! -d "roblox_packages" ]; then
    sh pesde install
fi

if [[ "$REVY_ENGINE" == "prison" ]]; then
    roblox_dev=true
    config=".darklua.json"
else
    roblox_dev=false
    config=".darklua.json"
fi

rojo serve default.project.json \
    & rojo sourcemap dev.project.json -o sourcemap.json --watch \
    & ROBLOX_DEV="$roblox_dev" darklua process --config "$config" --watch src/ dist/