return {
  "mason-org/mason.nvim",
  dependencies = {
    "mason-org/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  config = function()
    local mason = require("mason")

    local mason_lspconfig = require("mason-lspconfig")

    local mason_tool_installer = require("mason-tool-installer")

    -- enable mason and configure icons
    mason.setup({
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    })

    mason_lspconfig.setup({
      -- list of servers for mason to install
      ensure_installed = {
        "html",
        "cssls",
        "tailwindcss",
        "lua_ls",
        "pyright",
        "gopls",
        "jsonls",
        "bashls",
        "yamlls",
        "dockerls",
        "sqlls",
        "clangd",
        "rust_analyzer",
        "ts_ls",
        "angularls",
        "eslint",
        "emmet_language_server", -- replaces emmet_ls, which merged tags like "<<div></div>"
      },
    })

    mason_tool_installer.setup({
      ensure_installed = {
        "prettier", -- prettier formatter
        "stylua", -- lua formatter
        -- "isort", -- python formatter
        -- "black", -- python formatter
        -- "pylint",
        "eslint_d",
      },
    })
  end,
}
