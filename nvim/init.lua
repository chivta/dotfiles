require("config")

-- fff ships a native binary: fetch (or build) it whenever vim.pack installs or
-- updates the plugin. Defined before vim.pack.add so the first install runs it.
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == "fff" and (kind == "install" or kind == "update") then
      if not ev.data.active then vim.cmd.packadd("fff") end
      require("fff.download").download_or_build_binary()
    end
  end,
})

vim.pack.add({
    "https://github.com/OXY2DEV/markview.nvim",
    -- master is archived and breaks on nvim 0.12 (query directives use the
    -- removed `all = false` mode); main is the maintained branch.
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/nvim-telescope/telescope.nvim",
    "https://github.com/rose-pine/neovim",
    "https://github.com/lewis6991/gitsigns.nvim",
    -- Maintained fork of sindrets/diffview.nvim (renamed diffview-plus.nvim),
    -- same `diffview` Lua module.
    "https://github.com/dlyongemallo/diffview-plus.nvim",
    -- Default branch is master; the repo has no main branch.
    "https://github.com/NeogitOrg/neogit",
    "https://github.com/folke/which-key.nvim",
    "https://github.com/neovim/nvim-lspconfig",
    "https://github.com/mason-org/mason.nvim",
    -- A release tag lets blink download its prebuilt Rust fuzzy matcher.
    { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.*") },
    "https://github.com/stevearc/conform.nvim",
    "https://github.com/mfussenegger/nvim-lint",
    { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },
    "https://github.com/dmtrKovalenko/fff",
    { src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },
    "https://github.com/stevearc/oil.nvim",
    "https://github.com/mfussenegger/nvim-dap",
    "https://github.com/leoluz/nvim-dap-go",
    { src = "https://github.com/igorlfs/nvim-dap-view", version = vim.version.range("1.*") },
    "https://github.com/nvim-neotest/nvim-nio",
    "https://github.com/nvim-neotest/neotest",
    { src = "https://github.com/fredrikaverpil/neotest-golang", version = vim.version.range("2.*") },
    "https://github.com/olimorris/codecompanion.nvim",
    "https://github.com/MunifTanjim/nui.nvim",
    "https://github.com/m4xshen/hardtime.nvim",
    "https://github.com/tris203/precognition.nvim",
    "https://github.com/ThePrimeagen/vim-be-good",
})


vim.keymap.set('v', '<Esc>[25;5~', '"+y', { noremap = true, silent = true })

vim.keymap.set("n", "<leader>o", "Go", { desc = "Append line at EOF and insert" })
