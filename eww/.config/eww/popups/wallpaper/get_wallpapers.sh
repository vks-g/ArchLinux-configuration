#!/usr/bin/env bash

# --- CONFIGURATION ---
# CHANGE THIS TO YOUR WALLPAPER PATH
WALL_DIR="/etc/nixos/config/sessions/hyprland/images"
CACHE_DIR="$HOME/.cache/eww/wall_thumbs"
THUMB_SIZE="320x180" # 16:9 Aspect Ratio for previews

mkdir -p "$CACHE_DIR"

# Generate JSON
echo -n "["
first=true

# Find images (jpg, jpeg, png, webp)
find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort | while read -r img; do
    filename=$(basename "$img")
    thumb="$CACHE_DIR/$filename"

    # Generate thumb if missing (Requires ImageMagick)
    if [ ! -f "$thumb" ]; then
        convert "$img" -thumbnail "$THUMB_SIZE" -gravity center -extent "$THUMB_SIZE" "$thumb"
    fi

    if [ "$first" = true ]; then
        first=false
    else
        echo -n ","
    fi

    # Escape quotes for JSON safety
    clean_path=$(echo "$img" | sed 's/"/\\"/g')
    clean_thumb=$(echo "$thumb" | sed 's/"/\\"/g')
    clean_name=$(echo "$filename" | sed 's/\.[^.]*$//') # Remove extension for display name

    echo -n "{\"path\": \"$clean_path\", \"thumb\": \"$clean_thumb\", \"name\": \"$clean_name\"}"
done

echo "]"
