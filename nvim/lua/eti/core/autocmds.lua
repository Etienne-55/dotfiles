-- briefly highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("eti_yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- launched straight into a picker from the shell (`ff`, `fs`: `nvim "+Pick ..."`):
-- hide the normal-mode cursor until the picker's prompt takes insert mode. Otherwise
-- the shell's block cursor jumps to nvim's startup cursor at the top left, and
-- ghostty's cursor trail (ghostty/shaders/cursor_trail.glsl) smears across the screen.
-- The trail skips hidden and bar cursors, so hidden -> prompt bar draws nothing.
if vim.iter(vim.v.argv):any(function(a)
  return vim.startswith(a, "+Pick")
end) then
  local group = vim.api.nvim_create_augroup("eti_pick_cursor", { clear = true })
  local function hidden_hl() -- blend=100 hides the cursor in the TUI
    vim.api.nvim_set_hl(0, "PickHiddenCursor", { blend = 100, nocombine = true })
  end
  hidden_hl()
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = hidden_hl }) -- a colorscheme clears it
  local guicursor = vim.o.guicursor
  vim.o.guicursor = guicursor .. ",n:PickHiddenCursor"
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    once = true,
    callback = function()
      vim.o.guicursor = guicursor
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })
end
