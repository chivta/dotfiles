-- Vim motion trainers. hardtime blocks repeated hjkl and suggests better
-- motions (on by default), precognition shows motion hints in the gutter and
-- buffer (hidden until toggled), vim-be-good is the :VimBeGood game.
-- Keymaps: <leader>uH toggle hardtime, <leader>up toggle precognition.

-- hardtime restricts <C-p> as a line motion by default, which would throttle
-- the fff file picker bound to it.
-- disable_mouse = false keeps trackpad scrolling; arrow keys stay blocked by
-- hardtime's default disabled_keys.
require("hardtime").setup({
  disable_mouse = false,
  restricted_keys = { ["<C-P>"] = false },
})
require("precognition").setup({ startVisible = false })

vim.keymap.set("n", "<leader>uH", "<cmd>Hardtime toggle<cr>", { desc = "Toggle hardtime" })
vim.keymap.set("n", "<leader>up", function() require("precognition").toggle() end, { desc = "Toggle precognition" })
