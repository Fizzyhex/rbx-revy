#!/bin/sh

# Stop execution if any tasks fail
set -e

pesde install

rojo sourcemap dev.project.json -o sourcemap.json
darklua process --config .darklua.json src/ dist/

pesde publish
wally publish