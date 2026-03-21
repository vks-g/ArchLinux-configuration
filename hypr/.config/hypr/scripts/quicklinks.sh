#!/usr/bin/env bash

# --- 1. Settings ---
CONFIG_FILE="$HOME/.config/rofi/quicklink.yaml"
ICON_DIR="$HOME/.config/rofi/quick-icons"

# --- 2. Toggle Logic ---
if pgrep -x "rofi" > /dev/null; then
    pkill rofi
    exit 0
fi

# --- 3. Generator Function ---
generate_menu() {
    if [ ! -f "$CONFIG_FILE" ]; then
        notify-send "Error" "Quicklinks config file not found!"
        exit 1
    fi

    # Loop through yaml entries
    # We pipe directly to rofi later, so null bytes (\0) are preserved
    yq -r '.[] | .name + "|" + .icon + "|" + .command' "$CONFIG_FILE" | while IFS='|' read -r name icon cmd; do
        
        # Resolve Icon Path
        if [[ -f "$ICON_DIR/$icon" ]]; then
            icon_path="$ICON_DIR/$icon"
        else
            icon_path="$icon"
        fi

        # Format: Name \0 icon \x1f IconPath
        # usage of printf is critical here
        printf "%s\0icon\x1f%s\n" "$name" "$icon_path"
    done
}

# --- 4. Rofi Logic ---
# PIPING DIRECTLY avoids Bash stripping the null bytes
SELECTED=$(generate_menu | rofi -dmenu \
    -p "Quick Links" \
    -show-icons \
    -i \
    -config ~/.config/rofi/config.rasi \
    -theme-str 'window { width: 800px; }' \
    -theme-str 'listview { columns: 4; lines: 3; }')

# Exit if nothing selected
if [ -z "$SELECTED" ]; then
    exit 0
fi

# --- 5. Execution ---
# Find command matching the clean name
COMMAND=$(yq -r ".[] | select(.name == \"$SELECTED\") | .command" "$CONFIG_FILE")

if [ -z "$COMMAND" ]; then
    notify-send "Error" "Command not found for: $SELECTED"
    exit 1
fi

eval "$COMMAND"
