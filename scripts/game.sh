#!/bin/sh
# ref: https://github.com/grilme99/roblox-project-template/blob/main/scripts/dev.sh

# Stop execution if any tasks fail
set -e

# If Packages aren't installed, install them.
if [ ! -d "roblox_packages" ]; then
    sh psede install
fi

darklua process --config .darklua.json src/ dist/

rojo serve game/build.project.json \
    & rojo sourcemap game/default.project.json -o game/sourcemap.json --watch \
    & ROBLOX_DEV=true darklua process --config game/.darklua.json --watch game/src game/dist