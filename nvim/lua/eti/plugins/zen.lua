return {
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    keys = {
      { "<leader>zz", function() require("zen-mode").toggle() end, desc = "Toggle Zen Mode" },
    },
    config = function()
      local diagnostic_config, hints_were_on

      require("zen-mode").setup {
        window = {
          backdrop = 1,
          -- full size and the normal gutter, so the text doesn't shift on toggle
          width = 1,
          height = 1,
          options = {
            list = false,
            cursorline = false,
          },
        },
        plugins = {
          twilight = { enabled = true }, -- dim everything but the current function
          gitsigns = { enabled = true }, -- hide git signs
          -- tmux status bar is handled in on_open/on_close: zen's built-in tmux
          -- plugin reads it with `tmux show -w status` (status isn't a window
          -- option), so it never restored the bar; it also zoomed the pane
          tmux = { enabled = false },
        },
        on_open = function()
          -- zen-mode recentres the cursor line (norm! zz); keep the original scroll
          local parent = require("zen-mode.view").parent
          if parent and vim.api.nvim_win_is_valid(parent) then
            vim.fn.winrestview { topline = vim.fn.line("w0", parent) }
          end

          -- hide diagnostics through their display config: enable(false) would also
          -- wipe any per-buffer enable/disable state when re-enabled
          diagnostic_config = vim.deepcopy(vim.diagnostic.config())
          vim.diagnostic.config { virtual_text = false, virtual_lines = false, signs = false, underline = false }
          hints_were_on = vim.lsp.inlay_hint.is_enabled()
          vim.lsp.inlay_hint.enable(false)
          if vim.env.TMUX then
            vim.fn.system { "tmux", "set", "status", "off" }
          end
        end,
        on_close = function()
          vim.diagnostic.config(diagnostic_config)
          vim.lsp.inlay_hint.enable(hints_were_on)
          if vim.env.TMUX then
            vim.fn.system { "tmux", "set", "-u", "status" } -- back to the tmux.conf value
          end
        end,
      }

      -- quitting with zen open skips on_close, which would leave the tmux bar hidden
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          if require("zen-mode.view").is_open() then
            require("zen-mode").close()
          end
        end,
      })
    end,
  },

  {
    "folke/twilight.nvim",
    config = function()
      require("twilight").setup {}

      -- Keep the whole enclosing function lit, not the innermost if/loop that
      -- twilight's treesitter mode locks onto. Outside a function (or without a
      -- parser), fall back to a fixed window around the cursor.
      -- Lines from <= l < to stay bright (1-indexed).
      local half = 9 -- fallback: 9 above + cursor + 9 below = 19 lines

      local function is_function(type)
        return (type:find "function" or type:find "method" or type:find "func_literal"
          or type:find "closure" or type:find "lambda")
          and not (type:find "call" or type:find "parameter" or type:find "argument"
            or type:find "name" or type:find "type" or type:find "body" or type:find "signature")
      end

      local function function_range(buf, line)
        local text = vim.api.nvim_buf_get_lines(buf, line, line + 1, false)[1] or ""
        local col = math.max(0, (text:find "%S" or 1) - 1)
        local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { line, col } })
        while ok and node do
          if is_function(node:type()) then
            local start_row, _, end_row = node:range()
            return start_row + 1, end_row + 2
          end
          node = node:parent()
        end
      end

      require("twilight.view").get_context = function(buf, line)
        local from, to = function_range(buf, line)
        if from then
          return from, to
        end
        local cur = line + 1 -- line is 0-indexed
        local last = vim.api.nvim_buf_line_count(buf)
        return math.max(1, cur - half), math.min(last, cur + half) + 1
      end
    end,
  },
}
