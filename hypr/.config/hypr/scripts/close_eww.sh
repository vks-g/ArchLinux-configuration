#!/usr/bin/env bash

# Arguments:
# $1: The workspace number (e.g., 1, 2, 3...)
# $2: The action mode (optional). passing "move" will move the window instead of switching workspace.

TARGET_WORKSPACE="$1"
ACTION="${2:-switch}" # Default to 'switch' if second arg is missing

# Configuration
EWW_BIN=$(which eww)
EWW_CFG="$HOME/.config/eww/bar"

# 1. List of Eww windows to force close
WINDOWS="battery_win music_win network_win calendar_win search_bar" 

# 2. Close the windows (Only if eww is actually running)
if pidof eww > /dev/null; then
    ${EWW_BIN} --config ${EWW_CFG} close $WINDOWS 2>/dev/null
fi

# 3. Clean up the toggle state files

# --- Special Cleanup for Network/Bluetooth ---
# The network toggle starts a background bluetooth scan that must be killed explicitly.
BT_PID_FILE="$HOME/.cache/bt_scan_pid"

if [ -f "$BT_PID_FILE" ]; then
    kill $(cat "$BT_PID_FILE") 2>/dev/null
    rm "$BT_PID_FILE"
fi

# Ensure bluetooth scan is explicitly turned off
bluetoothctl scan off > /dev/null 2>&1
# ---------------------------------------------

# Generic cleanup for other widgets
rm -f "$HOME/.cache/eww_launch.battery"
rm -f "$HOME/.cache/eww_launch.musicbar"
rm -f "$HOME/.cache/eww_launch.network"
rm -f "$HOME/.cache/eww_launch.calendar"
rm -f "$HOME/.cache/eww_launch.searchbar"

# 4. Perform Hyprland Action
if [[ "$ACTION" == "move" ]]; then
    # Move the active window to the target workspace
    hyprctl dispatch movetoworkspace "$TARGET_WORKSPACE"
else
    # Just switch to the target workspace
    hyprctl dispatch workspace "$TARGET_WORKSPACE"
fi
