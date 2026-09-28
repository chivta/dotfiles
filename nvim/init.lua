require("config")
vim.pack.add({
    "https://github.com/OXY2DEV/markview.nvim",
    -- master is archived and breaks on nvim 0.12 (query directives use the
    -- removed `all = false` mode); main is the maintained branch.
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/nvim-telescope/telescope.nvim",
    "https://github.com/rose-pine/neovim",
    "https://github.com/lewis6991/gitsigns.nvim",
    "https://github.com/sindrets/diffview.nvim",
    "https://github.com/folke/which-key.nvim",
})


vim.keymap.set('v', '<Esc>[25;5~', '"+y', { noremap = true, silent = true })

vim.opt.clipboard = ""   -- make sure nothing sets unnamedplus

vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("YankToClipboard", { clear = true }),
  callback = function()
    local ev = vim.v.event
    if ev.operator == "y" and ev.regname == "" then
      vim.fn.setreg("+", vim.fn.getreg('"'), vim.fn.getregtype('"'))
    end
  end,
})

vim.keymap.set("n", "<leader>o", "Go", { desc = "Append line at EOF and insert" })
