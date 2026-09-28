-- LSP: mason installs the binaries, nvim-lspconfig ships server definitions
-- (lsp/*.lua on the runtimepath), overrides live in this config's lsp/ dir.
-- Keymaps are the 0.12 defaults (grn, gra, grr, gri, grt, grx, gO, K) plus
-- <leader>uh to toggle inlay hints.
-- Copilot ghost text comes from the copilot LSP through built-in inline
-- completion: <C-l> accept, <C-g> next suggestion, <leader>ua toggle. Sign in
-- once with :LspCopilotSignIn.
local SERVERS = { "gopls", "vtsls", "lua_ls", "copilot" }

-- Mason package names, installed on startup when missing.
local TOOLS = {
  "gopls",
  "vtsls",
  "lua-language-server",
  "copilot-language-server",
  "delve",
  "gotestsum",
  "gofumpt",
  "goimports",
  "prettier",
  "stylua",
}

-- "prepend" puts mason's bin first on PATH so its gopls wins over ~/go/bin.
require("mason").setup({ PATH = "prepend" })

local registry = require("mason-registry")
registry.refresh(function()
  for _, name in ipairs(TOOLS) do
    local pkg = registry.get_package(name)
    if not pkg:is_installed() and not pkg:is_installing() then
      pkg:install()
    end
  end
end)

vim.lsp.enable(SERVERS)

vim.keymap.set("n", "<leader>uh", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })

vim.lsp.inline_completion.enable()

vim.keymap.set("i", "<C-l>", vim.lsp.inline_completion.get, { desc = "Accept AI suggestion" })
vim.keymap.set("i", "<C-g>", vim.lsp.inline_completion.select, { desc = "Next AI suggestion" })
vim.keymap.set("n", "<leader>ua", function()
  vim.lsp.inline_completion.enable(not vim.lsp.inline_completion.is_enabled())
end, { desc = "Toggle AI suggestions" })
