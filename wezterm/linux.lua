-- Linux/Hyprland. WezTerm actions live on ctrl+shift: bare ctrl belongs to the
-- shell (ctrl+d EOF, ctrl+w kill-word, ctrl+c SIGINT, ctrl+q XON, ctrl+z
-- suspend), super belongs to Hyprland. MOD_SHIFT+X collapses to ctrl+shift+X
-- here, so mac's cmd+X and cmd+shift+X layers share one chord.
local wezterm = require("wezterm")
local act = wezterm.action

local M = {
  MOD = "CTRL|SHIFT",
  MOD_SHIFT = "CTRL|SHIFT",
}

-- Apps that turn on the kitty keyboard protocol (Claude Code, neovim, helix)
-- ask WezTerm to report every key, so an unbound chord arrives at the app as a
-- literal CSI-u sequence and lands in the input buffer as garbage, e.g.
-- ctrl+shift+h -> CSI 104 ; 6 u, shown as "104;6u".
-- Nop swallows the event: neither WezTerm nor the app sees it. (Unbinding with
-- DisableDefaultAssignment would do the opposite - that is what leaks the
-- sequence.)
--
-- Bare ctrl is deliberately absent: every ctrl+<letter> is a live shell key.
-- ctrl+shift+c/v (copy/paste), ctrl+tab and ctrl+shift+tab (tab cycling) keep
-- their WezTerm defaults, as do the combos bound above and in wezterm.lua.
local NOP_CTRL_SHIFT = {
  "a", "e", "g", "h", "j", "k", "n", "o", "p", "r", "s", "u", "x", "z",
  ",", ".", ";", "'", "\\",
  "UpArrow", "DownArrow", "Home", "End", "PageUp", "PageDown", "Backspace",
  "Delete", "Space", "Escape", "Insert",
  "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
}

function M.apply(config, shared)
  local bind = shared.bind

  bind("CTRL|SHIFT", "t", act.SpawnTab("CurrentPaneDomain"))
  -- hsplit gets ctrl+alt: ctrl+shift+d is vsplit (mac uses cmd+shift+d)
  bind("CTRL|ALT", "phys:D", act.SplitVertical({ domain = "CurrentPaneDomain" }))
  -- kitty's ctrl+shift+grave (nth_window -1, jump to the previously focused
  -- pane) has no WezTerm action.

  -- --- clipboard -------------------------------------------------------------
  -- ctrl+shift+c / ctrl+shift+v are WezTerm's Linux defaults and stay unchanged.
  -- Needs OSC 133 marks, which bash doesn't emit.
  bind("CTRL|SHIFT", "phys:Y", shared.copy_last_output)

  -- --- readline-style line editing -------------------------------------------
  -- home/end and ctrl+u/ctrl+k already cover line start/end on Linux.
  -- ctrl+arrow is the Linux word-jump convention.
  bind("CTRL", "LeftArrow", act.SendString("\x1b\x62"))
  bind("CTRL", "RightArrow", act.SendString("\x1b\x66"))
  -- ctrl+backspace / ctrl+delete -> delete word backward / forward
  bind("CTRL", "Backspace", act.SendString("\x17"))
  bind("CTRL", "Delete", act.SendString("\x1bd"))

  -- --- swallow unbound ctrl+shift chords -------------------------------------
  for _, key in ipairs(NOP_CTRL_SHIFT) do
    bind("CTRL|SHIFT", key, act.Nop)
  end
end

return M
