return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local lualine = require("lualine")
    local lazy_status = require("lazy.status") -- to configure lazy pending updates count

    local p = require("eti.core.palette")
    local function mode(color)
      return {
        a = { bg = color, fg = p.bg_statusline, gui = "bold" },
        b = { bg = p.bg_statusline, fg = p.fg },
        c = { bg = p.bg_statusline, fg = p.fg },
      }
    end
    local theme = {
      normal = mode(p.blue),
      insert = mode(p.green),
      visual = mode(p.magenta),
      command = mode(p.yellow),
      replace = mode(p.red),
      inactive = {
        a = { bg = p.bg_dark, fg = p.dark5, gui = "bold" },
        b = { bg = p.bg_dark, fg = p.dark5 },
        c = { bg = p.bg_dark, fg = p.dark5 },
      },
    }

    local opts = {
      options = {
        theme = theme,
      },
      sections = {
        -- filename first; the branch comes after it, truncated (tmux shows the full one)
        lualine_b = { { "filename", path = 1 } },
        lualine_c = {
          {
            "branch",
            fmt = function(name)
              return #name > 20 and name:sub(1, 19) .. "…" or name
            end,
          },
          "diff",
          "diagnostics",
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
          { "encoding" },
          { "fileformat" },
          { "filetype" },
        },
      },
    }
    lualine.setup(opts)

    -- lualine doesn't refresh on these by itself
    vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
      group = vim.api.nvim_create_augroup("UserLualineRecording", {}),
      callback = function()
        vim.schedule(lualine.refresh)
      end,
    })
  end,
}
