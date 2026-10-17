return {
  -- render headings, code blocks, tables and checkboxes inside the buffer
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown" },
    opts = {
      code = { width = "block", right_pad = 2 },
      heading = { sign = false },
    },
    keys = {
      {
        "<leader>mr",
        function()
          require("render-markdown").toggle()
        end,
        ft = "markdown",
        desc = "Toggle markdown rendering",
      },
    },
  },
}
