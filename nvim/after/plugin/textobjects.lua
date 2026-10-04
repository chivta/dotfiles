-- Treesitter textobjects (main branch): function-based API, keymaps are set by
-- hand. af/if function, ac/ic class, aa/ia parameter, ]f/[f next/previous
-- function start.
require("nvim-treesitter-textobjects").setup({
  select = { lookahead = true },
  move = { set_jumps = true },
})

local select = require("nvim-treesitter-textobjects.select")
local move = require("nvim-treesitter-textobjects.move")

local SELECTS = {
  { "af", "@function.outer", "Around function" },
  { "if", "@function.inner", "Inside function" },
  { "ac", "@class.outer", "Around class" },
  { "ic", "@class.inner", "Inside class" },
  { "aa", "@parameter.outer", "Around parameter" },
  { "ia", "@parameter.inner", "Inside parameter" },
}

for _, s in ipairs(SELECTS) do
  local lhs, query, desc = s[1], s[2], s[3]
  vim.keymap.set({ "x", "o" }, lhs, function()
    select.select_textobject(query, "textobjects")
  end, { desc = desc })
end

vim.keymap.set({ "n", "x", "o" }, "]f", function()
  move.goto_next_start("@function.outer", "textobjects")
end, { desc = "Next function start" })
vim.keymap.set({ "n", "x", "o" }, "[f", function()
  move.goto_previous_start("@function.outer", "textobjects")
end, { desc = "Previous function start" })
