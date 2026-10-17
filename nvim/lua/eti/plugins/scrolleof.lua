return {
  "Aasim-A/scrollEOF.nvim",
  event = { "CursorMoved", "WinScrolled" },
  opts = {
    pattern = "*", -- Apply to all filetypes
    insert_mode = false, -- Disable in insert mode
  },
}
