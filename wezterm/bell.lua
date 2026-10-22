-- Persistent "bell" marker for tabs, ported from kitty's tab_bar.py + watcher.py.
-- A program sets the bell_pending user var on its pane, user-var-changed
-- records it, format_tab_title draws it, and the mark is cleared when the user
-- leaves the tab.
--
-- A pane's user var can't be unset from Lua, so the marks live in
-- wezterm.GLOBAL, keyed by tab id; they survive config reloads.
local wezterm = require("wezterm")

local M = {}

local BELL = "🔔 "
local VAR = "bell_pending"
local BELL_COLOR = "red"

-- GLOBAL tables are keyed by strings
local function key(id)
  return tostring(id)
end

local function marks()
  if not wezterm.GLOBAL.bell_marks then
    wezterm.GLOBAL.bell_marks = {}
  end
  return wezterm.GLOBAL.bell_marks
end

-- Active tab per window as of the last repaint
local function active_tabs()
  if not wezterm.GLOBAL.bell_active_tabs then
    wezterm.GLOBAL.bell_active_tabs = {}
  end
  return wezterm.GLOBAL.bell_active_tabs
end

-- Runs on every tab-bar repaint, which is the one hook that fires on any tab
-- switch (keys, mouse, wezterm cli). The previous active tab of the window is
-- cleared here rather than while drawing it, so it never paints a stale bell.
-- Still the active tab after a split change, app switch or OS window switch:
-- the mark stays.
local function clear_left_tabs(tabs)
  for _, tab in ipairs(tabs) do
    if tab.is_active then
      local last = active_tabs()[key(tab.window_id)]
      if last ~= tab.tab_id then
        active_tabs()[key(tab.window_id)] = tab.tab_id
        if last then
          marks()[key(last)] = nil
        end
      end
    end
  end
end

function M.setup()
  -- WezTerm repaints the tab bar after this handler returns, so the mark shows
  -- up immediately.
  wezterm.on("user-var-changed", function(_, pane, name)
    if name ~= VAR then
      return
    end
    local tab = pane:tab()
    if tab then
      marks()[key(tab:tab_id())] = true
    end
  end)
end

-- format-tab-title handler body. kitty's activity_symbol, secure_input_symbol
-- and progress percent have no WezTerm equivalent.
function M.format_tab_title(tab, tabs)
  clear_left_tabs(tabs)
  local title = tab.tab_title
  if title == "" then
    title = tab.active_pane.title
  end
  if not marks()[key(tab.tab_id)] then
    return title
  end
  return {
    { Foreground = { Color = BELL_COLOR } },
    { Text = BELL },
    "ResetAttributes",
    { Text = title },
  }
end

return M
