#!/usr/bin/env bash

# Usage: ./toggle_eww.sh <window_name>
# Example: ./toggle_eww.sh network_win

TARGET_WIN="$1"
EWW_BIN=$(which eww)
CFG="$HOME/.config/eww/bar"

# --- Configuration: Define all your windows and their lockfiles here ---
declare -A LOCKFILES
LOCKFILES=(
    ["battery_win"]="$HOME/.cache/eww_launch.battery"
    ["music_win"]="$HOME/.cache/eww_launch.musicbar"
    ["network_win"]="$HOME/.cache/eww_launch.network"
    ["calendar_win"]="$HOME/.cache/eww_launch.calendar"
    ["search_bar"]="$HOME/.cache/eww_launch.searchbar"
)

# Bluetooth specific files
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
BT_SCAN_LOG="$HOME/.cache/bt_scan.log"

# 1. Check current state of the requested window
WAS_OPEN=false
TARGET_LOCK="${LOCKFILES[$TARGET_WIN]}"

if [[ -f "$TARGET_LOCK" ]]; then
    WAS_OPEN=true
fi

# 2. GLOBAL RESET: Close ALL windows and clean ALL state
# We do this every time to ensure "exclusive" behavior (only one open at a time)

# A. Close all eww windows in the list
ALL_WINS="${!LOCKFILES[*]}" # expanded list of keys
${EWW_BIN} --config ${CFG} close $ALL_WINS 2>/dev/null

# B. Remove all lockfiles
for win in "${!LOCKFILES[@]}"; do
    rm -f "${LOCKFILES[$win]}"
done

# C. Special Cleanup: Network/Bluetooth
# Regardless of which window we are toggling, if network was open, kill the scan.
if [ -f "$BT_PID_FILE" ]; then
    kill $(cat "$BT_PID_FILE") 2>/dev/null
    rm "$BT_PID_FILE"
fi
bluetoothctl scan off > /dev/null 2>&1


# 3. OPEN NEW WINDOW (Only if it wasn't open before)
if [[ "$WAS_OPEN" == "false" ]]; then
    
    # A. Create the lockfile
    touch "$TARGET_LOCK"

    # B. Open the window
    ${EWW_BIN} --config ${CFG} open "$TARGET_WIN"

    # C. Special Startup: Network/Bluetooth
    if [[ "$TARGET_WIN" == "network_win" ]]; then
        # Start Bluetooth Scan
        echo "" > "$BT_SCAN_LOG"
        { echo "scan on"; sleep infinity; } | stdbuf -oL bluetoothctl > "$BT_SCAN_LOG" 2>&1 &
        echo $! > "$BT_PID_FILE"

        # Trigger WiFi Rescan
        (nmcli device wifi rescan) &
    fi
fi

