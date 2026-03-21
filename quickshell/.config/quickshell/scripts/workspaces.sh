#!/usr/bin/env bash

EWW_BIN=$(which eww)
EWW_CFG="$HOME/.config/eww/bar"

# 1. List of Eww windows to force close
WINDOWS="battery_win music_win network_win calendar_win search_bar" 

# 2. Close the windows
${EWW_BIN} --config ${EWW_CFG} close $WINDOWS 2>/dev/null

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


# Configuration: How many workspaces do you want to show?
SEQ_END=6

print_workspaces() {
    # Get raw data
    spaces=$(hyprctl workspaces -j)
    active=$(hyprctl activeworkspace -j | jq '.id')

    # Generate the JSON
    echo "$spaces" | jq --argjson a "$active" --arg end "$SEQ_END" -c '
        # Create a map of workspace ID -> workspace data for easy lookup
        (map( { (.id|tostring): . } ) | add) as $s
        |
        # Iterate from 1 to SEQ_END
        [range(1; ($end|tonumber) + 1)] | map(
            . as $i |
            # Determine state: active -> occupied -> empty
            (if $i == $a then "active"
             elif ($s[$i|tostring] != null and $s[$i|tostring].windows > 0) then "occupied"
             else "empty" end) as $state |

            # Get window title for tooltip (if exists)
            (if $s[$i|tostring] != null then $s[$i|tostring].lastwindowtitle else "Empty" end) as $win |

            {
                id: $i,
                state: $state,
                tooltip: $win
            }
        )
    '
}

# Print initial state
print_workspaces

# Listen to Hyprland socket
socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r line; do
    case "$line" in
        workspace*|createwindow*|closewindow*|movewindow*)
            print_workspaces
            ;;
    esac
done
