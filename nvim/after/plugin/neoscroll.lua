-- neoscroll: animates scroll commands so the eye can follow the jump. Keymaps:
-- <C-u>/<C-d> half page, <C-b>/<C-f> full page, zt/zz/zb reposition. <C-e> and
-- <C-y> are left out because <C-e> is the harpoon menu.
local SMOOTH_KEYS = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "zt", "zz", "zb" }

require("neoscroll").setup({ mappings = SMOOTH_KEYS })
