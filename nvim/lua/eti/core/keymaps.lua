vim.g.mapleader = " "

local keymap = vim.keymap

-- registers (primeagen style): d copies as usual, <leader>d deletes into the black hole
keymap.set({ "n", "v" }, "<leader>d", [["_d]]) -- delete without copying
keymap.set("x", "<leader>p", [["_dP]]) -- paste over selection, keep the register

-- move selected lines; in read-only buffers (Claude terminal, help...) keep the native
-- key, so selecting with J / K before a yank still works there
local function move_lines(key, cmd)
  keymap.set("x", key, function() return vim.bo.modifiable and cmd or key end, { expr = true, silent = true })
end
move_lines("J", ":m '>+1<CR>gv=gv") -- move selected lines down
move_lines("K", ":m '<-2<CR>gv=gv") -- move selected lines up
move_lines("<M-Down>", ":m '>+1<CR>gv=gv") -- same, with alt+arrows (plain arrows extend the selection)
move_lines("<M-Up>", ":m '<-2<CR>gv=gv")


-- half-page scroll keeps the cursor centered on screen
keymap.set({ "n", "x" }, "<C-d>", "<C-d>zz")
keymap.set({ "n", "x" }, "<C-u>", "<C-u>zz")
keymap.set({ "n", "x" }, "<C-Down>", "<C-d>zz") -- same, with ctrl+arrows
keymap.set({ "n", "x" }, "<C-Up>", "<C-u>zz")
-- alt+arrows too, but only in normal mode: in visual mode they move the selected lines (above)
keymap.set("n", "<M-Down>", "<C-d>zz")
keymap.set("n", "<M-Up>", "<C-u>zz")
-- page keys (fn+arrows on a mac, shift+arrows) would leave the cursor on the
-- top/bottom line; make them the same centered half-page scroll.
-- shift+arrows also flash the minimap (extras/minimap.lua)
keymap.set({ "n", "x" }, "<PageDown>", "<C-d>zz")
keymap.set({ "n", "x" }, "<PageUp>", "<C-u>zz")
local function scroll_with_minimap(key, scroll)
  keymap.set({ "n", "x" }, key, function()
    require("eti.extras.minimap").peek()
    return scroll
  end, { expr = true })
end
scroll_with_minimap("<S-Down>", "<C-d>zz")
scroll_with_minimap("<S-Up>", "<C-u>zz")

-- shift+9 / shift+0: previous/next line with a diagnostic (several on one line
-- count once), wrapping around; centered like the {/} hunk jumps, and flashes the
-- minimap. Set for every buffer so ( / ) never fall back to the sentence motion;
-- normal mode only, so d) / v) keep it.
local function jump_diagnostic_line(dir)
  local diags = vim.diagnostic.get(0)
  if #diags == 0 then
    return
  end
  local lines = {} -- line -> first column with a diagnostic on it
  for _, d in ipairs(diags) do
    lines[d.lnum] = math.min(lines[d.lnum] or math.huge, d.col)
  end
  local sorted = vim.tbl_keys(lines)
  table.sort(sorted)

  local cur = vim.api.nvim_win_get_cursor(0)[1] - 1
  local target = dir > 0 and sorted[1] or sorted[#sorted] -- wrap around
  for i = dir > 0 and 1 or #sorted, dir > 0 and #sorted or 1, dir do
    if (sorted[i] - cur) * dir > 0 then
      target = sorted[i]
      break
    end
  end

  vim.cmd("normal! m'") -- jumplist, like the built-in jumps
  vim.api.nvim_win_set_cursor(0, { target + 1, lines[target] })
  vim.cmd("normal! zz")
  -- after zz, so it sits next to the centered line. focus = false: pressed again
  -- before the old popup closes, open_float would move the cursor into it
  vim.diagnostic.open_float({ focus = false })
  require("eti.extras.minimap").peek()
end
keymap.set("n", "(", function() jump_diagnostic_line(-1) end, { desc = "Previous line with a diagnostic" })
keymap.set("n", ")", function() jump_diagnostic_line(1) end, { desc = "Next line with a diagnostic" })

-- search: <CR> on a / or ? search centers the match (n/N/*/# do too, in
-- plugins/hlslens); <Esc> clears the highlight.
-- Only from normal mode: in `c/foo<CR>` or <C-o>/ from insert mode the zz would be
-- typed into the buffer
vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = vim.api.nvim_create_augroup("eti_search_center", { clear = true }),
  pattern = { "/", "?" },
  callback = function()
    if vim.v.event.abort then
      return
    end
    vim.schedule(function()
      if vim.fn.mode() == "n" then
        vim.cmd("normal! zz")
      end
    end)
  end,
})
keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlighting" })

-- replace the word under the cursor (or the selection) in the whole file, asked in the same input
-- box as <leader>rn. Every match shows the new text live while typing (drawn over the buffer, which
-- only changes on <CR>); <Esc> cancels, and the cursor stays where it was either way
-- keeppatterns: n/N keep searching what they did before
local preview_ns = vim.api.nvim_create_namespace("eti_replace_preview")
local function replace_all(pattern, default)
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local view = vim.fn.winsaveview()
  -- \C: case-sensitive like the I flag below; matched per line, so a multi-line selection
  -- gets no preview but is still replaced
  local matches = vim.fn.matchbufline(buf, [[\C]] .. pattern, 1, "$")
  -- the preview hides each match and draws the new text in its place, on the cursor line too
  local wo = { conceallevel = vim.wo[win].conceallevel, concealcursor = vim.wo[win].concealcursor }
  vim.wo[win].conceallevel, vim.wo[win].concealcursor = 2, "nvic"

  local done = false -- set once answered: the matches' positions are stale after the replace
  local function preview(text)
    vim.api.nvim_buf_clear_namespace(buf, preview_ns, 0, -1)
    if done then
      return
    end
    for _, m in ipairs(matches) do
      vim.api.nvim_buf_set_extmark(buf, preview_ns, m.lnum - 1, m.byteidx, {
        end_col = m.byteidx + #m.text,
        conceal = "",
        virt_text = { { text, "IncSearch" } },
        virt_text_pos = "inline",
      })
    end
  end

  local function cleanup()
    done = true
    vim.api.nvim_buf_clear_namespace(buf, preview_ns, 0, -1)
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].conceallevel, vim.wo[win].concealcursor = wo.conceallevel, wo.concealcursor
    end
  end

  preview(default)
  local input = vim.ui.input({ prompt = "Replace with: ", default = default }, function(text)
    cleanup()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    vim.api.nvim_win_call(win, function()
      if text then
        vim.cmd("keeppatterns %s/" .. pattern .. "/" .. vim.fn.escape(text, [[/\&~]]) .. "/gIe")
      end
      vim.fn.winrestview(view)
    end)
  end)

  -- snacks returns its input window; follow what's typed in it, and clean up however it closes
  if type(input) == "table" and input.buf then
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      buffer = input.buf,
      callback = function()
        preview(input:text())
      end,
    })
    vim.api.nvim_create_autocmd({ "BufWipeout", "BufHidden" }, { buffer = input.buf, once = true, callback = cleanup })
  end
end
keymap.set("n", "<leader>s", function()
  local word = vim.fn.expand("<cword>")
  replace_all([[\V\<]] .. vim.fn.escape(word, [[/\]]) .. [[\>]], word)
end, { desc = "Replace word in file" })
-- yank into "z so the clipboard is untouched; \V + escape makes the selection literal
keymap.set("x", "<leader>s", function()
  vim.cmd('noautocmd normal! "zy')
  replace_all([[\V]] .. vim.fn.escape(vim.fn.getreg("z"), [[/\]]):gsub("\n", [[\n]]), "")
end, { desc = "Replace selection in file" })

keymap.set("n", "<leader>T", vim.treesitter.inspect_tree, { desc = "Inspect Treesitter tree" })

-- run the current file in a terminal split below; re-running replaces the previous output
local runners = {
  typescript = "node", -- node 22.18+ strips TS types itself, no tsc step needed
  javascript = "node",
  python = "python3",
  lua = "nvim -l",
  sh = "bash",
}
local run_buf
keymap.set("n", "<leader>rr", function()
  local cmd = runners[vim.bo.filetype]
  if not cmd then return vim.notify("No runner for " .. vim.bo.filetype, vim.log.levels.WARN) end
  vim.cmd("silent update")
  local file = vim.fn.shellescape(vim.fn.expand("%:p"))
  if run_buf and vim.api.nvim_buf_is_valid(run_buf) then vim.api.nvim_buf_delete(run_buf, { force = true }) end
  local code_win = vim.api.nvim_get_current_win()
  vim.cmd("botright 12split")
  vim.cmd.terminal(cmd .. " " .. file)
  run_buf = vim.api.nvim_get_current_buf()
  -- focus stays on the output: q closes it and lands back in the code
  keymap.set("n", "q", function()
    vim.api.nvim_buf_delete(run_buf, { force = true })
    if vim.api.nvim_win_is_valid(code_win) then vim.api.nvim_set_current_win(code_win) end
  end, { buffer = run_buf, nowait = true, desc = "Close run output" })
end, { desc = "Run current file in a split" })

-- gd (Telescope lsp_definitions) pushes onto the tagstack, so <C-t> pops exactly one gd
keymap.set("n", "<leader>6", "<C-t>", { desc = "Back from definition (pop tagstack)" })
