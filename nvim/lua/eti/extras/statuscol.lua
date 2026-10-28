-- Line-number column ('statuscolumn', set in core/options.lua): the usual
-- relative numbers, except lines above the top of the window show their real
-- number. Only the sticky header (plugins/treesitter-context) draws those, so
-- it shows e.g. 142 instead of how far it is from the cursor.
local M = {}

function M.number()
  -- no numbers (Claude panel, telescope): no number and no trailing space either
  if not (vim.wo.number or vim.wo.relativenumber) then
    return ""
  end
  -- evaluated with the drawn window as the current one, for both the real column
  -- and treesitter-context's header (g:statusline_winid is unset in both)
  if vim.v.lnum < vim.fn.line("w0") then
    return "%=" .. vim.v.lnum .. " "
  end
  -- %l follows number/relativenumber; the cursor line is left-aligned like the default
  return vim.v.relnum == 0 and "%l%= " or "%=%l "
end

return M
