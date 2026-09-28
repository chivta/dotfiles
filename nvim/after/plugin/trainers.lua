-- Vim motion trainers. hardtime blocks repeated hjkl and suggests better
-- motions (on by default), precognition shows motion hints in the gutter and
-- buffer (hidden until toggled), vim-be-good is the :VimBeGood game.
-- Keymaps: <leader>uH toggle hardtime, <leader>up toggle precognition.
require("hardtime").setup()
require("precognition").setup({ startVisible = false })

vim.keymap.set("n", "<leader>uH", "<cmd>Hardtime toggle<cr>", { desc = "Toggle hardtime" })
vim.keymap.set("n", "<leader>up", function() require("precognition").toggle() end, { desc = "Toggle precognition" })
