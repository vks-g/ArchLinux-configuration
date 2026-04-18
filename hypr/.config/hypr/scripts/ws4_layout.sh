#!/bin/bash
hyprctl dispatch workspace 1
sleep 2

# 1. Start cava-bottom fullscreen first (so it spans full width)
kitty --title ws1-cava-bottom --hold -e cava &
sleep 0.5

# 2. Split UP for spotify (top section)
hyprctl dispatch layoutmsg preselect u
spotify &
sleep 2  # spotify takes longer to open

# 3. Focus spotify, split RIGHT for cava-right (narrow right strip)
hyprctl dispatch focuswindow "class:^(spotify)$"
hyprctl dispatch layoutmsg preselect r
kitty --title ws1-cava-right --hold -e cava &
sleep 0.5

# --- Adjust Proportions ---

# cava-bottom: shrink to ~20% height (from default 50%)
hyprctl dispatch focuswindow "title:^(ws1-cava-bottom)$"
hyprctl dispatch resizeactive 0 -260
sleep 0.2

# cava-right: shrink to ~13% width (from default 50%)
hyprctl dispatch focuswindow "title:^(ws1-cava-right)$"
hyprctl dispatch resizeactive -420 0
sleep 0.2

# Return focus to spotify
hyprctl dispatch focuswindow "class:^(spotify)$"
