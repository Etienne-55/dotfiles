return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    lsp = {
      -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
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
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  }
}
