return {
  "hrsh7th/nvim-cmp",
  event = { "InsertEnter", "CmdlineEnter" }, -- CmdlineEnter so "/" completion works before any insert
  dependencies = {
    "hrsh7th/cmp-buffer", -- source for text in buffer
    "hrsh7th/cmp-path", -- source for file system paths
    "hrsh7th/cmp-cmdline", -- source for cmd completion
    {
      "L3MON4D3/LuaSnip",
      version = "v2.*",
      -- install jsregexp (optional!).
      build = "make install_jsregexp",
    },
    "saadparwaiz1/cmp_luasnip", -- for autocompletion
    "rafamadriz/friendly-snippets", -- useful snippets
    "onsails/lspkind.nvim", -- vs-code like pictograms
  },
  config = function()
    local cmp = require("cmp")

    local luasnip = require("luasnip")

    local lspkind = require("lspkind")

    -- loads vscode style snippets from installed plugins (e.g. friendly-snippets)
    require("luasnip.loaders.from_vscode").lazy_load()

    -- friendly-snippets files its Angular snippets (a-component, a-service, ...) under an
    -- "angular" filetype that no buffer has, so pull them into ts and angular templates
    luasnip.filetype_extend("typescript", { "angular" })
    luasnip.filetype_extend("htmlangular", { "angular" })

    -- Angular lifecycle hooks: ts_ls only suggests them once the class `implements` the
    -- interface, so type the hook name and pick the snippet instead
    local hooks = {
      ngOnInit = "", ngOnDestroy = "", ngOnChanges = "changes: SimpleChanges", ngDoCheck = "",
      ngAfterViewInit = "", ngAfterViewChecked = "", ngAfterContentInit = "", ngAfterContentChecked = "",
    }
    local hook_snippets = {}
    for name, params in pairs(hooks) do
      table.insert(hook_snippets, luasnip.snippet(name, {
        luasnip.text_node({ name .. "(" .. params .. "): void {", "\t" }),
        luasnip.insert_node(0),
        luasnip.text_node({ "", "}" }),
      }))
    end
    luasnip.add_snippets("typescript", hook_snippets)

    cmp.setup.cmdline("/", {
      -- arrows pick a suggestion (it gets written into the search), then Enter searches it
      mapping = cmp.mapping.preset.cmdline({
        ["<Down>"] = { c = cmp.mapping.select_next_item() },
        ["<Up>"] = { c = cmp.mapping.select_prev_item() },
      }),
      sources = {
        { name = "buffer" },
      },
    })

    cmp.setup({
      completion = {
        completeopt = "menu,menuone,preview,noselect",
      },
      snippet = { -- configure how nvim-cmp interacts with snippet engine
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-k>"] = cmp.mapping.select_prev_item(), -- previous suggestion
        ["<C-j>"] = cmp.mapping.select_next_item(), -- next suggestion
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(), -- show completion suggestions
        ["<C-e>"] = cmp.mapping.abort(), -- close completion window
        ["<CR>"] = cmp.mapping.confirm({ select = false }),
        -- next / previous snippet placeholder (snippets and LSP function arguments): nvim's own
        -- <Tab> only jumps vim.snippet, not LuaSnip; a plain Tab everywhere else
        ["<Tab>"] = cmp.mapping(function(fallback)
          if luasnip.locally_jumpable(1) then
            luasnip.jump(1)
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if luasnip.locally_jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      }),
      -- sources for autocompletion
      sources = cmp.config.sources({
        { name = "lazydev", group_index = 0 }, -- neovim lua api (lazydev.nvim)
        { name = "nvim_lsp"}, -- also css class names in class="..." (html-css runs as an LSP server)
        {
          name = "luasnip", -- snippets
          -- snippets insert their whole text ("console.log()", "<span></span>"), so hide them
          -- right after "." or "<", otherwise they merge with what's already typed
          entry_filter = function(entry, ctx)
            local offset = entry:get_offset()
            local char_before = ctx.cursor_before_line:sub(offset - 1, offset - 1)
            return char_before ~= "." and char_before ~= "<"
          end,
        },
        { name = "buffer" }, -- text within current buffer
        { name = "path" }, -- file system paths
      }),

      -- configure lspkind for vs-code like pictograms in completion menu
      formatting = {
        format = lspkind.cmp_format({
          maxwidth = 50,
          ellipsis_char = "...",
        }),
      },
    })
  end,
}

