-- glow preview in a split on the right, re-rendered on every save
local previews = {} -- markdown buf -> preview win

local function render(src, win)
  local width = vim.api.nvim_win_get_width(win) - 2
  local file = vim.api.nvim_buf_get_name(src)
  local out = vim.system({ "glow", "-s", "dark", "-w", tostring(width), file }):wait().stdout or ""
  local old = vim.api.nvim_win_get_buf(win)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_chan_send(vim.api.nvim_open_term(buf, {}), (out:gsub("\n", "\r\n")))
  vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf, desc = "Close glow preview" })
  if old ~= src and vim.api.nvim_buf_is_valid(old) then
    vim.api.nvim_buf_delete(old, { force = true })
  end
end

local function toggle_preview()
  local src = vim.api.nvim_get_current_buf()
  local win = previews[src]
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    previews[src] = nil
    return
  end
  local cur = vim.api.nvim_get_current_win()
  vim.cmd("botright vsplit")
  win = vim.api.nvim_get_current_win()
  vim.wo[win].number, vim.wo[win].relativenumber, vim.wo[win].signcolumn = false, false, "no"
  previews[src] = win
  vim.api.nvim_set_current_win(cur)
  render(src, win)
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("GlowPreview" .. src, { clear = true }),
    buffer = src,
    callback = function()
      if not vim.api.nvim_win_is_valid(win) then
        return true -- preview closed, drop the autocmd
      end
      render(src, win)
    end,
  })
end

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
      { "<leader>md", toggle_preview, ft = "markdown", desc = "Toggle glow preview on the right" },
    },
  },
}
