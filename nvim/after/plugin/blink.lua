-- blink.cmp: completion popup fed by LSP, paths, snippets and buffer words.
-- Keys follow VSCode on top of the "enter" preset: <Tab> or <CR> accepts the
-- menu item, <Up>/<Down> select, <C-space> opens, <C-e> closes. With no menu
-- open, <Tab> accepts the minuet ghost text, then jumps snippet placeholders,
-- then inserts a tab. Vim keys stay too: <C-n>/<C-p> select, <C-y> accept,
-- <C-b>/<C-f> scroll docs, <C-k> signature help. LSP capabilities are picked
-- up automatically through vim.lsp.config on 0.11+.
require("blink.cmp").setup({
  keymap = {
    preset = "enter",
    ["<Tab>"] = {
      function(cmp)
        if cmp.snippet_active() then
          return cmp.accept()
        end
        return cmp.select_and_accept()
      end,
      function()
        local virtualtext = require("minuet.virtualtext").action
        if virtualtext.is_visible() then
          virtualtext.accept()
          return true
        end
      end,
      "snippet_forward",
      "fallback",
    },
    ["<C-y>"] = { "select_and_accept", "fallback" },
  },
  completion = { documentation = { auto_show = true } },
  signature = { enabled = true },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
  fuzzy = { implementation = "prefer_rust_with_warning" },
})
