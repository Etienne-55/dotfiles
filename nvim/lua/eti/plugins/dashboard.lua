-- Start screen (replaces alpha-nvim). Merged into the snacks.nvim spec by lazy.
-- The art and the bouncing Pokémon live in eti/extras/dashboard.lua.
local dashboard = require("eti.extras.dashboard")

-- the shell aliases (`nvim "+Pick find_files"`) go straight to a picker; the
-- dashboard would only show through behind it
local from_pick = vim.iter(vim.v.argv):any(function(a)
  return vim.startswith(a, "+Pick")
end)

return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      enabled = not from_pick,
      width = dashboard.width,
      pane_gap = 0,
      sections = { dashboard.sections },
    },
    -- every redraw rewrites the whole buffer; with undo on, nvim keeps a copy of
    -- each one, and the bounce redraws 2.5x a second (it grew to GBs of RAM)
    styles = { dashboard = { bo = { undolevels = -1 } } },
  },
}
