-- macOS. MOD is cmd, so wezterm.lua's MOD+X is cmd+X and MOD_SHIFT+X is
-- cmd+shift+X. Karabiner remaps cmd+q to ctrl+q inside WezTerm and keeps shift,
-- so prevtab's toggle also needs ctrl+q here (wezterm.lua binds cmd+q) and its
-- walk goes on ctrl+shift+q, same keys as in the browser.
local wezterm = require("wezterm")
local act = wezterm.action

local M = {
  MOD = "CMD",
  MOD_SHIFT = "CMD|SHIFT",
}

local FONT_SIZE = 13.0

-- Apps that turn on the kitty keyboard protocol (Claude Code, neovim, helix)
-- ask WezTerm to report every key, so an unbound cmd chord arrives at the app
-- as a literal CSI-u sequence and lands in the input buffer as garbage, e.g.
-- cmd+shift+v -> CSI 118 ; 10 u, shown as "118;10u".
-- Nop swallows the event: neither WezTerm nor the app sees it. (Unbinding with
-- DisableDefaultAssignment would do the opposite - that is what leaks the
-- sequence.) Chords already bound above or by WezTerm's defaults are
-- deliberately absent, except the ones the user discarded on purpose in kitty.
local NOP_CMD = {
  "a", "b", "e", "g", "i", "j", "o", "p", "s", "u", "x", "y", "z",
  "[", "]", "\\", ";", "'", ".", "/",
  "Tab", "Space", "Escape", "Insert",
  "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
}
local NOP_CMD_SHIFT = {
  "a", "e", "g", "h", "j", "k", "l", "n", "o", "p", "q", "r", "s", "t", "u",
  "v", "x", "y", "z",
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
  ",", ".", ";", "'", "\\",
  "UpArrow", "DownArrow", "Home", "End", "PageUp", "PageDown", "Backspace",
  "Delete", "Tab", "Space", "Escape", "Insert",
  "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
}

function M.apply(config, shared)
  local bind = shared.bind

  config.font_size = FONT_SIZE

  bind("CTRL", "phys:Q", shared.prevtab.previous)
  bind("CTRL|SHIFT", "phys:Q", shared.prevtab.walk)
  bind("CMD|SHIFT", "phys:D", act.SplitVertical({ domain = "CurrentPaneDomain" }))
  bind("CMD|SHIFT", "c", shared.copy_last_output)

  -- --- mac-style line editing ------------------------------------------------
  -- jump to beginning and end of line
  bind("CMD", "LeftArrow", act.SendString("\x01"))
  bind("CMD", "RightArrow", act.SendString("\x05"))
  -- Cmd+Backspace -> delete to start of line (sends Ctrl+U)
  bind("CMD", "Backspace", act.SendString("\x15"))
  -- Cmd+Delete -> delete to end of line (sends Ctrl+K)
  bind("CMD", "Delete", act.SendString("\x0b"))

  -- --- swallow unbound cmd chords --------------------------------------------
  for _, key in ipairs(NOP_CMD) do
    bind("CMD", key, act.Nop)
  end
  for _, key in ipairs(NOP_CMD_SHIFT) do
    bind("CMD|SHIFT", key, act.Nop)
  end
end

return M
