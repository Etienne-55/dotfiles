-- Minimap that only shows while jumping: shift+up/down (core/keymaps), {/} hunks
-- (plugins/gitsigns) and (/) diagnostics (plugins/lsp/lspconfig) call peek(), and it
-- hides again once the jumps stop. neominimap stays enabled so the minimaps are
-- already built; plugins/minimap.lua's win_filter only lets a peeked window show one.
local M = {}

local hide_after = 750 -- ms after the last jump
local timer = assert(vim.uv.new_timer())
local peeked -- window currently showing the minimap

local function set(win, on)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.w[win].minimap_peek = on or nil
  require("neominimap.api").win.refresh(win) -- re-runs win_filter: opens or closes it
end

function M.visible(win)
  return vim.w[win].minimap_peek == true
end

-- safe from expr mappings: refresh is scheduled by neominimap
function M.peek()
  local win = vim.api.nvim_get_current_win()
  if peeked and peeked ~= win then
    set(peeked, false)
  end
  if not M.visible(win) then
    set(win, true)
  end
  peeked = win

  timer:stop()
  timer:start(hide_after, 0, vim.schedule_wrap(function()
    set(win, false)
    peeked = nil
  end))
end

return M
