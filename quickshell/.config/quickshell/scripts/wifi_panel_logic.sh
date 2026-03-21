#!/usr/bin/env bash

# Check if WiFi is enabled
POWER=$(nmcli radio wifi)

if [[ "$POWER" == "disabled" ]]; then
    echo '{ "power": "off", "connected": "null", "networks": [] }'
    exit 0
fi

# Function to get icon based on signal strength
get_icon() {
    local signal=$1
    if [[ $signal -ge 80 ]]; then echo "󰤨";
    elif [[ $signal -ge 60 ]]; then echo "󰤥";
    elif [[ $signal -ge 40 ]]; then echo "󰤢";
    elif [[ $signal -ge 20 ]]; then echo "󰤟";
    else echo "󰤯"; fi
}

# Get current connection details
# Fields: active, ssid, signal, security
CURRENT_RAW=$(nmcli -t -f active,ssid,signal,security device wifi | grep "^yes")

if [[ -n "$CURRENT_RAW" ]]; then
    # Parse the colon-separated values
    IFS=':' read -r active ssid signal security <<< "$CURRENT_RAW"
    
    icon=$(get_icon "$signal")
    
    # JSON for connected device
    CONNECTED_JSON=$(jq -n \
                  --arg ssid "$ssid" \
                  --arg icon "$icon" \
                  --arg signal "$signal" \
                  --arg security "$security" \
                  '{ssid: $ssid, icon: $icon, signal: $signal, security: $security}')
else
    CONNECTED_JSON="null"
fi

# Get available networks (excluding current connection and empty SSIDs)
# We use awk to deduplicate SSIDs (keep first occurrence which is usually strongest due to nmcli sorting)
NETWORKS_JSON=$(nmcli -t -f active,ssid,signal,security device wifi list | \
    awk -F: '!seen[$2]++ && $2 != "" && $1 != "yes" {print $2":"$3":"$4}' | \
    head -n 20 | \
    while IFS=':' read -r ssid signal security; do
        icon=$(get_icon "$signal")
        jq -n \
           --arg ssid "$ssid" \
           --arg icon "$icon" \
           --arg signal "$signal" \
           --arg security "$security" \
           '{ssid: $ssid, icon: $icon, signal: $signal, security: $security}'
    done | jq -s '.')

# Final Output
echo $(jq -n \
       --arg power "on" \
       --argjson connected "$CONNECTED_JSON" \
       --argjson networks "$NETWORKS_JSON" \
       '{power: $power, connected: $connected, networks: $networks}')
