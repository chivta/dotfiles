-- nvim-lint: runs golangci-lint (v2, reads the repo's .golangci.yml) on save
-- and shows results as diagnostics.
local lint = require("lint")

lint.linters_by_ft = {
  go = { "golangcilint" },
}

vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("Lint", { clear = true }),
  callback = function()
    lint.try_lint()
  end,
})
