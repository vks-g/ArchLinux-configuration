#!/usr/bin/env bash

# --- CONFIGURATION ---
EWW_CFG="$HOME/.config/eww/popups/volume"
EWW_BIN=$(which eww)

# PID file to track the current "sleep" process.
TIMER_PID="/tmp/eww_volume_timer.pid"

# --- HELPER FUNCTIONS ---

get_icon() {
    IS_MUTED=$(pamixer --get-mute)
    VOL_NUM=$(pamixer --get-volume)

    if [[ "$IS_MUTED" == "true" ]] || [[ "$VOL_NUM" -eq 0 ]]; then
        echo "󰝟" 
    else
        echo "" 
    fi
}

ensure_eww_ready() {
    # Check if daemon is responding
    if ! $EWW_BIN ping &>/dev/null; then
        # Daemon is dead. Start it.
        $EWW_BIN daemon &
        
        # Wait for the daemon to respond to ping
        while ! $EWW_BIN ping &>/dev/null; do
            sleep 0.1
        done

        # CRITICAL FIX for "0%" bug:
        # Give the daemon a moment to fully initialize its internal state variables
        # before we try to update them. Without this, Eww loads default "0" 
        # *after* we send the update.
        sleep 0.5
    fi
}

show_osd() {
    ensure_eww_ready

    # 1. Kill the previous sleep timer (reset countdown)
    if [ -f "$TIMER_PID" ]; then
        kill "$(cat "$TIMER_PID")" 2>/dev/null
    fi

    # 2. Get current values
    VOL=$(pamixer --get-volume)
    ICON=$(get_icon)

    # 3. Update Eww variables FIRST
    $EWW_BIN -c "$EWW_CFG" update volume_value="$VOL" volume_icon="$ICON"

    # 4. Open Window ONLY if it is not already open
    #    CRITICAL FIX for "Ghost" window:
    #    Spamming "eww open" on an already open window causes glitches/stuck windows.
    if ! $EWW_BIN active-windows | grep -q "volume_osd"; then
        $EWW_BIN -c "$EWW_CFG" open volume_osd
    fi

    # 5. Start background timer to close window
    (
        sleep 2
        $EWW_BIN -c "$EWW_CFG" close volume_osd
        rm "$TIMER_PID" 2>/dev/null
    ) &

    # 6. Save PID
    echo $! > "$TIMER_PID"
}

# --- ACTIONS ---

get_volume() {
    volume=$(pamixer --get-volume)
    if [[ "$volume" -eq "0" ]]; then
        echo "Muted"
    else
        echo "$volume %"
    fi
}

inc_volume() {
    if [ "$(pamixer --get-mute)" == "true" ]; then
        pamixer -u
    else
        pamixer -i 5 
    fi
    show_osd
}

dec_volume() {
    if [ "$(pamixer --get-mute)" == "true" ]; then
        pamixer -u
    else
        pamixer -d 5
    fi
    show_osd
}

toggle_mute() {
    pamixer -t
    show_osd
}

toggle_mic() {
    pamixer --default-source -t
}

# --- EXECUTION ---

if [[ "$1" == "--get" ]]; then
    get_volume
elif [[ "$1" == "--inc" ]]; then
    inc_volume
elif [[ "$1" == "--dec" ]]; then
    dec_volume
elif [[ "$1" == "--toggle" ]]; then
    toggle_mute
elif [[ "$1" == "--toggle-mic" ]]; then
    toggle_mic
else
    get_volume
fi
