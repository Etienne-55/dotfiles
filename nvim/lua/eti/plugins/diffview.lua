-- Side-by-side git diffs with a file list: <leader>gv (or Cmd+w in tmux, a popup) for uncommitted changes, and
-- `git diff dev` / `git diff master` in the shell for the whole branch (zsh/zshrc).
-- In it: <Tab>/<S-Tab> next/prev file, ]c/[c next/prev change, <C-w>z zooms the current side, q closes.
-- Review: <leader> on a file in the list marks it reviewed (□ -> ■), again to unmark; `H` hides reviewed.
return {
  -- maintained fork of sindrets/diffview.nvim (same require("diffview") and commands)
  "dlyongemallo/diffview-plus.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Diff view of uncommitted changes" },
  },
  config = function()
    -- slashes instead of dashes on the side where lines don't exist
    vim.opt.fillchars:append({ diff = "╱" })

    -- in the tmux Cmd+w popup (g:diff_popup), q saves edits and quits nvim so the popup closes too
    local function quit()
      if vim.g.diff_popup then
        vim.cmd("silent! wall | qa!")
      else
        vim.cmd("DiffviewClose")
      end
    end
    local close = { "n", "q", quit, { desc = "Close the diff view" } }

    -- tmux-style zoom: the current side takes the whole width (the diff colors stay), again to restore
    local layout
    local function zoom()
      if layout then
        vim.cmd(layout)
        layout = nil
      else
        layout = vim.fn.winrestcmd()
        vim.cmd("wincmd |")
      end
    end
    local zoom_map = { "n", "<C-w>z", zoom, { desc = "Zoom the current side" } }

    -- <leader> alone in the file list marks the file under the cursor reviewed (□ -> ■), again to unmark.
    -- The built-in toggle (`w`) jumps to the next file; this one stays put. Fires at once (diffview maps
    -- are nowait), so other <leader> maps don't work while the cursor is in the file list
    local function toggle_reviewed()
      local view = require("diffview.lib").get_current_view()
      local item = view and view.panel:get_item_at_cursor()
      -- folders have a boolean `collapsed`; only files get marked
      if not item or type(item.collapsed) == "boolean" then
        return
      end
      local sel = require("diffview.api").selections
      local opts = { kind = item.kind }
      if sel.is_selected(item.path, opts) then
        sel.deselect({ item.path }, opts)
      else
        sel.select({ item.path }, opts)
      end
    end
    local review_map = { "n", "<leader>", toggle_reviewed, { desc = "Toggle file reviewed" } }
    -- diffview's merge-tool maps would shadow claude (<leader>cb/ct) and code actions
    -- (<leader>ca), and its <leader>e makes nvim-tree's <leader>ee/ef wait
    local function off(lhs)
      return { "n", lhs, false }
    end
    local unmap = {}
    for _, lhs in ipairs({ "<leader>co", "<leader>ct", "<leader>cb", "<leader>ca", "<leader>cO", "<leader>cT", "<leader>cB", "<leader>cA", "<leader>e" }) do
      table.insert(unmap, off(lhs))
    end
    require("diffview").setup({
      -- old side: removed lines red instead of green
      enhanced_diff_hl = true,
      -- reviewed marks survive closing nvim (per repo and revision)
      persist_selections = { enabled = true },
      -- show □ on every file from the start, not only once something is marked
      file_panel = { always_show_marks = true },
      keymaps = {
        view = vim.list_extend({ close, zoom_map }, unmap),
        file_panel = vim.list_extend({ close, review_map }, unmap),
        file_history_panel = { close, off("<leader>e") },
      },
    })

    -- classic red/green, like delta in the shell (git/gitconfig). Set after setup:
    -- diffview sets its own colors when it loads and on every colorscheme change,
    -- and this autocmd, created after its own, runs last
    local function colors()
      vim.api.nvim_set_hl(0, "DiffviewDiffAdd", { bg = "#173A22" })
      vim.api.nvim_set_hl(0, "DiffviewDiffAddAsDelete", { bg = "#4A1A1D" })
      vim.api.nvim_set_hl(0, "DiffviewDiffDeleteDim", { fg = "#6B2A2F" })
      vim.api.nvim_set_hl(0, "DiffviewDiffChange", { bg = "#1C1A26" })
      vim.api.nvim_set_hl(0, "DiffviewDiffText", { bg = "#2C5E38", bold = true })
    end
    colors()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })
  end,
}
