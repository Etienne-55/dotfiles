vim.g.mapleader = " "

local keymap = vim.keymap

-- registers: only visual d (and y) copy; normal-mode d/D delete into the black hole
keymap.set("n", "d", '"_d') -- dd, dw, d$... don't overwrite the clipboard
keymap.set("n", "D", '"_D')

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
-- top/bottom line; make them the same centered half-page scroll
for _, key in ipairs({ "<PageDown>", "<S-Down>" }) do
  keymap.set({ "n", "x" }, key, "<C-d>zz")
end
for _, key in ipairs({ "<PageUp>", "<S-Up>" }) do
  keymap.set({ "n", "x" }, key, "<C-u>zz")
end

-- search: keep the match centered; <Esc> clears the highlight
keymap.set("n", "n", "nzz")
keymap.set("n", "N", "Nzz")
-- same after a / or ? search, only from normal mode: in `c/foo<CR>` or <C-o>/ from
-- insert mode the zz would be typed into the buffer
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

-- replace the word under the cursor (or the selection) in the whole file: edit the replacement, <CR> to apply
-- keeppatterns: n/N keep searching what they did before
keymap.set("n", "<leader>s", [[:<C-u>keeppatterns %s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace word in file" })
-- yank into "z so the clipboard is untouched; \V + escape makes the selection literal
keymap.set("x", "<leader>s", [["zy:<C-u>keeppatterns %s/\V<C-r>=escape(@z, '/\')<CR>//gI<Left><Left><Left>]], { desc = "Replace selection in file" })

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
