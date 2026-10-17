-- relativenumber is window-local and remembered per buffer, so a plain toggle gets
-- undone when switching files; keep it global and re-apply it to every file window
local function is_file_win(win)
  return vim.api.nvim_win_get_config(win).relative == "" and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
end

local function set_relativenumber(value)
  vim.o.relativenumber = value
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if is_file_win(win) then vim.wo[win].relativenumber = value end
  end
end

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = vim.api.nvim_create_augroup("eti_relativenumber", { clear = true }),
  callback = function()
    local win = vim.api.nvim_get_current_win()
    if is_file_win(win) then vim.wo[win].relativenumber = vim.go.relativenumber end
  end,
})

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    input = { enabled = true }, -- nicer vim.ui.input (replaces dressing.nvim)
    picker = { enabled = true, ui_select = true }, -- nicer vim.ui.select (replaces dressing.nvim)
    lazygit = { enabled = true }, -- floating lazygit window
  },
  keys = {
    {
      "<leader>gg",
      function()
        -- save first: lazygit sees what's in nvim, and clean buffers get reloaded
        -- by core/autoreload when lazygit discards/undoes (dirty ones are skipped)
        vim.cmd("silent! wall")
        Snacks.lazygit()
      end,
      desc = "Save all and open lazygit",
    },
    { "<leader>rf", function() Snacks.rename.rename_file() end, desc = "Rename current file (LSP-aware)" },
    {
      "<leader>tn",
      function()
        Snacks.toggle.new({ name = "Relative Number", get = function() return vim.go.relativenumber end, set = set_relativenumber }):toggle()
      end,
      desc = "Toggle relative line numbers (all windows)",
    },
  },
}
