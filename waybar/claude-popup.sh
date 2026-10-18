#!/bin/bash
# Read the pointer first, while it is still on the clicked widget.
pos=$(hyprctl cursorpos | tr -d ' ')

gdbus call --session --dest dev.arvlas.ClaudePopup --object-path /dev/arvlas/ClaudePopup \
    --method org.freedesktop.Application.ActivateAction toggle "[<'$pos'>]" "{}" >/dev/null 2>&1 && exit 0

# No running instance yet: start one, detached so Waybar doesn't wait on it.
setsid -f "$(dirname "$(readlink -f "$0")")/claude-popup.py" "$pos" >/dev/null 2>&1
