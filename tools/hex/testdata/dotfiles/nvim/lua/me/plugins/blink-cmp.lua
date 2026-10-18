return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      preset = "none",
      ["<C-j>"] = { "select_next", "fallback" }, -- next suggestion
      ["<C-e>"] = { "hide", "fallback" },
    },
    cmdline = {
      keymap = {
        ["<Down>"] = { "select_next", "fallback" },
      },
    },
  },
}
