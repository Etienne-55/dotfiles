-- Minimap that only shows while jumping: shift+up/down (core/keymaps), {/} hunks
-- (plugins/gitsigns) and (/) diagnostics (plugins/lsp/lspconfig) call peek(), and it
-- hides again once the jumps stop. neominimap stays enabled so the minimaps are
-- already built; plugins/minimap.lua's win_filter only lets a peeked window show one.
local M = {}

local hide_after = 750 -- ms after the last jump
local timer = assert(vim.uv.new_timer())
local peeked -- window currently showing the minimap

-- the minimap's cursor row changes color when the cursor sits on a bug (warning or
-- error, same filter as ( / ) in core/keymaps) or on a changed line. An extmark,
-- not CursorLine: the red diagnostic row's extmark would cover CursorLine.
local ns = vim.api.nvim_create_namespace("eti_minimap_cursor")
M.bug_severity = { min = vim.diagnostic.severity.WARN }

local function on_hunk(buf, row)
  local ok, hunks = pcall(function() return require("gitsigns").get_hunks(buf) end)
  for _, h in ipairs(ok and hunks or {}) do
    local first = h.added.start
    local last = first + math.max(h.added.count, 1) - 1 -- deletions sit on one line
    if row >= first and row <= last then
      return true
    end
  end
  return false
end

-- source row -> minimap row, skipping closed folds like neominimap does
local function minimap_row(buf, row)
  local ok, mrow = pcall(function()
    local fold = require("neominimap.map.fold")
    local vrow, hidden = fold.subtract_fold_lines(fold.get_cached_folds(buf), row)
    return require("neominimap.map.coord").codepoint_to_mcodepoint(hidden and row or vrow, 1)
  end)
  return ok and mrow or row
end

local function mark_cursor(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local mbuf = require("neominimap.buffer").get_minimap_bufnr(buf)
  if not mbuf or not vim.api.nvim_buf_is_valid(mbuf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(mbuf, ns, 0, -1)
  if not M.visible(win) then
    return
  end

  local row = vim.api.nvim_win_get_cursor(win)[1]
  local hl
  if #vim.diagnostic.get(buf, { lnum = row - 1, severity = M.bug_severity }) > 0 then
    hl = "NeominimapCursorOnBug"
  elseif on_hunk(buf, row) then
    hl = "NeominimapCursorOnDiff"
  else
    return -- plain line: the normal minimap CursorLine shows
  end
  local mrow = minimap_row(buf, row)
  if mrow <= vim.api.nvim_buf_line_count(mbuf) then
    -- above the diagnostic rows (priority 100) so it shows on top of the red
    vim.api.nvim_buf_set_extmark(mbuf, ns, mrow - 1, 0, { end_row = mrow, hl_group = hl, priority = 200 })
  end
end

local function set(win, on)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.w[win].minimap_peek = on or nil
  require("neominimap.api").win.refresh(win) -- re-runs win_filter: opens or closes it
  mark_cursor(win)
end

-- keep the marker on the cursor while the minimap is up
vim.api.nvim_create_autocmd("CursorMoved", {
  group = vim.api.nvim_create_augroup("eti_minimap_cursor", { clear = true }),
  callback = function()
    local win = vim.api.nvim_get_current_win()
    if win == peeked then
      mark_cursor(win)
    end
  end,
})

-- never in diff windows (diffview, :diffthis): the two sides already line up and the
-- minimap pushed the right one narrower than the left
function M.visible(win)
  return vim.w[win].minimap_peek == true and not vim.wo[win].diff
end

-- safe from expr mappings: refresh is scheduled by neominimap
function M.peek()
  local win = vim.api.nvim_get_current_win()
  if peeked and peeked ~= win then
    set(peeked, false)
  end
  peeked = win
  if not M.visible(win) then
    set(win, true)
  else
    mark_cursor(win)
  end

  timer:stop()
  timer:start(hide_after, 0, vim.schedule_wrap(function()
    set(win, false)
    peeked = nil
  end))
end

return M
