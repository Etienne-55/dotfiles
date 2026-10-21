-- Runs a ClaudeCode command and starts typing if it left us in Claude (auto_insert is off
-- below, so opening wouldn't enter terminal mode by itself). Toggling it closed does nothing.
local function open_claude(cmd)
  return function()
    vim.cmd(cmd)
    local buf = require("claudecode.terminal").get_active_terminal_bufnr()
    if buf and vim.api.nvim_get_current_buf() == buf then
      vim.cmd.startinsert()
    end
  end
end

-- Sends keys or a slash command into the running Claude session and focuses it,
-- so model / effort / sandbox can be changed without restarting the conversation.
local function send_to_claude(text, submit)
  local terminal = require("claudecode.terminal")
  local buf = terminal.get_active_terminal_bufnr()
  if not buf then
    vim.notify("Claude isn't running, <leader>cc to start it", vim.log.levels.WARN)
    return
  end
  terminal.send_to_terminal(text, { submit = submit, focus = true })
  if vim.api.nvim_get_current_buf() == buf then
    vim.cmd.startinsert() -- the picker / command needs keys even if Claude was left in normal mode
  end
end

-- hlsearch paints matches in every window. While the cursor is elsewhere, Claude's window
-- maps the search groups to an empty one, so / only lights up the file being edited.
-- Leaves the Claude terminal in a direction (nvim split, or tmux pane past the edge).
-- Flagged after the jump (BufLeave would overwrite it) so coming back resumes typing.
local function navigate(term, dir)
  vim.cmd.stopinsert()
  vim.cmd("TmuxNavigate" .. dir)
  vim.b[term.buf].claude_insert = true
end

local NO_SEARCH ="Search:ClaudeNoSearch,CurSearch:ClaudeNoSearch,IncSearch:ClaudeNoSearch"
local function show_search(win, show)
  local hl = vim.wo[win].winhighlight:gsub(",?%a*Search:ClaudeNoSearch", "")
  if not show then
    hl = hl == "" and NO_SEARCH or hl .. "," .. NO_SEARCH
  end
  vim.wo[win].winhighlight = hl
end

return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  cmd = { "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSelectModel" },
  opts = function()
    local claude = vim.fn.exepath("claude")
    if claude == "" then
      claude = vim.fn.expand("~/.local/bin/claude") -- native installer location
    end

    return {
      terminal_cmd = claude,
      -- Claude's fullscreen mode draws on the alternate screen, which leaves the nvim
      -- terminal buffer without scrollback; the classic renderer keeps j/k scrolling working.
      -- It redraws relative to the last frame, so the pane width must never change (see wo).
      env = { CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN = "1" },
      terminal = {
        provider = "snacks",
        split_side = "right",
        split_width_percentage = 0.35,
        -- Snacks re-enters terminal mode on every BufEnter, which throws away the scroll
        -- position / selection you left Claude at. on_buf below brings back whichever
        -- mode you left in instead.
        auto_insert = false,
        -- Keys for when the cursor is inside Claude, where the <leader> maps below
        -- don't apply. Model, thinking and permission mode already have Option+P,
        -- Option+T and Shift+Tab in Claude itself.
        snacks_win_opts = {
          -- Keep the pty size fixed across hide/show: no inherited gutter (shifts the width),
          -- and no Snacks winbar, which the re-shown split only gets after the buffer is set,
          -- so the height blips by a row and the prompt box is redrawn one line off.
          -- No cursorline either, it highlights a line that isn't Claude's input.
          wo = { number = false, relativenumber = false, signcolumn = "no", cursorline = false, winbar = "" },
          on_buf = function(self)
            local buf = self.buf
            vim.b[buf].claude_insert = true -- a fresh session starts out typing
            vim.api.nvim_create_autocmd("BufLeave", {
              buffer = buf,
              callback = function() vim.b[buf].claude_insert = vim.fn.mode() == "t" end,
            })
            vim.api.nvim_create_autocmd("BufEnter", {
              buffer = buf,
              callback = function()
                -- Snacks enters the buffer before the job starts; open_claude handles that case
                if vim.b[buf].claude_insert and vim.bo[buf].buftype == "terminal" then
                  vim.cmd.startinsert()
                end
              end,
            })
            -- Where Claude's input is, counted from the bottom so output arriving above
            -- doesn't shift it; the cursor still sits on it as terminal mode ends.
            vim.api.nvim_create_autocmd("TermLeave", {
              buffer = buf,
              callback = function()
                vim.b[buf].claude_prompt_from_end = vim.api.nvim_buf_line_count(buf) - vim.fn.line(".")
              end,
            })
            vim.api.nvim_set_hl(0, "ClaudeNoSearch", {})
            vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave" }, {
              buffer = buf,
              callback = function(args) show_search(0, args.event == "WinEnter") end,
            })
          end,
          keys = {
            term_normal = false, -- let Esc / Esc Esc reach Claude (cancel, rewind); <C-\><C-n> still works
            claude_hide = { "<C-q>", function(self) self:hide() end, mode = "t", desc = "Hide Claude" },
            -- <C-\><C-n> gets eaten by vim-tmux-navigator's tmux binding, so navigate directly
            -- (into nvim splits or out to tmux panes; ghostty maps Cmd+arrows to these).
            -- Flag set after the jump: left while typing, so come back typing.
            claude_left = { "<C-h>", function(self) navigate(self, "Left") end, mode = "t", desc = "Go to left window" },
            claude_down = { "<C-j>", function(self) navigate(self, "Down") end, mode = "t", desc = "Go to lower window" },
            claude_up = { "<C-k>", function(self) navigate(self, "Up") end, mode = "t", desc = "Go to upper window" },
            claude_right = { "<C-l>", function(self) navigate(self, "Right") end, mode = "t", desc = "Go to right window" },
            -- same problem for scrolling: Shift+arrows hop out of the input into the
            -- conversation (normal mode, to scroll/search/yank) and back into it to type.
            -- In normal mode Shift+Up is the global centered half-page scroll (core/keymaps).
            claude_scroll_up = {
              "<S-Up>",
              function() vim.api.nvim_feedkeys(vim.keycode("<C-\\><C-n><C-u>zz"), "n", false) end,
              mode = "t",
              desc = "Scroll the conversation up",
            },
            claude_scroll_down = {
              "<S-Down>",
              function(self)
                local prompt = vim.api.nvim_buf_line_count(self.buf) - (vim.b[self.buf].claude_prompt_from_end or 0)
                if vim.fn.line(".") + vim.wo.scroll >= prompt then
                  vim.cmd.startinsert()
                else
                  vim.cmd("normal! " .. vim.keycode("<C-d>zz"))
                end
              end,
              mode = "n",
              desc = "Scroll down, back to typing at the input",
            },
            claude_sandbox = { "<M-s>", function() send_to_claude("/sandbox", true) end, mode = "t", desc = "Claude sandbox" },
            claude_effort = { "<M-e>", function() send_to_claude("/effort", true) end, mode = "t", desc = "Claude effort" },
          },
        },
      },
    }
  end,
  keys = {
    -- same key as claude_hide inside the terminal, so one key opens and closes it
    { "<C-q>", open_claude("ClaudeCode"), desc = "Toggle Claude" },
  },
}
