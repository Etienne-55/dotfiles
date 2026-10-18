-- Side-by-side git diffs with a file list: <leader>gv for uncommitted changes, and
-- `git diff dev` / `git diff master` in the shell for the whole branch (zsh/zshrc).
-- In it: <Tab>/<S-Tab> next/prev file, ]c/[c next/prev change, q closes.
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

    local close = { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close the diff view" } }
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
      keymaps = {
        view = vim.list_extend({ close }, unmap),
        file_panel = vim.list_extend({ close }, unmap),
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
