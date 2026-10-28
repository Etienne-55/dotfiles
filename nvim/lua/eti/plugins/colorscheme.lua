return {
  "folke/tokyonight.nvim",
  priority = 1000,
  config = function()
    local p = require("eti.core.palette")
    local transparent = true

    -- the palette as a custom tokyonight style, so tokyonight derives
    -- diff/visual/terminal colors from it (internal table, not a setup option)
    require("tokyonight.colors").styles.neon = function()
      return vim.deepcopy(p)
    end

    require("tokyonight").setup({
      style = "neon",
      transparent = transparent,
      styles = {
        sidebars = transparent and "transparent" or "dark",
        floats = transparent and "transparent" or "dark",
      },
      on_colors = function(colors)
        colors.border_highlight = p.border
        colors.border = p.fg_gutter
        colors.bg_visual = p.bg_visual
      end,
      on_highlights = function(hl, c)
        hl.TelescopePromptBorder = { fg = p.border_prompt, bg = c.bg_float }
        hl.TelescopePromptTitle = { fg = p.border_prompt, bg = c.bg_float }
        hl.TelescopeSelection = { fg = c.fg, bg = c.bg_visual, bold = true }
        -- relative numbers: fg_gutter is too dark to read on the glass
        hl.LineNr = { fg = p.dark5 }
        hl.LineNrAbove = { fg = p.dark5 }
        hl.LineNrBelow = { fg = p.dark5 }
        hl.CursorLineNr = { fg = p.border_prompt, bold = true }
        -- sticky header (treesitter-context): no bg, it looked like a visual selection;
        -- a thin underline marks where it ends and the code starts
        hl.TreesitterContext = { bg = "NONE" }
        hl.TreesitterContextLineNumber = { fg = p.dark5 }
        hl.TreesitterContextBottom = { underline = true, sp = p.dark3 }
        hl.TreesitterContextLineNumberBottom = { fg = p.dark5, underline = true, sp = p.dark3 }
        -- minimap cursor: the default CursorLine bg is too dark to spot in the minimap
        hl.NeominimapCursorLine = { bg = p.blue0 }
        -- dashboard branch and worktree in neon: hot pink branch, purple folder, cyan icon
        hl.SnacksDashboardFile = { fg = p.magenta, bold = true }
        hl.SnacksDashboardDir = { fg = p.purple }
        hl.SnacksDashboardTitle = { fg = p.cyan, bold = true }
        hl.SnacksDashboardIcon = { fg = p.cyan }
      end,
    })

    vim.cmd("colorscheme tokyonight")
  end,
}
