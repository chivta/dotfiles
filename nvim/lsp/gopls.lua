-- gopls overrides, merged over nvim-lspconfig's lsp/gopls.lua defaults.
-- Code lenses run with `grx` (vim.lsp.codelens.run) in 0.12.
return {
  settings = {
    gopls = {
      gofumpt = true,
      staticcheck = true,
      usePlaceholders = true,
      completeUnimported = true,
      -- gc_details is no longer a codelens in gopls 0.17+, so it stays off.
      codelenses = {
        test = true,
        tidy = true,
        generate = true,
      },
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        ignoredError = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
}
