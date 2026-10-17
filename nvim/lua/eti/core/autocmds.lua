-- briefly highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("eti_yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})
