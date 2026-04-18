#!/bin/bash
hyprctl dispatch workspace 1
sleep 2

# 1. btop fullscreen first
kitty --title ws1-btop --hold -e btop &
sleep 0.5

# 2. Split RIGHT for fastfetch (50/50 left-right)
hyprctl dispatch layoutmsg preselect r
kitty --title ws1-fastfetch --hold -e fastfetch &
sleep 0.5

# 3. Focus fastfetch, split DOWN for unimatrix
hyprctl dispatch focuswindow "title:^(ws1-fastfetch)$"
hyprctl dispatch layoutmsg preselect d
kitty --title ws1-unimatrix --hold -e bash -c 'unimatrix -s 96 -f' &
sleep 0.5

# --- Adjust Proportions ---

# fastfetch: slightly shorter so unimatrix gets more room below
# 50/50 default is close, just nudge fastfetch up a bit
hyprctl dispatch focuswindow "title:^(ws1-fastfetch)$"
hyprctl dispatch resizeactive 0 -80
sleep 0.2

# Return focus to btop
hyprctl dispatch focuswindow "title:^(ws1-btop)$"
