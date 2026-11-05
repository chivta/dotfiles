-- fff: fast file and grep picker with frecency. Keymaps: <C-p> and <leader>pf
-- find files, <leader>ps live grep, <leader>pw grep the word under cursor (or
-- the visual selection). Inside the picker <C-l> sends the matches (or the
-- <Tab>-marked ones) to quickfix, since kitty takes <C-q> for zitty's tab history.
local fff = require("fff")

fff.setup({ keymaps = { send_to_quickfix = "<C-l>" } })

vim.keymap.set("n", "<C-p>", fff.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>pf", fff.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>ps", fff.live_grep, { desc = "Grep project" })
vim.keymap.set({ "n", "x" }, "<leader>pw", fff.live_grep_under_cursor, { desc = "Grep word under cursor" })
