return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    { "antosha417/nvim-lsp-file-operations", config = true },
    { "folke/lazydev.nvim", ft = "lua", opts = {} },
    { "b0o/schemastore.nvim", version = false }, -- json/yaml schemas (package.json, tsconfig, ...)
  },
  config = function()
    local cmp_nvim_lsp = require("cmp_nvim_lsp")

    local keymap = vim.keymap
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspConfig", {}),
      callback = function(ev)
        -- cmp-nvim-lsp only picks up new servers on InsertEnter, so a server that finishes
        -- starting while you're already typing gave no completions until you re-entered insert
        pcall(vim.api.nvim_exec_autocmds, "InsertEnter", { group = "cmp_nvim_lsp", modeline = false })

        -- Buffer local mappings.
        -- See `:help vim.lsp.*` for documentation on any of the below functions
        local opts = { buffer = ev.buf, silent = true }

        -- set keybinds
        opts.desc = "Show LSP references"
        keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references

        opts.desc = "Go to declaration"
        keymap.set("n", "gD", vim.lsp.buf.declaration, opts) -- go to declaration

        opts.desc = "Show LSP definitions"
        keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts) -- show lsp definitions

        opts.desc = "Show LSP implementations"
        keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts) -- show lsp implementations

        opts.desc = "Show LSP type definitions"
        keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- show lsp type definitions

        opts.desc = "See available code actions"
        keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection

        opts.desc = "Smart rename"
        keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts) -- smart rename

        opts.desc = "Show buffer diagnostics"
        keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file

        opts.desc = "Show line diagnostics"
        keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line

        opts.desc = "Go to previous diagnostic"
        keymap.set("n", "[d", function()
          vim.diagnostic.jump({ count = -1, float = true })
        end, opts) -- jump to previous diagnostic in buffer

        opts.desc = "Go to next diagnostic"
        keymap.set("n", "]d", function()
          vim.diagnostic.jump({ count = 1, float = true })
        end, opts) -- jump to next diagnostic in buffer

        opts.desc = "Show documentation for what is under cursor"
        keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

        opts.desc = "Restart LSP"
        keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts) -- mapping to restart lsp if necessary
      end,
    })

    -- used to enable autocompletion (assign to every lsp server config)
    local capabilities = cmp_nvim_lsp.default_capabilities()

    vim.diagnostic.config({
      virtual_text = true,
      underline = true,
      update_in_insert = false,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = " ",
          [vim.diagnostic.severity.WARN] = " ",
          [vim.diagnostic.severity.HINT] = "󰠠 ",
          [vim.diagnostic.severity.INFO] = " ",
        },
      },
    })

    vim.lsp.config("*", {
      capabilities = capabilities,
    })

    vim.lsp.config("svelte", {
      on_attach = function(client, bufnr)
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = { "*.js", "*.ts" },
          callback = function(ctx)
            -- Here use ctx.match instead of ctx.file
            client.notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
          end,
        })
      end,
    })

    vim.lsp.config("graphql", {
      filetypes = { "graphql", "gql", "svelte", "typescriptreact", "javascriptreact" },
    })

    -- also run the html server in Angular templates (tag and inline css completions)
    vim.lsp.config("html", {
      filetypes = { "html", "htmlangular" },
    })

    -- while tsserver loads the project, completions come from a syntax-only server that knows
    -- no auto-imports (no `Component`, `inject`, ... from @angular/core), and cmp keeps that
    -- list for the whole word; "never" waits for the real project instead
    vim.lsp.config("ts_ls", {
      init_options = {
        tsserver = { useSyntaxServer = "never" },
        -- in a class, complete members of implemented interfaces / base classes as full
        -- method stubs (`ngOnInit(): void {}` once the class implements OnInit)
        preferences = { includeCompletionsWithClassMemberSnippets = true },
      },
    })

    -- only start in Angular workspaces (angular.json / nx.json), not in every ts/html file.
    -- --forceStrictTemplates: projects with fullTemplateTypeCheck/strictTemplates off only check
    -- top-level template expressions, so gd/K/rename found nothing inside <ng-template>, *ngIf,
    -- *ngFor...; it only changes the editor's language service, not `ng build`
    local ngserver_cmd = vim.lsp.config.angularls.cmd
    vim.lsp.config("angularls", {
      workspace_required = true,
      cmd = function(dispatchers, config)
        -- lspconfig builds the probe-location args itself, so append the flag to its command
        local rpc_start = vim.lsp.rpc.start
        vim.lsp.rpc.start = function(cmd, ...)
          vim.lsp.rpc.start = rpc_start
          table.insert(cmd, "--forceStrictTemplates")
          return rpc_start(cmd, ...)
        end
        local ok, rpc = pcall(ngserver_cmd, dispatchers, config)
        vim.lsp.rpc.start = rpc_start
        assert(ok, rpc)
        return rpc
      end,
    })

    vim.lsp.config("gopls", {
      settings = {
        gopls = {
          analyses = {
            unusedparams = true,
            shadow = true,
          },
          staticcheck = true,
          gofumpt = true,
        },
      },
    })

    vim.lsp.config("jsonls", {
      settings = {
        json = {
          schemas = require("schemastore").json.schemas(),
          validate = { enable = true },
        },
      },
    })

    vim.lsp.config("yamlls", {
      settings = {
        yaml = {
          -- use schemastore instead of the built-in schema store
          schemaStore = { enable = false, url = "" },
          schemas = require("schemastore").yaml.schemas(),
        },
      },
    })

    vim.lsp.config("lua_ls", {
      settings = {
        Lua = {
          -- make the language server recognize "vim" global
          diagnostics = {
            globals = { "vim" },
          },
          completion = {
            callSnippet = "Replace",
          },
        },
      },
    })
  end,
}
