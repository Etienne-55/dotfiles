-- Pins the enclosing function/class header at the top of the window while you scroll.
return {
  "nvim-treesitter/nvim-treesitter-context",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    max_lines = 3, -- never take more than 3 lines of the window
    trim_scope = "outer", -- when nested too deep, drop the outermost headers first
  },
  keys = {
    -- [c is taken by diff hunks, so jump to the context line with [x
    {
      "[x",
      function()
        require("treesitter-context").go_to_context(vim.v.count1)
      end,
      desc = "Jump to treesitter context",
    },
    { "<leader>tc", "<cmd>TSContext toggle<CR>", desc = "Toggle treesitter context" },
  },
}
