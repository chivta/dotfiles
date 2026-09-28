-- Editor options. Loaded from config/init.lua before any plugin.
local SCROLL_OFF = 8
local INDENT_WIDTH = 4
-- Milliseconds of idle before CursorHold fires and swap is written.
local UPDATE_TIME_MS = 250

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.termguicolors = true
opt.scrolloff = SCROLL_OFF

opt.undofile = true
opt.updatetime = UPDATE_TIME_MS
opt.confirm = true

opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"

opt.splitright = true
opt.splitbelow = true

-- Go buffers switch back to tabs via the bundled ftplugin.
opt.expandtab = true
opt.shiftwidth = INDENT_WIDTH
opt.tabstop = INDENT_WIDTH

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = true,
  float = { border = "rounded", source = true },
})
