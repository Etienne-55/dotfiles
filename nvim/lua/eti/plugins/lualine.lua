return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local lualine = require("lualine")
    local lazy_status = require("lazy.status") -- to configure lazy pending updates count

    local p = require("eti.core.palette")
    -- glass bar, like the tmux one: no backgrounds (the colorscheme is transparent, so ghostty's
    -- opacity + blur shows through) and no powerline blocks; the mode is colored text instead
    local function mode(color)
      return {
        a = { bg = "NONE", fg = color, gui = "bold" },
        b = { bg = "NONE", fg = p.fg },
        c = { bg = "NONE", fg = p.fg_dark },
      }
    end
    local theme = {
      normal = mode(p.blue),
      insert = mode(p.green),
      visual = mode(p.magenta),
      command = mode(p.yellow),
      replace = mode(p.red),
      inactive = {
        a = { bg = "NONE", fg = p.dark3, gui = "bold" },
        b = { bg = "NONE", fg = p.dark3 },
        c = { bg = "NONE", fg = p.dark3 },
      },
    }

    -- save state after the file name (instead of lualine's [+]): an orange save icon while
    -- there are unsaved changes, a green save-check icon once the file is saved
    local filename = { "filename", path = 4, symbols = { modified = "" } }
    local save_state = {
      function()
        return vim.bo.modified and "󰽃" or "󱣫"
      end,
      color = function()
        return { fg = vim.bo.modified and p.orange or p.green }
      end,
      padding = { left = 0, right = 1 },
    }
    -- hint and error counts right after the file name, count first: "file.txt 2 3"
    -- (warnings and infos stay with the diagnostics further right)
    local function diagnostic_count(severity, icon, color)
      local function count()
        return #vim.diagnostic.get(0, { severity = severity })
      end
      return {
        function() return count() .. icon end,
        cond = function() return count() > 0 end,
        color = { fg = color },
        padding = { left = 0, right = 1 },
      }
    end
    local hints = diagnostic_count(vim.diagnostic.severity.HINT, "", p.green)
    local errors = diagnostic_count(vim.diagnostic.severity.ERROR, "", p.red)

    local opts = {
      options = {
        theme = theme,
        section_separators = "",
        component_separators = "",
      },
      sections = {
        -- the current file (parent dir + name only, so diagnostics fit), then the last 3 other
        -- files, <leader>1-3 to open (extras/recent.lua). No branch: the tmux bar shows it.
        lualine_b = { filename, save_state, hints, errors, { require("eti.extras.recent").component } },
        lualine_c = {
          "diff",
          {
            "diagnostics",
            sections = { "warn", "info" }, -- errors and hints are next to the file name
            -- same icons as the gutter signs in lsp/lspconfig.lua
            symbols = { error = " ", warn = " ", info = " ", hint = "󰠠 " },
          },
        },
        lualine_x = {
          -- show macro recording: noice hides the "recording @q" message, and nvim-autopairs
          -- stops pairing while recording, so an accidental `q` made pairs silently stop working
          {
            function()
              return "recording @" .. vim.fn.reg_recording()
            end,
            cond = function()
              return vim.fn.reg_recording() ~= ""
            end,
            color = { fg = p.red, gui = "bold" },
          },
          {
            lazy_status.updates,
            cond = lazy_status.has_updates,
            color = { fg = p.orange },
          },
          { "filetype", icon_only = true, color = { fg = p.comment } }, -- the icon, no name
        },
      },
    }
    -- the Claude split (claudecode.nvim's snacks terminal): just " claude" in orange at the
    -- right end, like its tmux window, instead of TERMINAL, the term://… buffer name and the snacks_terminal filetype
    -- (orange whether or not the split has focus)
    local claude_bar = {
      lualine_z = { { function() return "\u{ec82} claude" end, color = { fg = p.orange, gui = "bold" } } },
    }
    opts.extensions = {
      { filetypes = { "snacks_terminal" }, sections = claude_bar, inactive_sections = claude_bar },
    }
    lualine.setup(opts)
    require("eti.extras.recent").setup()

    -- lualine doesn't refresh on these by itself; LSP diagnostics arrive after the buffer opens,
    -- so without DiagnosticChanged the counts only showed up once the cursor moved
    vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave", "DiagnosticChanged" }, {
      group = vim.api.nvim_create_augroup("UserLualineRefresh", {}),
      callback = function()
        vim.schedule(lualine.refresh)
      end,
    })
  end,
}
