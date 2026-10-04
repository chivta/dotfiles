-- nvim-treesitter main branch: no configs.setup(), no auto_install. Parsers are
-- installed explicitly (needs the tree-sitter CLI + a C compiler) and
-- highlighting is turned on per buffer with vim.treesitter.start().
local parsers = {
  "c", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline",
  "go", "gomod", "gosum", "gowork",
  "typescript", "tsx", "javascript", "json", "yaml", "html", "css",
  "sql", "dockerfile", "bash",
}

require("nvim-treesitter").install(parsers)

vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    -- Neovim maps filetype -> parser itself; start() is a no-op without one.
    pcall(vim.treesitter.start, args.buf)
  end,
})
