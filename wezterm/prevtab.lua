-- Tab history with two movements, ported from kitty/prevtab.py, which is itself
-- ported from ~/Projects/prevtab (the Chrome extension) so ctrl+q /
-- ctrl+shift+q behave the same in WezTerm, kitty and the browser.
--
-- The state lives in wezterm.GLOBAL, which lasts until WezTerm quits and
-- survives config reloads.
--
-- previous toggles between the current tab and the one before it: each jump
-- promotes its target to the head of the list, so pressing it twice lands you
-- back where you started.
--
-- walk goes further back without touching the list. It starts at WALK_START
-- (skipping the tab previous is aimed at) and steps one deeper per press. The
-- next previous ends the walk: the tab the walk landed on is promoted as a
-- normal visit, then the toggle runs from there.
--
-- Tabs are ranked across all GUI windows, and jumping to a tab in another
-- window focuses it.
local wezterm = require("wezterm")

local M = {}

local MRU_LIMIT = 10
-- Positions in the mru list, which is 1-based here
local PREVIOUS = 2
local WALK_START = 3

-- State fields (a field that is nil is simply absent):
--   mru:     tab ids, newest first. Position 1 is where navigation is
--            measured from, which during a walk is the tab the walk started
--            at, not the visible tab.
--   cursor:  position in mru while walking back, nil when not walking.
--   pending: tab this module just activated. Its own focus events must not
--            count as a user switch. Cleared by the first event naming a
--            different tab.
local function load_state()
  local saved = wezterm.GLOBAL.prevtab
  local state = { mru = {} }
  if saved then
    for i = 1, #saved.mru do
      state.mru[i] = saved.mru[i]
    end
    state.cursor = saved.cursor
    state.pending = saved.pending
  end
  return state
end

local function save_state(state)
  wezterm.GLOBAL.prevtab = state
end

local function index_of(state, tab_id)
  for i, id in ipairs(state.mru) do
    if id == tab_id then
      return i
    end
  end
end

-- Moves a tab to the head of the list. Every caller clears the cursor first,
-- so this never has to keep a walk position valid.
local function promote(state, tab_id)
  local at = index_of(state, tab_id)
  if at then
    table.remove(state.mru, at)
  end
  table.insert(state.mru, 1, tab_id)
  while #state.mru > MRU_LIMIT do
    table.remove(state.mru)
  end
end

local function drop(state, tab_id)
  local at = index_of(state, tab_id)
  if not at then
    return
  end
  table.remove(state.mru, at)
  if state.cursor and at < state.cursor then
    state.cursor = state.cursor - 1
  end
end

-- WezTerm has no tab-closed event, so closed tabs are removed before every
-- use, and a dead entry never shifts the position a shortcut counts to.
local function prune_closed(state)
  local open = {}
  for _, window in ipairs(wezterm.mux.all_windows()) do
    for _, tab in ipairs(window:tabs()) do
      open[tab:tab_id()] = true
    end
  end
  for _, tab_id in ipairs({ table.unpack(state.mru) }) do
    if not open[tab_id] then
      drop(state, tab_id)
    end
  end
end

-- Ends a walk by promoting the tab it landed on, so the list measures from the
-- tab actually on screen rather than from where the walk began.
local function commit_walk(state)
  if not state.cursor then
    return
  end
  local landed = state.mru[state.cursor]
  state.cursor = nil
  if landed then
    promote(state, landed)
  end
end

-- A real tab switch by the user: it ends any walk and reorders the list.
local function record_visit(state, tab_id)
  if tab_id == state.pending then
    return
  end
  state.pending = nil
  prune_closed(state)
  commit_walk(state)
  promote(state, tab_id)
end

local function go_to(state, tab_id)
  -- Saved before switching: the focus events arrive as soon as we return.
  state.pending = tab_id
  save_state(state)
  local tab = wezterm.mux.get_tab(tab_id)
  tab:activate()
  local gui_window = tab:window():gui_window()
  if gui_window then
    gui_window:focus()
  end
end

local function switch_previous()
  local state = load_state()
  prune_closed(state)
  commit_walk(state)
  if #state.mru < PREVIOUS then
    save_state(state)
    return
  end
  local target = state.mru[PREVIOUS]
  promote(state, target)
  go_to(state, target)
end

local function walk()
  local state = load_state()
  prune_closed(state)
  local step = state.cursor and state.cursor + 1 or WALK_START
  if step > #state.mru then
    -- already at the oldest tab we track
    save_state(state)
    return
  end
  state.cursor = step
  go_to(state, state.mru[step])
end

M.previous = wezterm.action_callback(switch_previous)
M.walk = wezterm.action_callback(walk)

-- Switching GUI windows counts the same way as switching tabs, for the tab
-- shown there.
function M.setup()
  wezterm.on("window-focus-changed", function(window, pane)
    if not window:is_focused() then
      return
    end
    local tab = pane:tab()
    if tab then
      local state = load_state()
      record_visit(state, tab:tab_id())
      save_state(state)
    end
  end)
end

-- Tab switches are seen from the tab-bar repaint (see wezterm.lua), the one
-- hook that fires on any of them, wezterm cli and the Lua API included. A
-- window's first repaint only seeds its active tab: its visit comes from the
-- focus event.
function M.observe_tabs(tabs)
  if not wezterm.GLOBAL.prevtab_active then
    wezterm.GLOBAL.prevtab_active = {}
  end
  local active = wezterm.GLOBAL.prevtab_active
  for _, tab in ipairs(tabs) do
    local window_key = tostring(tab.window_id)
    local last = active[window_key]
    if tab.is_active and last ~= tab.tab_id then
      active[window_key] = tab.tab_id
      if last then
        local state = load_state()
        record_visit(state, tab.tab_id)
        save_state(state)
      end
    end
  end
end

return M
