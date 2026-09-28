-- blink.cmp: completion popup fed by LSP, paths, snippets and buffer words.
-- Keymaps are the "default" preset: <C-space> open, <C-y> accept, <C-n>/<C-p>
-- select, <C-e> close, <C-k> signature help. LSP capabilities are picked up
-- automatically through vim.lsp.config on 0.11+.
require("blink.cmp").setup({
  keymap = { preset = "default" },
  completion = { documentation = { auto_show = true } },
  signature = { enabled = true },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
  fuzzy = { implementation = "prefer_rust_with_warning" },
})
