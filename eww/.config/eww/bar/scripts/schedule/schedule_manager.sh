#!/bin/bash

CACHE_DIR="$HOME/.cache/eww/schedule"
CACHE_FILE="${CACHE_DIR}/schedule.json"
CACHE_LIMIT=600 # 1 Hour

# Script Paths
UPDATER_SCRIPT="$HOME/.config/eww/bar/scripts/schedule/get_schedule.py"
SHELL_NIX="$HOME/.config/eww/bar/scripts/schedule/shell.nix"

mkdir -p "$CACHE_DIR"

trigger_update() {
    nix-shell "$SHELL_NIX" --run "python3 '$UPDATER_SCRIPT'" >/dev/null 2>&1 &
}

if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    
    current_time=$(date +%s)
    file_time=$(stat -c %Y "$CACHE_FILE")
    age=$((current_time - file_time))
    
    if [ "$age" -gt "$CACHE_LIMIT" ]; then
        trigger_update
    fi
else
    # Valid placeholder with "link"
    echo '{ "header": "Loading...", "lessons": [], "link": "" }'
    trigger_update
fi
