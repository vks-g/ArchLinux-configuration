#!/usr/bin/env bash

EWW=$(which eww)
CFG="$HOME/.config/eww/bar/"
FILE="$HOME/.cache/eww_launch.bar"

run_eww() {
	"$EWW" --config "$CFG" open bar
}

close_eww() {
	"$EWW" --config "$CFG" close bar
}

# Check for --force-open flag
if [[ "$1" == "--force-open" ]]; then
	touch "$FILE"
	run_eww
	exit 0
fi

# Check for --force-close flag
if [[ "$1" == "--force-close" ]]; then
	close_eww
	rm -f "$FILE"
	exit 0
fi

# Normal toggle behavior
if [[ ! -f "$FILE" ]]; then
	touch "$FILE"
	run_eww
else
	close_eww
	rm "$FILE"
fi
