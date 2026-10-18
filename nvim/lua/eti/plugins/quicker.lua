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

return {
  "stevearc/quicker.nvim",
  ft = "qf",
  keys = {
    {
      "<leader>xx",
      function() require("quicker").toggle(half()) end,
      desc = "Toggle the editable quickfix list (half the screen)",
    },
    { "<leader>xw", word_to_list, mode = { "n", "x" }, desc = "Word under cursor: every mention into the list" },
  },
  opts = {
    keys = {
      {
        ">",
        function() require("quicker").expand({ before = 2, after = 2, add_to_existing = true }) end,
        desc = "Show context around results",
      },
      { "<", function() require("quicker").collapse() end, desc = "Hide context" },
    },
  },
}
