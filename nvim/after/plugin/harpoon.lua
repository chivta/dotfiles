-- harpoon2: a short per-project list of pinned files. Keymaps: <leader>a pin
-- current file, <C-e> edit the list, <leader>1..4 jump to slot 1..4.
local SLOTS = 4

local harpoon = require("harpoon")
harpoon:setup()

vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "Harpoon file" })
vim.keymap.set("n", "<C-e>", function()
  harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = "Harpoon menu" })

for i = 1, SLOTS do
  vim.keymap.set("n", "<leader>" .. i, function() harpoon:list():select(i) end, { desc = "Harpoon file " .. i })
end
