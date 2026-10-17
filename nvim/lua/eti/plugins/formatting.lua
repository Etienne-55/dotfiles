return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require("conform")

    conform.setup({
      -- prettier from the project's node_modules is used when available, mason's otherwise
      formatters_by_ft = {
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        html = { "prettier" },
        htmlangular = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        json = { "prettier" },
      },
      format_on_save = {
        timeout_ms = 1000,
      },
    })

    vim.keymap.set({ "n", "v" }, "<leader>mp", function()
      conform.format({ timeout_ms = 1000 })
    end, { desc = "Format file or range" })
  end,
}
