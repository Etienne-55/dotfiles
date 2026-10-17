vim.g.mapleader = " "

vim.keymap.set("n", "<M-Up>", "<C-u>zz")
vim.keymap.set("n", "<leader>zz", function()
  require("zen-mode").toggle()
end, { desc = "Toggle Zen Mode" })
