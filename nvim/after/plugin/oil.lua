-- oil: edit directories as buffers, replaces netrw. Keymaps: `-` opens the
-- parent directory of the current file, <leader>pv (remap.lua) opens it too.
require("oil").setup({ default_file_explorer = true })

vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })
