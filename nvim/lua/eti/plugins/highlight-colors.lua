return {
  "brenoprata10/nvim-highlight-colors",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    render = "virtual", -- show the color next to the value, don't recolor the text
    enable_tailwind = true,
  },
}
