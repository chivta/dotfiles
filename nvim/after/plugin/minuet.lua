-- minuet-ai: ghost-text completion from Mistral Codestral FIM, auto-triggered
-- in every filetype. Auth: get a free key at https://codestral.mistral.ai and
-- export CODESTRAL_API_KEY in the shell (not MISTRAL_API_KEY). Never put the
-- key in this file.
-- Keymaps: <Tab> accepts the suggestion (wired in blink.lua), insert <C-g>
-- next suggestion, <leader>ua toggle auto-trigger in the current buffer.
require("minuet").setup({
  provider = "codestral",
  provider_options = {
    codestral = {
      optional = { max_tokens = 256, stop = { "\n\n" } },
    },
  },
  virtualtext = {
    auto_trigger_ft = { "*" },
  },
})

local virtualtext = require("minuet.virtualtext").action

vim.keymap.set("i", "<C-g>", virtualtext.next, { desc = "Next AI suggestion" })
vim.keymap.set("n", "<leader>ua", virtualtext.toggle_auto_trigger, { desc = "Toggle AI suggestions" })
