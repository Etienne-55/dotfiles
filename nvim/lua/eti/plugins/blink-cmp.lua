-- Completion (replaces nvim-cmp, its cmp-* sources, cmp_luasnip and lspkind)
return {
  "saghen/blink.cmp",
  version = "1.*", -- release tags ship a prebuilt fuzzy matcher, no rust toolchain needed
  event = { "InsertEnter", "CmdlineEnter" }, -- CmdlineEnter so "/" completion works before any insert
  dependencies = {
    {
      "L3MON4D3/LuaSnip",
      version = "v2.*",
      -- install jsregexp (optional!).
      build = "make install_jsregexp",
      dependencies = { "rafamadriz/friendly-snippets" }, -- useful snippets
      config = function()
        local luasnip = require("luasnip")

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
      end,
    },
  },
  opts = {
    keymap = {
      preset = "none",
      ["<C-k>"] = { "select_prev", "fallback" }, -- previous suggestion
      ["<C-j>"] = { "select_next", "fallback" }, -- next suggestion
      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<C-b>"] = { "scroll_documentation_up", "fallback" },
      ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" }, -- show completion suggestions
      ["<C-e>"] = { "hide", "fallback" }, -- close completion window
      ["<CR>"] = { "accept", "fallback" }, -- accept the selected suggestion (nothing is preselected)
      -- next / previous snippet placeholder (snippets and LSP function arguments); a plain Tab everywhere else
      ["<Tab>"] = { "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "snippet_backward", "fallback" },
    },
    completion = {
      -- nothing selected until <C-j>/<C-k>, and the selection isn't typed into the buffer
      list = { selection = { preselect = false, auto_insert = false } },
      documentation = { auto_show = true },
    },
    snippets = { preset = "luasnip" },
    sources = {
      -- lsp also gives css class names in class="..." (html-css runs as an LSP server)
      default = { "lazydev", "lsp", "snippets", "buffer", "path" },
      providers = {
        -- neovim lua api (lazydev.nvim), above everything else
        lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
        -- snippets insert their whole text ("console.log()", "<span></span>"), so hide them
        -- right after "." or "<", otherwise they merge with what's already typed
        snippets = {
          should_show_items = function(ctx)
            local char_before = ctx.line:sub(ctx.bounds.start_col - 1, ctx.bounds.start_col - 1)
            return char_before ~= "." and char_before ~= "<"
          end,
        },
      },
    },
    cmdline = {
      -- words from the buffer while searching with "/"; ":" commands get no menu, as before
      sources = function()
        return vim.fn.getcmdtype() == "/" and { "buffer" } or {}
      end,
      -- arrows pick a suggestion (it gets written into the search), then Enter searches it
      keymap = {
        preset = "cmdline",
        ["<Down>"] = { "select_next", "fallback" },
        ["<Up>"] = { "select_prev", "fallback" },
      },
      completion = { menu = { auto_show = true } },
    },
  },
}
