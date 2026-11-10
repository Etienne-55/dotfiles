return {
  "Isrothy/neominimap.nvim",
  version = "v3.x.x",
  lazy = false, -- the plugin lazy-loads itself
  init = function()
    vim.g.neominimap = {
      auto_enable = true,
      -- bugs as red (errors) / yellow (warnings) rows; hints and info are left out.
      -- the cursor row gets its own color on top (extras/minimap.lua)
      diagnostic = { mode = "line", severity = { min = vim.diagnostic.severity.WARN } },
      -- hidden except while jumping around (extras/minimap.lua)
      win_filter = function(winid)
        return require("eti.extras.minimap").visible(winid)
      end,
    }
  end,
}
