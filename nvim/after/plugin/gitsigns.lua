-- VSCode-style git decorations: colored bars in the sign column for added,
-- changed and deleted lines, plus hunk navigation and preview.
require("gitsigns").setup({
  signs = {
    add          = { text = "┃" },
    change       = { text = "┃" },
    delete       = { text = "▁" },
    topdelete    = { text = "▔" },
    changedelete = { text = "~" },
    untracked    = { text = "┆" },
  },
  -- Keeps the gutter from collapsing when a file has no changes.
  signcolumn = true,
  on_attach = function(bufnr)
    local gs = require("gitsigns")
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map("n", "]c", function() gs.nav_hunk("next") end, "Next git hunk")
    map("n", "[c", function() gs.nav_hunk("prev") end, "Previous git hunk")
    map("n", "<leader>hp", gs.preview_hunk, "Preview git hunk")
    map("n", "<leader>hr", gs.reset_hunk, "Reset git hunk")
    map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
    map("n", "<leader>hd", gs.diffthis, "Diff against index")
  end,
})

-- rose-pine paints adds teal (#9ccfd8) and deletes rose (#eb6f92). Override with
-- saturated green/red so the gutter reads at a glance.
local GIT_ADD = "#2fd95b"
local GIT_DELETE = "#ff4d4d"

local function git_sign_colors()
  vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = GIT_ADD })
  vim.api.nvim_set_hl(0, "GitSignsUntracked", { fg = GIT_ADD })
  vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = GIT_DELETE })
  vim.api.nvim_set_hl(0, "GitSignsTopdelete", { fg = GIT_DELETE })
  vim.api.nvim_set_hl(0, "GitSignsChangedelete", { fg = GIT_DELETE })
end

-- Re-applied on every colorscheme load, since that resets the groups.
vim.api.nvim_create_autocmd("ColorScheme", { callback = git_sign_colors })
git_sign_colors()
