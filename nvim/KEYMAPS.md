# Keymaps

Every custom keymap and behavior change in this config. Update this file in the same commit as any keymap change. It is the source for the interactive guide.

Leader is `<Space>`. Press it and wait, and which-key lists what follows.

## Changes to stock Vim behavior

These keys do something different from what `:Tutor`, vim-be-good or any Vim tutorial describes.

| Keys | Mode | Stock Vim | This config | Defined in |
|---|---|---|---|---|
| `y`, `p` | n, x | use the unnamed register | use the macOS clipboard (`clipboard=unnamedplus`) | `lua/config/options.lua` |
| `d`, `D`, `c`, `C`, `x`, `s` | n, x | delete and save the text to the register | delete into the black-hole register, clipboard untouched | `lua/config/remap.lua` |
| `<leader>x{motion}` | n, x | none | cut: delete and copy to clipboard (`<leader>xiw`, visual `<leader>x`) | `lua/config/remap.lua` |
| `<leader>xx` | n | none | cut line | `lua/config/remap.lua` |
| `<leader>X` | n | none | cut to end of line | `lua/config/remap.lua` |
| `p`, `P` | n | `p` puts after the cursor or below the line, `P` before or above | swapped: `p` puts before or above, `P` after or below | `lua/config/remap.lua` |
| `{count}j`, `{count}k` | n, x | move, not recorded as a jump | counts above 1 are added to the jumplist, so `<C-o>` returns to the start | `lua/config/remap.lua` |
| `<C-p>` | n | line up | find files (fff) | `after/plugin/fff.lua` |
| `<C-e>` | n | scroll down one line | harpoon menu | `after/plugin/harpoon.lua` |
| `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>`, `zt`, `zz`, `zb` | n, x | jump instantly | same motion, animated (neoscroll) | `after/plugin/neoscroll.lua` |
| `-` | n | line up, first non-blank | open parent directory (oil) | `after/plugin/oil.lua` |
| `hjkl` repeats | n | move | blocked by hardtime after a few presses | `after/plugin/trainers.lua` |
| arrow keys | n, x, o, i | move | disabled by hardtime (mouse and trackpad scrolling still work) | `after/plugin/trainers.lua` |

Consequences of the delete change: `ddp` no longer swaps lines and `xp` no longer swaps characters. Move text with `<leader>xx` then `p`. In visual mode `p` replaces the selection and copies the replaced text, while `P` keeps the clipboard.

## Project and files

| Keys | Mode | Action | Defined in |
|---|---|---|---|
| `<C-p>`, `<leader>pf` | n | find files (fff, frecency ranked) | `after/plugin/fff.lua` |
| `<leader>ps` | n | grep project (fff) | `after/plugin/fff.lua` |
| `<leader>pw` | n, x | grep word under cursor or selection (fff) | `after/plugin/fff.lua` |
| `<C-l>` | fff picker | send matches (or the `<Tab>`-marked ones) to quickfix, then `]q` / `[q` walk them | `after/plugin/fff.lua` |
| `<leader>pv`, `-` | n | file explorer (oil), edit the listing then `:w` to apply | `lua/config/remap.lua`, `after/plugin/oil.lua` |
| `<leader>a` | n | pin current file to harpoon | `after/plugin/harpoon.lua` |
| `<C-e>` | n | harpoon list, reorder or delete lines to edit it | `after/plugin/harpoon.lua` |
| `<leader>1` to `<leader>4` | n | jump to harpoon slot | `after/plugin/harpoon.lua` |
| `<leader>o` | n | append line at end of file and insert | `init.lua` |

## Telescope

| Keys | Action |
|---|---|
| `<leader>fh` | help tags |
| `<leader>fk` | keymaps |
| `<leader>fd` | diagnostics |
| `<leader>fs` | workspace symbols |
| `<leader>fb` | buffers |
| `<leader>fr` | resume last picker |

All in `after/plugin/telescope.lua`.

## LSP

Neovim 0.12 defaults, not remapped. Active in any buffer with a language server (gopls, vtsls, lua_ls).

