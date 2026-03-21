#!/usr/bin/env bash

EWW=`which eww`
CFG="$HOME/.config/eww/popups/search-bar"
FILE="$HOME/.cache/eww_launch.searchbar"


if [[ ! -f "$FILE" ]]; then
	touch "$FILE"
	${EWW} --config "$CFG" open search_bar 
else
	${EWW} --config "$CFG" close search_bar
	rm "$FILE"
fi


