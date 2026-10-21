-- Shared WezTerm config, ported from kitty/kitty.conf. The per-OS layer
-- (macos.lua / linux.lua) supplies the modifiers and the bindings that differ,
-- and is applied last so it can override anything below.
--
-- MOD is cmd on macOS and ctrl+shift on Linux, so MOD+X is cmd+X / ctrl+shift+X
-- and MOD_SHIFT+X is cmd+shift+X / ctrl+shift+X.
--
-- The phys: key prefix makes letter shortcuts match the physical key position,
-- so they also fire on the Ukrainian layout (MOD+phys:D == MOD+в).
--
-- Naming is swapped against kitty: kitty's vsplit (side by side) is WezTerm's
-- SplitHorizontal, kitty's hsplit (one above the other) is SplitVertical.

local wezterm = require("wezterm")
local act = wezterm.action

package.path = wezterm.config_dir .. "/?.lua;" .. package.path
local bell = require("bell")
local prevtab = require("prevtab")

local OS_LAYERS = {
  ["apple-darwin"] = "macos",
  ["linux"] = "linux",
}
local TAB_SHORTCUT_COUNT = 10
local DETACH_TAB = "tab"
local DETACH_WINDOW = "window"
-- ESC b / ESC f: readline's word back / forward
local WORD_BACK = "\x1b\x62"
local WORD_FORWARD = "\x1b\x66"

local function os_layer()
  for suffix, name in pairs(OS_LAYERS) do
    if wezterm.target_triple:find(suffix, 1, true) then
      return require(name)
    end
  end
  error("no WezTerm OS layer for " .. wezterm.target_triple)
end

-- Last command's output as plain text, taken from the OSC 133 semantic zones
-- the shell emits.
local copy_last_output = wezterm.action_callback(function(window, pane)
  local zones = pane:get_semantic_zones("Output")
  local last = zones[#zones]
  if last then
    window:copy_to_clipboard(pane:get_text_from_semantic_zone(last), "Clipboard")
  end
end)

local detach_pane = act.InputSelector({
  title = "Detach pane to",
  choices = {
    { id = DETACH_TAB, label = "New tab" },
    { id = DETACH_WINDOW, label = "New window" },
  },
  action = wezterm.action_callback(function(_, pane, id)
    if id == DETACH_TAB then
      pane:move_to_new_tab()
    elseif id == DETACH_WINDOW then
      pane:move_to_new_window()
    end
  end),
})

local layer = os_layer()
local config = wezterm.config_builder()
local keys = {}

local function bind(mods, key, action)
  table.insert(keys, { mods = mods, key = key, action = action })
end

-- Apps that turn on the kitty keyboard protocol (Claude Code, neovim, helix)
-- ask for every key to be reported; kitty always honours that, WezTerm only
-- with this on. It is also why an unbound chord reaches the app as a literal
-- CSI-u sequence (see the Nop lists in the OS layers).
config.enable_kitty_keyboard = true

-- Confirm closing a window or tab only when one of its panes runs a command;
-- idle shell prompts don't count (skip_close_confirmation_for_processes_named
-- lists the shells). Same as WezTerm's current default, pinned here.
config.window_close_confirmation = "AlwaysPrompt"

-- --- tabs --------------------------------------------------------------------
-- Only the first format-tab-title handler runs, so bell and prevtab share this
-- one. It fires on every tab switch, which update-status does not.
wezterm.on("format-tab-title", function(tab, tabs)
  prevtab.observe_tabs(tabs)
  return bell.format_tab_title(tab, tabs)
end)

-- Persistent bell: a program sets the bell_pending user var on its pane
-- (~/.claude/hooks/bell.sh does it when Claude Code finishes), bell.lua draws a
-- bell on that tab even while it's the active one and clears it when you
-- switch to another tab.
bell.setup()

for n = 1, TAB_SHORTCUT_COUNT do
  -- the tenth shortcut is the 0 key
  bind(layer.MOD, tostring(n % TAB_SHORTCUT_COUNT), act.ActivateTab(n - 1))
end
-- Tab history that matches the prevtab browser extension: toggle between the
-- two most recently used tabs, and walk further back (bound in macos.lua). See
-- prevtab.lua.
prevtab.setup()
bind(layer.MOD, "phys:Q", prevtab.previous)

-- --- splits and panes --------------------------------------------------------
bind(layer.MOD, "phys:D", act.SplitHorizontal({ domain = "CurrentPaneDomain" }))
-- confirm=true still skips the prompt when the pane just sits at a shell prompt
bind(layer.MOD, "phys:W", act.CloseCurrentPane({ confirm = true }))
bind(layer.MOD_SHIFT, "RightArrow", act.ActivatePaneDirection("Next"))
bind(layer.MOD_SHIFT, "LeftArrow", act.ActivatePaneDirection("Prev"))
-- kitty's layout_action rotate (flip a split between horizontal and vertical)
-- has no WezTerm equivalent.
bind(layer.MOD_SHIFT, "phys:F", act.RotatePanes("Clockwise"))
bind(layer.MOD_SHIFT, "phys:B", act.RotatePanes("CounterClockwise"))
bind(layer.MOD_SHIFT, "phys:M", detach_pane)

-- --- line editing ------------------------------------------------------------
-- alt+left / alt+right -> word back / forward
bind("ALT", "LeftArrow", act.SendString(WORD_BACK))
bind("ALT", "RightArrow", act.SendString(WORD_FORWARD))

-- Per-OS: modifiers, bindings that differ, and the Nop lists.
-- Must stay last so the OS file can override anything above.
layer.apply(config, {
  bind = bind,
  copy_last_output = copy_last_output,
  prevtab = prevtab,
})

config.keys = keys
return config
