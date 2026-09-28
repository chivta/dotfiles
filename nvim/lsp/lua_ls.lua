-- lua_ls overrides: treat this config as Neovim Lua (LuaJIT, `vim` global,
-- runtime files on the library path).
return {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = {
        checkThirdParty = false,
        library = { vim.env.VIMRUNTIME },
      },
    },
  },
}
