#!/bin/sh
# Claude Code hook: marks the kitty tab holding this window with a persistent
# bell. Sets the kitty user var bell_pending on the window (tab_bar.py renders
# it, watcher.py clears it when the user leaves the tab), then rings a plain
# BEL so kitty's built-in bell indicator still works for unfocused windows.
# Hook processes have no controlling tty, so walk up the process tree to the
# first ancestor that has one and write to that device.
# Inside tmux the user var sequence is wrapped in tmux passthrough
# (needs `set -g allow-passthrough on`) with every ESC doubled.
SETVAR='\033]1337;SetUserVar=bell_pending=MQ==\007'
if [ -n "$TMUX" ]; then
  SETVAR='\033Ptmux;\033\033]1337;SetUserVar=bell_pending=MQ==\007\033\\'
fi
p=$PPID
while [ "${p:-0}" -gt 1 ]; do
  t=$(ps -o tty= -p "$p" | tr -d ' ')
  case "$t" in
    ''|'?'|'??') ;;
    *) printf "$SETVAR\\a" > "/dev/$t"; exit 0 ;;
  esac
  p=$(ps -o ppid= -p "$p" | tr -d ' ')
done
exit 0
