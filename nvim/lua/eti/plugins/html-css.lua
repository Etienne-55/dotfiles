-- completes css class names inside class="..." from the stylesheets linked in the file
-- (<link href="..."> local files and CDN urls like bootstrap) plus the global ones below
return {
  "Jezda1337/nvim-html-css",
  -- markup files only: its setup re-sources every plugin/ script and looks for ./.nvim.lua
  ft = {
    "html",
    "htmlangular",
    "htmldjango",
    "javascriptreact",
    "typescriptreact",
    "vue",
    "svelte",
    "php",
    "astro",
  },
  -- no nvim-cmp: it serves completions as an in-process LSP server, which cmp-nvim-lsp picks up
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  opts = {
    -- file extensions, not filetypes (it matches "*.<ext>"); angular/django templates are *.html
    enable_on = { "html", "jsx", "tsx", "vue", "svelte", "php", "astro" },
    documentation = { auto_show = true },
    -- stylesheets available in every file, even without a <link> tag
    style_sheets = {
      -- bootstrap 3 (col-xs-*); switch to bootstrap@5.3.3 when the project upgrades
      "https://cdn.jsdelivr.net/npm/bootstrap@3.4.1/dist/css/bootstrap.min.css",
    },
  },
  config = function(_, opts)
    -- setup() runs ./.nvim.lua (its per-project config) with a bare dofile(), so a cloned
    -- repo's file ran unasked, and it switches 'exrc' on for the rest of the session.
    -- Only run that file once it's trusted (the vim.secure.read prompt, or :trust), and
    -- put 'exrc' back.
    -- It also runs `runtime! plugin/**`, which with ft-loading would re-run every already
    -- loaded plugin/ script mid-session (double keymaps/handlers); lazy.nvim has already
    -- sourced them, so skip just that call
    local exrc, run_file, cmd = vim.o.exrc, dofile, vim.cmd
    vim.cmd = setmetatable({}, {
      __index = cmd,
      __call = function(_, c, ...)
        if c ~= "runtime! plugin/**/*.{vim,lua}" then
          return cmd(c, ...)
        end
      end,
    })
    dofile = function(path)
      local code = vim.secure.read(path)
      if code then
        return assert(loadstring(code, "@" .. path))()
      end
    end
    local ok, err = pcall(require("html-css").setup, opts)
    dofile, vim.o.exrc, vim.cmd = run_file, exrc, cmd
    assert(ok, err)
  end,
}
