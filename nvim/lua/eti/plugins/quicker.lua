-- Editable quickfix list: <C-q> in a telescope picker (live grep, references, ...)
-- sends the results here. Edit the lines like a normal buffer and :w writes the
-- changes into every file. > / < show / hide a few lines of context around each result.
local function half()
  return { focus = true, height = math.floor(vim.o.lines / 2) }
end

-- every mention of the word under the cursor (or the selection) in the project,
-- whole words only, .gitignore'd files skipped, straight into the list
local function word_to_list()
  local word
  if vim.fn.mode():find("[vV]") then
    word = table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos(".")), "\n")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
  else
    word = vim.fn.expand("<cword>")
  end
  if word == "" then
    return
  end
  local out = vim.fn.systemlist({ "rg", "--vimgrep", "--fixed-strings", "--word-regexp", "--", word })
  if #out == 0 then
    return vim.notify("No mentions of " .. word, vim.log.levels.WARN)
  end
  vim.fn.setqflist({}, " ", { title = word, lines = out, efm = "%f:%l:%c:%m" })
  require("quicker").open(half())
end

-- moving through the list shows each result in the file window, focus stays in
-- the list (like <CR> without leaving). Context lines from > preview too.
local function preview_under_cursor(qfwin)
  local item = vim.fn.getqflist()[vim.api.nvim_win_get_cursor(qfwin)[1]]
  if not item or item.bufnr == 0 then
    return
  end
  -- the window <CR> would use: the previous one, else the first normal window
  local target = vim.fn.win_getid(vim.fn.winnr("#"))
  local function usable(win)
    if win == 0 or win == qfwin or vim.api.nvim_win_get_config(win).relative ~= "" then
      return false
    end
    local bt = vim.bo[vim.api.nvim_win_get_buf(win)].buftype
    return bt == "" or bt == "acwrite"
  end
  if not usable(target) then
    target = vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(usable)
    if not target then
      return
    end
  end
  -- :buffer, not nvim_win_set_buf: a first load needs the full autocmds
  -- (filetype, treesitter, LSP attach), same as opening it from the list.
  -- quicker may have loaded it already (for highlights) with no filetype set.
  vim.api.nvim_win_call(target, function()
    vim.cmd.buffer(item.bufnr)
    if vim.bo.filetype == "" then
      vim.cmd("filetype detect")
    end
  end)
  local lnum = math.min(math.max(item.lnum, 1), vim.api.nvim_buf_line_count(item.bufnr))
  vim.api.nvim_win_set_cursor(target, { lnum, math.max(item.col - 1, 0) })
  vim.api.nvim_win_call(target, function() vim.cmd("normal! zz") end)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(ev)
    local last
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = vim.api.nvim_create_augroup("qf_follow_" .. ev.buf, { clear = true }),
      buffer = ev.buf,
      callback = function()
        local win = vim.api.nvim_get_current_win()
        if vim.fn.win_gettype(win) ~= "quickfix" then
          return -- location lists keep the default behaviour
        end
        local line = vim.api.nvim_win_get_cursor(win)[1]
        if line ~= last then
          last = line
          preview_under_cursor(win)
        end
      end,
    })
  end,
})

return {
  "stevearc/quicker.nvim",
  ft = "qf",
  keys = {
    {
      "<leader>xx",
      function() require("quicker").toggle(half()) end,
      desc = "Toggle the editable quickfix list (half the screen)",
    },
    { "<leader>w", word_to_list, mode = { "n", "x" }, desc = "Word under cursor: every mention into the list" },
  },
  opts = {
    keys = {
      {
        ">",
        function() require("quicker").expand({ before = 2, after = 2, add_to_existing = true }) end,
        desc = "Show context around results",
      },
      { "<", function() require("quicker").collapse() end, desc = "Hide context" },
      { "q", function() require("quicker").close() end, desc = "Close the list" },
    },
  },
}
