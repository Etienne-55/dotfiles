return {
  "MeanderingProgrammer/render-markdown.nvim",
  keys = {
    {
      "<leader>mr",
      function() require("render-markdown").toggle() end,
      ft = "markdown",
      desc = "Toggle markdown rendering",
    },
  },
}
