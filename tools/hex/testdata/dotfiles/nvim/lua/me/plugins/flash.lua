return {
  "folke/flash.nvim",
  keys = {
    { "z", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    { "<leader>c", nil, desc = "a group, not a binding" },
  },
}
