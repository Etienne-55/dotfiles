return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    -- no " Cmdline " / " Search " / ... title on the popup border: just the bar
    cmdline = {
      format = {
        cmdline = { title = "" },
        search_down = { title = "" },
        search_up = { title = "" },
        filter = { title = "" },
        lua = { title = "" },
        help = { title = "" },
        calculator = { title = "" },
        input = { title = "" },
      },
    },
    lsp = {
      -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      },
    },
    -- you can enable a preset for easier configuration
    presets = {
      bottom_search = false, -- use a classic bottom cmdline for search
      command_palette = true, -- position the cmdline and popupmenu together
      long_message_to_split = false, -- long messages will be sent to a split
      inc_rename = false, -- enables an input dialog for inc-rename.nvim
      lsp_doc_border = false, -- add a border to hover docs and signature help
    },
    -- Make messages disappear faster and appear smaller
    views = {
      mini = {
        size = {
          width = "auto",
          height = "auto",
          max_height = 3, -- Limit height to 3 lines
          max_width = 60, -- Limit width to 60 characters
        },
        timeout = 2000, -- Messages disappear after 2 seconds (default is 4000)
        position = {
          row = -2, -- Position from bottom
          col = "100%", -- Right side
        },
      },
      notify = {
        timeout = 500, -- Notifications disappear after 0.5 seconds
        size = {
          max_height = 5, -- Smaller notification height
          max_width = 80, -- Smaller notification width
        },
      },
      cmdline_popup = {
        size = {
          width = 60, -- Smaller command line popup
          height = "auto",
        },
      },
    },
    -- Configure message routing to make them less intrusive
    routes = {
      -- Hide "written" messages
      {
        filter = {
          event = "msg_show",
          kind = "",
          find = "written",
        },
        opts = { skip = true },
      },
      -- Hide search count messages like "1 of 5"
      {
        filter = {
          event = "msg_show",
          kind = "search_count",
        },
        opts = { skip = true },
      },
      -- Route LSP progress to mini view (smaller)
      {
        filter = {
          event = "lsp",
          kind = "progress",
        },
        view = "mini",
      },
      -- errors, and warnings sent with vim.notify, stay up 5s instead of the 0.5s above
      -- (missed ones are in :Noice errors)
      {
        filter = { error = true },
        view = "notify",
        opts = { title = "Error", timeout = 5000 },
      },
      {
        filter = { event = "notify", warning = true },
        view = "notify",
        opts = { timeout = 5000 },
      },
      -- output taller than the mini view (:ls, :map, :reg, :lua print(...), :!cmd, ...)
      -- opens in a split at the bottom instead of being cut to 3 lines (<C-w>j to get into it, q closes it)
      {
        filter = {
          event = "msg_show",
          min_height = 4,
        },
        view = "cmdline_output",
      },
      -- Make other (short) messages use mini view by default
      {
        filter = {
          event = "msg_show",
          min_height = 1,
        },
        view = "mini",
      },
    },
  },
  config = function(_, opts)
    require("noice").setup(opts)

    -- the cmdline popup border slowly fades through the syntax colors while the
    -- cmdline is open, like the `git push` rainbow in zshrc. Every per-kind border
    -- links to NoiceCmdlinePopupBorder, except search which has its own group.
    local p = require("eti.core.palette")
    local colors = { p.purple, p.magenta, p.red, p.orange, p.yellow, p.green, p.cyan, p.blue }
    local STEP_MS = 50
    local FADE_STEPS = 40 -- 2s from one color to the next, 16s for the whole cycle

    local function rgb(hex)
      return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
    end

    local function mix(a, b, t)
      local ar, ag, ab = rgb(a)
      local br, bg, bb = rgb(b)
      return string.format(
        "#%02x%02x%02x",
        math.floor(ar + (br - ar) * t + 0.5),
        math.floor(ag + (bg - ag) * t + 0.5),
        math.floor(ab + (bb - ab) * t + 0.5)
      )
    end

    local frame = 0 -- kept between cmdlines, so it picks up where it stopped
    local function paint()
      local i = math.floor(frame / FADE_STEPS)
      local color = mix(colors[i % #colors + 1], colors[(i + 1) % #colors + 1], (frame % FADE_STEPS) / FADE_STEPS)
      vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder", { fg = color })
      vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorderSearch", { fg = color })
    end

    local timer = assert(vim.uv.new_timer())
    vim.api.nvim_create_autocmd("CmdlineEnter", {
      callback = function()
        paint()
        -- no fade on / and ?: every nvim_set_hl redraws all windows, which made the
        -- incsearch highlights flicker at the timer rate
        local cmdtype = vim.v.event.cmdtype
        if cmdtype == "/" or cmdtype == "?" then
          return
        end
        timer:start(STEP_MS, STEP_MS, vim.schedule_wrap(function()
          frame = (frame + 1) % (#colors * FADE_STEPS)
          paint()
          vim.api.nvim__redraw({ flush = true })
        end))
      end,
    })
    vim.api.nvim_create_autocmd("CmdlineLeave", {
      callback = function()
        timer:stop()
      end,
    })
    -- a colorscheme reload resets the groups; paint them again
    vim.api.nvim_create_autocmd("ColorScheme", { callback = paint })
  end,
  dependencies = {
    "MunifTanjim/nui.nvim",
  }
}
