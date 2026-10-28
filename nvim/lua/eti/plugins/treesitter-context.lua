-- Pins the enclosing function/class header at the top of the window while you scroll.
return {
  "nvim-treesitter/nvim-treesitter-context",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    max_lines = 1, -- a single line: just the outermost class/function
    multiwindow = true, -- keep it in the code window when focus moves to another split (Claude panel)
    -- follow the top of the screen, not the cursor (like VS Code's sticky scroll):
    -- moving around what's on screen doesn't change the header
    mode = "topline",
    trim_scope = "inner", -- when nested, drop the innermost headers first, keeping the big structure
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
