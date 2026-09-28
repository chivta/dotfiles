-- neotest with the Go adapter. gotestsum (from mason) writes JSON to a file,
-- which avoids the stdout corruption `go test -json` suffers from. Debugging
-- goes through nvim-dap-go. Keymaps: <leader>tt nearest, <leader>tf file,
-- <leader>tl last, <leader>td debug nearest, <leader>ts summary, <leader>to
-- output of nearest.
local neotest = require("neotest")

neotest.setup({
  adapters = {
    require("neotest-golang")({ runner = "gotestsum" }),
  },
})

vim.keymap.set("n", "<leader>tt", function() neotest.run.run() end, { desc = "Test nearest" })
vim.keymap.set("n", "<leader>tf", function() neotest.run.run(vim.fn.expand("%")) end, { desc = "Test file" })
vim.keymap.set("n", "<leader>tl", function() neotest.run.run_last() end, { desc = "Test last" })
vim.keymap.set("n", "<leader>td", function() neotest.run.run({ strategy = "dap" }) end, { desc = "Debug nearest test" })
vim.keymap.set("n", "<leader>ts", function() neotest.summary.toggle() end, { desc = "Test summary" })
vim.keymap.set("n", "<leader>to", function() neotest.output.open() end, { desc = "Test output" })
