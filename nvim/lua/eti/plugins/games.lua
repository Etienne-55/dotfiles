return {
  {
    "alec-gibson/nvim-tetris",
    cmd = "Tetris",
    keys = {
      { "<leader>tt", function() require("eti.extras.tetris").toggle() end, desc = "Toggle Tetris (hides & pauses)" },
    },
    config = function()
      require("eti.extras.tetris").setup() -- 1984 look, music, pause on hide
    end,
  },

  {
    "tamton-aquib/zone.nvim",
    event = "VeryLazy",
    dependencies = { "folke/zen-mode.nvim" },
    config = function()
      -- Own idle timer instead of zone.setup(): after 5 min without a key in normal
      -- mode, open zen mode and run zone's treadmill on top of it. The next key
      -- stops both (and is swallowed, so waking it up doesn't also edit).
      local idle_ms = 5 * 60 * 1000
      local excluded = { TelescopePrompt = true, NvimTree = true, snacks_dashboard = true, lazy = true, oil = true, tetris = true }
      local timer = assert(vim.uv.new_timer())
      local running, opened_zen = false, false -- running also covers "about to start"
      local focused = true

      -- zone puts its float right of the line numbers; stretch it over the whole
      -- window so the gutter is hidden too
      local function cover(win)
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local cfg = vim.api.nvim_win_get_config(w)
          if w ~= win and cfg.relative == "win" and cfg.win == win then
            vim.api.nvim_win_set_config(w, {
              relative = "win", win = win, row = 0, col = 0,
              width = vim.api.nvim_win_get_width(win), height = vim.api.nvim_win_get_height(win),
            })
          end
        end
      end

      local function start()
        if running or not focused or vim.api.nvim_get_mode().mode ~= "n" or vim.bo.buftype ~= "" or excluded[vim.bo.filetype] then
          return
        end
        running = true
        opened_zen = not require("zen-mode.view").is_open()
        if opened_zen then
          require("zen-mode").open()
        end
        -- zone closes itself on the next CursorMoved, and switching into the zen
        -- window fires one; start the treadmill only after that has gone by
        vim.defer_fn(function()
          if not running then
            return -- a key came in meanwhile
          end
          require("zone.styles.treadmill").start()
          cover(vim.api.nvim_get_current_win())
        end, 200)
      end

      local function stop()
        running = false
        require("zone.helper").zone_close() -- schedules the close
        if opened_zen then
          opened_zen = false
          vim.schedule(function() require("zen-mode").close() end)
        end
      end

      vim.on_key(function(_, typed)
        if typed == nil or typed == "" then
          return -- keys from mappings / :normal (zen's own `norm! zz`), not the user
        end
        focused = true -- a typed key proves it, even if a FocusGained got lost
        timer:stop()
        timer:start(idle_ms, 0, vim.schedule_wrap(start))
        if running then
          vim.schedule(stop)
          return ""
        end
      end, vim.api.nvim_create_namespace("eti_screensaver"))

      -- nvim sees no keys while you're in another tmux pane/window (e.g. Claude), so
      -- without this the screensaver would start in the background, and zen's
      -- `tmux set status off` hides the window list for the whole session.
      -- Needs `focus-events on` in tmux.conf.
      vim.api.nvim_create_autocmd("FocusLost", {
        callback = function()
          focused = false
          timer:stop()
          if running then
            stop()
          end
        end,
      })
      vim.api.nvim_create_autocmd("FocusGained", {
        callback = function()
          focused = true
          timer:stop()
          timer:start(idle_ms, 0, vim.schedule_wrap(start))
        end,
      })

      timer:start(idle_ms, 0, vim.schedule_wrap(start))
    end,
  },
}
