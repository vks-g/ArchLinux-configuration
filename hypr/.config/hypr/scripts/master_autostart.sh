#!/bin/bash

# 1. Setup Workspace 1 layout
bash ~/.config/hypr/scripts/ws1_layout.sh
sleep 1

# 2. Setup Workspace 4 layout
spotify &
sleep 1

# 3. Launch remaining apps (Rules in window-rules.conf handle placement)
# We give the WS2 terminal a unique title to lock it to WS2
kitty --title ws2-terminal &
zen-browser &
vesktop &
obsidian &

# Finally, return focus to Workspace 1
hyprctl dispatch workspace 1
