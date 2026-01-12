#!/bin/sh

# Stop execution if any tasks fail
set -e

pesde install

BOLD_GREEN='\033[1;32m'
BOLD_RED='\033[1;34m'
NC='\033[0m' # No Color

rojo sourcemap dev.project.json -o sourcemap.json

printf "Building for ${BOLD_GREEN}Standalone${NC}...\n"

export REVY_ENGINE="standalone"
darklua process --config .darklua.json src/ dist/

printf "Building for ${BOLD_RED}Roblox${NC}...\n"

export REVY_ENGINE="prison"
darklua process --config .darklua.json src/ dist_rbx/

printf "${BOLD_GREEN}Prepare to publish!${NC}...\n"

pesde publish

printf "${BOLD_GREEN}All done!${NC}...\n"
