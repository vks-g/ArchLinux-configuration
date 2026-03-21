#!/usr/bin/env bash

QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
BT_SCAN_LOG="$HOME/.cache/bt_scan.log"
SRC_DIR="$HOME/Images/Wallpapers"
THUMB_DIR="$HOME/.cache/wallpaper_picker/thumbs"

IPC_FILE="/tmp/qs_widget_state"
NETWORK_MODE_FILE="/tmp/qs_network_mode"
ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

handle_wallpaper_prep() {
    mkdir -p "$THUMB_DIR"
    (
        for thumb in "$THUMB_DIR"/*; do
            [ -e "$thumb" ] || continue
            filename=$(basename "$thumb")
            clean_name="${filename#000_}"
            if [ ! -f "$SRC_DIR/$clean_name" ]; then
                rm -f "$thumb"
            fi
        done

        for img in "$SRC_DIR"/*.{jpg,jpeg,png,webp,gif,mp4,mkv,mov,webm}; do
            [ -e "$img" ] || continue
            filename=$(basename "$img")
            extension="${filename##*.}"

            if [[ "${extension,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
                thumb="$THUMB_DIR/000_$filename"
                [ -f "$THUMB_DIR/$filename" ] && rm -f "$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                     ffmpeg -y -ss 00:00:05 -i "$img" -vframes 1 -f image2 -q:v 2 "$thumb" > /dev/null 2>&1
                fi
            else
                thumb="$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                    magick "$img" -resize x420 -quality 70 "$thumb"
                fi
            fi
        done
    ) &

    TARGET_THUMB=""
    CURRENT_SRC=""

    if pgrep -a "mpvpaper" > /dev/null; then
        CURRENT_SRC=$(pgrep -a mpvpaper | grep -o "$SRC_DIR/[^' ]*" | head -n1)
        CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -z "$CURRENT_SRC" ] && command -v swww >/dev/null; then
        CURRENT_SRC=$(swww query 2>/dev/null | grep -o "$SRC_DIR/[^ ]*" | head -n1)
        CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -n "$CURRENT_SRC" ]; then
        EXT="${CURRENT_SRC##*.}"
        if [[ "${EXT,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
            TARGET_THUMB="000_$CURRENT_SRC"
        else
            TARGET_THUMB="$CURRENT_SRC"
        fi
    fi
    
    export WALLPAPER_THUMB="$TARGET_THUMB"
}

handle_network_prep() {
    echo "" > "$BT_SCAN_LOG"
    { echo "scan on"; sleep infinity; } | stdbuf -oL bluetoothctl > "$BT_SCAN_LOG" 2>&1 &
    echo $! > "$BT_PID_FILE"
    (nmcli device wifi rescan) &
}

# -----------------------------------------------------------------------------
# ENSURE MASTER WINDOW & TOP BAR ARE ALIVE (ZOMBIE WATCHDOG)
# -----------------------------------------------------------------------------
QS_PID=$(pgrep -f "quickshell.*Main\.qml")
WIN_EXISTS=$(hyprctl clients -j | grep "qs-master")

BAR_PID=$(pgrep -f "quickshell.*TopBar\.qml")

# 1. Manage the Master morphing window
if [[ -z "$QS_PID" ]] || [[ -z "$WIN_EXISTS" ]]; then
    if [[ -n "$QS_PID" ]]; then
        kill -9 $QS_PID 2>/dev/null
    fi
    quickshell -p "$QS_DIR/Main.qml" >/dev/null 2>&1 &
    disown
    sleep 0.6 
fi

# 2. Manage the persistent Top Bar
if [[ -z "$BAR_PID" ]]; then
    quickshell -p "$QS_DIR/TopBar.qml" >/dev/null 2>&1 &
    disown
fi

# -----------------------------------------------------------------------------
# MAIN LOGIC
# -----------------------------------------------------------------------------
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    MOVE_OPT="$2"
    echo "close" > "$IPC_FILE"
    
    if [[ "$MOVE_OPT" == "move" ]]; then
        hyprctl dispatch movetoworkspace "$WORKSPACE_NUM"
    else
        hyprctl dispatch workspace "$WORKSPACE_NUM"
    fi

    TARGET_ADDR=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $WORKSPACE_NUM and (.class | contains(\"qs-master\") | not) and (.title | contains(\"qs-master\") | not)) | .address" | head -n 1)

    if [[ -n "$TARGET_ADDR" && "$TARGET_ADDR" != "null" ]]; then
        hyprctl --batch "keyword cursor:no_warps true ; dispatch focuswindow address:$TARGET_ADDR ; keyword cursor:no_warps false"
    else
        hyprctl --batch "keyword cursor:no_warps true ; dispatch focuswindow qs-master ; keyword cursor:no_warps false"
    fi

    exit 0
fi

if [[ "$ACTION" == "close" ]]; then
    echo "close" > "$IPC_FILE"
    if [[ "$TARGET" == "network" || "$TARGET" == "all" || -z "$TARGET" ]]; then
        if [ -f "$BT_PID_FILE" ]; then
            kill $(cat "$BT_PID_FILE") 2>/dev/null
            rm -f "$BT_PID_FILE"
        fi
        bluetoothctl scan off > /dev/null 2>&1
    fi
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    if [[ "$TARGET" == "network" ]]; then
        ACTIVE_WIDGET=$(cat /tmp/qs_active_widget 2>/dev/null)
        CURRENT_MODE=$(cat "$NETWORK_MODE_FILE" 2>/dev/null)

        if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "network" ]]; then
            if [[ -n "$SUBTARGET" ]]; then
                if [[ "$CURRENT_MODE" == "$SUBTARGET" ]]; then
                    echo "close" > "$IPC_FILE"
                else
                    echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
                fi
            else
                echo "close" > "$IPC_FILE"
            fi
        else
            handle_network_prep
            if [[ -n "$SUBTARGET" ]]; then
                echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
            fi
            echo "$TARGET" > "$IPC_FILE"
        fi
        exit 0
    fi

    if [[ "$TARGET" == "wallpaper" ]]; then
        handle_wallpaper_prep
        # Passing the exact filename string to QML instead of an index
        echo "$TARGET:$WALLPAPER_THUMB" > "$IPC_FILE"
    else
        echo "$TARGET" > "$IPC_FILE"
    fi
    exit 0
fi
