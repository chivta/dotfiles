-- which-key: popup listing the keymaps that follow a pressed prefix. Every
-- keymap in this config carries a `desc`, which-key shows it. The groups below
-- label the prefixes from the keymap namespace in .claude/plan.md.
local GROUPS = {
  { "<leader>p", group = "project" },
  { "<leader>f", group = "find (telescope)" },
  { "<leader>h", group = "git hunk" },
  { "<leader>g", group = "git" },
  { "<leader>d", group = "debug" },
  { "<leader>t", group = "test" },
  { "<leader>c", group = "ai (codecompanion)" },
  { "<leader>u", group = "ui toggles" },
  { "gr", group = "lsp" },
}

require("which-key").setup({ spec = GROUPS })
