#!/bin/bash
# Ensure standard cursor theme for Wayland apps like slurp to show crosshair (+) indicator
export XCURSOR_THEME=Adwaita
export HYPRCURSOR_THEME=Adwaita

mkdir -p ~/Pictures/Screenshots
FILE=~/Pictures/Screenshots/screenshot_$(date +%Y%m%d_%H%M%S).png

# Run slurp with premium styling matching theme colors and dimensions enabled
if grim -g "$(slurp -d -c 89b4fa -b 11111b33 -s 11111b33 -w 2)" "$FILE"; then
    wl-copy -t image/png < "$FILE" 2>/dev/null
    notify-send -t 3000 "Screenshot" "Saved to $FILE"
fi

