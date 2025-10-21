#!/bin/sh

# Stop execution if any tasks fail
set -e

rojo sourcemap ./dev.project.json -o sourcemap.json
darklua process --config .darklua.json src/ dist/
wally publish