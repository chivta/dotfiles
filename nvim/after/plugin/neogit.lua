-- neogit: magit-style git UI; diffs open in diffview (diffview-plus fork).
-- Keymaps: <leader>gg neogit status, <leader>gd diff working tree against
-- index, <leader>gh history of the current file.
local neogit = require("neogit")

neogit.setup({ integrations = { diffview = true } })

vim.keymap.set("n", "<leader>gg", function() neogit.open() end, { desc = "Neogit" })
vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Diffview open" })
vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history" })
