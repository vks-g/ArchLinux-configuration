#!/usr/bin/env bash
sleep 2

# Restart swww
pkill swww-daemon
sleep 0.5
swww-daemon &
sleep 0.5
swww restore &

# Restart hypridle
pkill hypridle
sleep 0.5
hypridle &

# Restart playerctld
pkill playerctld
playerctld &

# Restart clipboard managers
pkill -f "wl-paste.*cliphist"
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &

# Restart volume listener
pkill -f volume_listener.sh
~/.config/hypr/scripts/volume_listener.sh &

# Restart quickshell
pkill quickshell
sleep 1
quickshell -p ~/.config/hypr/scripts/quickshell/Main.qml &
quickshell -p ~/.config/hypr/scripts/quickshell/TopBar.qml &

# Push qs-master off screen
sleep 3
hyprctl dispatch movewindowpixel "exact -5000 -5000,title:^(qs-master)$"
hyprctl dispatch resizewindowpixel "exact 1 1,title:^(qs-master)$"

