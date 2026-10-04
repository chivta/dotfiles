-- telescope: pickers for everything fff does not cover. Keymaps: <leader>fh
-- help, <leader>fk keymaps, <leader>fd diagnostics, <leader>fs workspace
-- symbols, <leader>fr resume last picker, <leader>fb buffers.
local builtin = require("telescope.builtin")

vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Find help" })
vim.keymap.set("n", "<leader>fk", builtin.keymaps, { desc = "Find keymaps" })
vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "Find diagnostics" })
vim.keymap.set("n", "<leader>fs", builtin.lsp_dynamic_workspace_symbols, { desc = "Find workspace symbols" })
vim.keymap.set("n", "<leader>fr", builtin.resume, { desc = "Resume last picker" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
