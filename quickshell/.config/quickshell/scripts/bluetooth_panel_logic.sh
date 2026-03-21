#!/usr/bin/env bash

# Log file for RSSI scraping
SCAN_LOG="$HOME/.cache/bt_scan.log"
PID_FILE="$HOME/.cache/bt_scan_pid"
EWW_BIN=$(which eww)

# --- HELPER FUNCTIONS ---

get_icon() {
    local type=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local name=$(echo "$2" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$type" == *"headset"* ]] || [[ "$type" == *"headphone"* ]] || [[ "$name" == *"headphone"* ]] || [[ "$name" == *"buds"* ]] || [[ "$name" == *"pods"* ]]; then
        echo "🎧"
    elif [[ "$type" == *"audio"* ]] || [[ "$type" == *"speaker"* ]] || [[ "$type" == *"card"* ]] || [[ "$name" == *"speaker"* ]]; then
        echo "蓼"
    elif [[ "$type" == *"phone"* ]] || [[ "$name" == *"phone"* ]] || [[ "$name" == *"iphone"* ]] || [[ "$name" == *"android"* ]]; then
        echo ""
    elif [[ "$type" == *"mouse"* ]] || [[ "$name" == *"mouse"* ]]; then
        echo ""
    elif [[ "$type" == *"keyboard"* ]] || [[ "$name" == *"keyboard"* ]]; then
        echo ""
    elif [[ "$type" == *"controller"* ]] || [[ "$name" == *"controller"* ]]; then
        echo ""
    else
        echo ""
    fi
}

get_rssi() {
    local mac="$1"
    if [ -f "$SCAN_LOG" ]; then
        # Look for "RSSI: -XX" associated with this MAC in recent lines
        local rssi=$(grep -B 5 "$mac" "$SCAN_LOG" | grep "RSSI" | tail -n1 | awk '{print $2}')
        echo "${rssi:-0}"
    else
        echo "0"
    fi
}

get_rssi_icon() {
    local rssi="$1"
    # RSSI is negative. Closer to 0 is better.
    if [ "$rssi" -eq 0 ]; then echo ""; # No signal data
    elif [ "$rssi" -ge -50 ]; then echo "󰤨"
    elif [ "$rssi" -ge -65 ]; then echo "󰤥"
    elif [ "$rssi" -ge -80 ]; then echo "󰤢"
    else echo "󰤟"
    fi
}

# --- MAIN STATUS LOGIC ---

get_status() {
    power="off"
    if bluetoothctl show | grep -q "Powered: yes"; then
        power="on"
    fi

    # CHANGE 1: Initialize as an EMPTY OBJECT, not "null"
    # This prevents Eww from freezing when switching types
    connected_json="{\"name\": \"\", \"mac\": \"\", \"icon\": \"\", \"battery\": \"0\", \"profile\": \"\"}"
    
    devices_json="[]"

    if [ "$power" == "on" ]; then
        paired_macs=$(bluetoothctl devices Paired | cut -d ' ' -f 2)
        mapfile -t devices < <(bluetoothctl devices)

        connected_mac=""
        
        # Lists for sorting: Paired (Connect) vs Strangers (Pair)
        paired_list_objs=()
        discovered_list_objs=()

        # 1. CONNECTED DEVICE
        connected_info=$(bluetoothctl devices Connected)
        if [ -n "$connected_info" ]; then
            connected_mac=$(echo "$connected_info" | cut -d ' ' -f 2)
            name=$(echo "$connected_info" | cut -d ' ' -f 3-)
            info=$(bluetoothctl info "$connected_mac")
            
            icon_type=$(echo "$info" | grep "Icon:" | cut -d: -f2 | xargs)
            icon=$(get_icon "$icon_type" "$name")
            bat=$(echo "$info" | grep "Battery Percentage" | awk '{print $NF}' | tr -d '()')
            if [ -z "$bat" ] || [ "$bat" == "?" ]; then bat="0"; fi
            
            profile=$(get_audio_profile "$connected_mac") # Ensure this function exists in your helpers or remove if unused

            # CHANGE 2: No need to use jq -n here, just overwrite the variable
            connected_json=$(jq -n \
                                --arg name "$name" \
                                --arg mac "$connected_mac" \
                                --arg icon "$icon" \
                                --arg bat "$bat" \
                                --arg profile "$profile" \
                                '{name: $name, mac: $mac, icon: $icon, battery: $bat, profile: $profile}')
        fi

        # 2. LOOP ALL DEVICES
        for line in "${devices[@]}"; do
            if [ -z "$line" ]; then continue; fi
            mac=$(echo "$line" | cut -d ' ' -f 2)
            
            # Skip connected
            if [ "$mac" == "$connected_mac" ]; then continue; fi

            name=$(echo "$line" | cut -d ' ' -f 3-)
            icon=$(get_icon "unknown" "$name")

            # Get RSSI
            rssi=$(get_rssi "$mac")
            rssi_icon=$(get_rssi_icon "$rssi")

            # Check if Paired
            if echo "$paired_macs" | grep -q "$mac"; then
                action="Connect"
                
                # Add to PAIRED list
                obj=$(jq -n \
                        --arg name "$name" \
                        --arg mac "$mac" \
                        --arg icon "$icon" \
                        --arg action "$action" \
                        --arg rssi "$rssi_icon" \
                        '{name: $name, mac: $mac, icon: $icon, action: $action, rssi: $rssi}')
                paired_list_objs+=("$obj")
            else
                action="Pair"
                
                # Add to DISCOVERED list
                obj=$(jq -n \
                        --arg name "$name" \
                        --arg mac "$mac" \
                        --arg icon "$icon" \
                        --arg action "$action" \
                        --arg rssi "$rssi_icon" \
                        '{name: $name, mac: $mac, icon: $icon, action: $action, rssi: $rssi}')
                discovered_list_objs+=("$obj")
            fi
        done

        # Combine lists: Paired first, then Discovered
        all_objs=("${paired_list_objs[@]}" "${discovered_list_objs[@]}")

        if [ ${#all_objs[@]} -gt 0 ]; then
            devices_json=$(printf '%s\n' "${all_objs[@]}" | jq -s '.')
        fi
    fi

    # CHANGE 3: Since connected_json is already a JSON string (either empty obj or full obj),
    # we pass it as --argjson safely.
    jq -n \
        --arg power "$power" \
        --argjson connected "$connected_json" \
        --argjson devices "$devices_json" \
        '{power: $power, connected: $connected, devices: $devices}'
}
# --- COMMAND SWITCHER ---

toggle_power() {
    if bluetoothctl show | grep -q "Powered: yes"; then
        bluetoothctl power off
    else
        bluetoothctl power on
    fi
    sleep 0.5
    get_status
}

connect_dev() {
    local mac="$1"
    
    # 1. Start Animation
    $EWW_BIN  --config ~/.config/eww/bar update connecting_mac="$mac"
    
    # 2. Pause Scanning (Crucial for connection reliability)
    if [ -f "$PID_FILE" ]; then
        kill -STOP $(cat "$PID_FILE") 2>/dev/null
    fi
    
    # 3. Trust & Connect
    bluetoothctl trust "$mac" > /dev/null 2>&1
    bluetoothctl connect "$mac"
    
    # 4. Resume Scanning
    if [ -f "$PID_FILE" ]; then
        kill -CONT $(cat "$PID_FILE") 2>/dev/null
    fi
    
    # 5. Stop Animation (Ensure this runs even if connect failed)
    $EWW_BIN --config ~/.config/eww/bar update connecting_mac=""
}

disconnect_dev() {
    local mac="$1"
    bluetoothctl disconnect "$mac"
}

cmd="$1"
case $cmd in
    --status) get_status ;;
    --toggle) toggle_power ;;
    --connect) connect_dev "$2" ;;
    --disconnect) disconnect_dev "$2" ;;
esac
