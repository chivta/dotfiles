-- Debugger: nvim-dap core, nvim-dap-go for delve (dlv from mason), dap-view
-- panel that opens with a session and closes when it ends. Keymaps: F5
-- continue, F10 step over, F11 step into, F12 step out, <leader>db toggle
-- breakpoint, <leader>dB conditional breakpoint, <leader>du toggle panel,
-- <leader>dt debug nearest Go test.
local dap = require("dap")
local dap_go = require("dap-go")
local dap_view = require("dap-view")

dap_go.setup()
dap_view.setup({ auto_toggle = true })

vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug continue" })
vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug step over" })
vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug step into" })
vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug step out" })
vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
vim.keymap.set("n", "<leader>dB", function()
  dap.set_breakpoint(vim.fn.input("Condition: "))
end, { desc = "Conditional breakpoint" })
vim.keymap.set("n", "<leader>du", dap_view.toggle, { desc = "Toggle debug panel" })
vim.keymap.set("n", "<leader>dt", dap_go.debug_test, { desc = "Debug nearest Go test" })