| Keys | Mode | Action |
|---|---|---|
| `K` | n | hover docs |
| `grn` | n | rename |
| `gra` | n, x | code action |
| `grr` | n | references |
| `gri` | n | implementation |
| `grt` | n | type definition |
| `grx` | n | run code lens (Go: run test, go mod tidy, go generate) |
| `gO` | n | document symbols |
| `<C-]>` | n | go to definition, `<C-o>` jumps back |
| `<C-s>` | i | signature help |
| `]d`, `[d` | n | next, previous diagnostic |
| `<leader>uh` | n | toggle inlay hints (custom, `after/plugin/lsp.lua`) |

## Completion

Keys follow VSCode. `<Tab>` tries each action in order: accept the menu item, jump to the next snippet placeholder, insert a tab.

| Keys | Mode | Action | Defined in |
|---|---|---|---|
| `<Tab>` | i | accept menu item, else next snippet placeholder, else tab | `after/plugin/blink.lua` |
| `<CR>` | i | accept menu item, else newline | blink enter preset |
| `<Up>`, `<Down>` | i | previous, next item (blocked by hardtime when no menu is open) | blink enter preset |
| `<C-n>`, `<C-p>` | i | next, previous item | blink enter preset |
| `<C-y>` | i | accept item | `after/plugin/blink.lua` |
| `<C-space>` | i | open completion menu | blink enter preset |
| `<C-e>` | i | close menu | blink enter preset |
| `<C-b>`, `<C-f>` | i | scroll docs popup | blink enter preset |
| `<C-k>` | i | signature help | blink enter preset |
| `<S-Tab>` | i | previous snippet placeholder | blink enter preset |

## Treesitter text objects

Use after an operator (`d`, `c`, `y`, `<leader>x`) or in visual mode. Defined in `after/plugin/textobjects.lua`.

| Keys | Selects |
|---|---|
| `af`, `if` | around, inside function |
| `ac`, `ic` | around, inside class or type |
| `aa`, `ia` | around, inside parameter |
| `]f`, `[f` | move to next, previous function start |

## Tests

Defined in `after/plugin/neotest.lua`.

| Keys | Action |
|---|---|
| `<leader>tt` | run nearest test |
| `<leader>tf` | run tests in file |
| `<leader>tl` | rerun last test |
| `<leader>td` | debug nearest test |
| `<leader>ts` | toggle test summary |
| `<leader>to` | open test output |

## Debugger

Defined in `after/plugin/dap.lua`.

| Keys | Action |
|---|---|
| `<F5>` | start or continue |
| `<F10>` | step over |
| `<F11>` | step into |
| `<F12>` | step out |
| `<leader>db` | toggle breakpoint |
| `<leader>dB` | conditional breakpoint |
| `<leader>du` | toggle debug panel |
| `<leader>dt` | debug nearest Go test |

## Git

| Keys | Action | Defined in |
|---|---|---|
| `]c`, `[c` | next, previous hunk | `after/plugin/gitsigns.lua` |
| `<leader>hp` | preview hunk | `after/plugin/gitsigns.lua` |
| `<leader>hr` | reset hunk | `after/plugin/gitsigns.lua` |
| `<leader>hb` | blame line | `after/plugin/gitsigns.lua` |
| `<leader>hd` | diff against index | `after/plugin/gitsigns.lua` |
| `<leader>gg` | neogit status | `after/plugin/neogit.lua` |
| `<leader>gd` | diffview of working tree | `after/plugin/neogit.lua` |
| `<leader>gh` | history of current file | `after/plugin/neogit.lua` |

## AI chat

Defined in `after/plugin/codecompanion.lua`.

| Keys | Mode | Action |
|---|---|---|
| `<leader>cc` | n | toggle Claude Code chat |
| `<leader>ca` | n | actions menu |
| `<leader>ca` | x | add selection to chat |

## UI toggles

| Keys | Action | Defined in |
|---|---|---|
| `<leader>uh` | inlay hints | `after/plugin/lsp.lua` |
| `<leader>uH` | hardtime | `after/plugin/trainers.lua` |
| `<leader>up` | precognition motion hints | `after/plugin/trainers.lua` |

## Terminal escape sequences

| Sequence | Mode | Action | Defined in |
|---|---|---|---|
| `<Esc>[25;5~` | v | yank selection to clipboard, sent by a terminal key chord | `init.lua` |
