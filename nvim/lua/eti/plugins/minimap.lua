return {
  "Isrothy/neominimap.nvim",
  version = "v3.x.x",
  lazy = false, -- the plugin lazy-loads itself
  init = function()
    vim.g.neominimap = {
      auto_enable = true,
      -- errors as a mark in the sign column (next to the git marks), not a red
      -- line background that hides the cursor line
      diagnostic = { mode = "sign" },
      -- hidden except while jumping around (extras/minimap.lua)
      win_filter = function(winid)
        return require("eti.extras.minimap").visible(winid)
      end,
    }
  end,
}
