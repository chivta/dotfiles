vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", "<cmd>Oil<cr>", { desc = "File explorer (oil)" })

-- Deletes and changes go to the black-hole register, so only yank and cut
-- touch the clipboard. <leader>x is the cut operator (<leader>xiw, <leader>xx,
-- <leader>X, visual <leader>x).
local BLACK_HOLE_KEYS = { "d", "D", "c", "C", "x", "s" }

for _, key in ipairs(BLACK_HOLE_KEYS) do
  vim.keymap.set({ "n", "x" }, key, '"_' .. key, { desc = "Delete without copying" })
end

vim.keymap.set({ "n", "x" }, "<leader>x", "d", { desc = "Cut" })
vim.keymap.set("n", "<leader>xx", "dd", { desc = "Cut line" })
vim.keymap.set("n", "<leader>X", "D", { desc = "Cut to end of line" })

-- p and P are swapped in normal mode: p puts above the current line (or
-- before the cursor for charwise text), P puts below (or after). Visual mode
-- keeps the stock keys.
vim.keymap.set("n", "p", "P", { desc = "Put before" })
vim.keymap.set("n", "P", "p", { desc = "Put after" })

-- j/k with a count above 1 (12j, 5k) are added to the jumplist, so <C-o>
-- returns to where they started. hardtime wraps these maps and calls them.
local function counted_jump(key)
  return function()
    return (vim.v.count > 1 and "m'" .. vim.v.count or "") .. key
  end
end
vim.keymap.set({ "n", "x" }, "j", counted_jump("j"), { expr = true, desc = "Down, counted moves are jumps" })
vim.keymap.set({ "n", "x" }, "k", counted_jump("k"), { expr = true, desc = "Up, counted moves are jumps" })
