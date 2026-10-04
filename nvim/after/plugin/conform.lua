-- conform: format on save. Go runs goimports then gofumpt, web files use
-- prettier, Lua uses stylua. Filetypes without an entry fall back to the LSP.
local FORMAT_TIMEOUT_MS = 1000
local PRETTIER_FILETYPES = {
  "typescript",
  "typescriptreact",
  "javascript",
  "javascriptreact",
  "json",
  "css",
  "html",
  "yaml",
  "markdown",
}

local formatters_by_ft = {
  go = { "goimports", "gofumpt" },
  lua = { "stylua" },
}
for _, ft in ipairs(PRETTIER_FILETYPES) do
  formatters_by_ft[ft] = { "prettier" }
end

require("conform").setup({
  formatters_by_ft = formatters_by_ft,
  format_on_save = { timeout_ms = FORMAT_TIMEOUT_MS, lsp_format = "fallback" },
})
