-- Flashes the text a normal-mode change touched (u, <C-r>, p, dd, ...) for a moment.
return {
  "tzachar/highlight-undo.nvim",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    duration = 300,
    ignored_filetypes = { "undotree", "NvimTree", "oil", "TelescopePrompt", "mason", "lazy" },
  },
}
