-- codecompanion: AI chat inside Neovim. Chat runs Claude Code over ACP via the
-- `claude-agent-acp` binary (npm i -g @zed-industries/claude-agent-acp).
-- Auth: the agent reuses an existing `claude` login; if that fails, run
-- `claude setup-token` and export CLAUDE_CODE_OAUTH_TOKEN in the shell. Never
-- put the token in this file. Inline and cmd interactions still use HTTP
-- adapters and stay unconfigured.
-- Keymaps: <leader>cc toggle chat, <leader>ca actions, visual <leader>ca add
-- the selection to the chat.
require("codecompanion").setup({
  interactions = {
    chat = { adapter = "claude_code" },
  },
})

vim.keymap.set("n", "<leader>cc", "<cmd>CodeCompanionChat Toggle<cr>", { desc = "AI chat toggle" })
vim.keymap.set("n", "<leader>ca", "<cmd>CodeCompanionActions<cr>", { desc = "AI actions" })
vim.keymap.set("x", "<leader>ca", ":CodeCompanionChat Add<cr>", { desc = "AI add selection to chat" })
