return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  lazy = false, -- needed so oil can take over directory buffers (e.g. `nvim .`)
  config = function()
    require("oil").setup({
      default_file_explorer = true,
      columns = { "icon" },
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
      watch_for_changes = true,
      keymaps = {
        ["q"] = { "actions.close", mode = "n" },
        -- <C-h>/<C-l> are window navigation (Cmd+arrows in ghostty), not split/refresh
        ["<C-h>"] = false,
        ["<C-l>"] = false,
        ["<C-x>"] = { "actions.select", opts = { horizontal = true } },
        ["R"] = "actions.refresh",
        -- mv/cp: dd/yy here, p in the side pane, then <leader>w.
        ["g|"] = {
          desc = "Open this dir in a side pane (for mv/cp)",
          mode = "n",
          callback = function()
            local dir = require("oil").get_current_dir()
            vim.cmd.vsplit()
            require("oil").open(dir)
          end,
        },
        ["<leader>w"] = {
          desc = "Apply oil changes without confirmation",
          mode = "n",
          callback = function() require("oil").save({ confirm = false }) end,
        },
      },
      view_options = {
        show_hidden = true,
        is_always_hidden = function(name)
          return name == ".DS_Store" or name == ".."
        end,
      },
      float = {
        padding = 4,
        max_width = 100,
        max_height = 30,
      },
    })

    -- Confirmation popup: <CR> = yes (oil already maps <Esc> = no).
    -- FileType fires before oil sets its buffer keymaps, so remap onto its "y".
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "oil_preview",
      callback = function(ev)
        vim.keymap.set("n", "<CR>", "y", { buffer = ev.buf, remap = true, nowait = true })
      end,
    })

    vim.keymap.set("n", "-", "<cmd>Oil<CR>", { desc = "Open parent directory (oil)" })
    vim.keymap.set("n", "<leader>-", function() require("oil").toggle_float() end, { desc = "Toggle oil in float" })
  end,
}
