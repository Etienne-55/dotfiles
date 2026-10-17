return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- the main branch does not support lazy-loading
  build = ":TSUpdate",
  config = function()
    -- ensure these language parsers are installed (needs the tree-sitter CLI)
    require("nvim-treesitter").install({
      "json",
      "markdown",
      "markdown_inline",
      "javascript",
      "typescript",
      "tsx",
      "yaml",
      "rust",
      "php",
      "html",
      "css",
      "graphql",
      "bash",
      "lua",
      "vim",
      "dockerfile",
      "gitignore",
      "query",
      "vimdoc",
      "c",
      "swift",
      "go",
      "python",
      "svelte",
      "prisma",
      "angular",
      "scss",
    })

    -- always treat Angular component templates as htmlangular
    -- (neovim only detects it when control-flow syntax is in the first 40 lines)
    vim.filetype.add({
      pattern = { [".*%.component%.html"] = "htmlangular" },
    })

    -- enable syntax highlighting and indentation for any filetype with a parser
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("UserTreesitter", {}),
      callback = function(ev)
        if pcall(vim.treesitter.start, ev.buf) then
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })

    -- incremental selection, using Neovim's built-in `an` / `in`
    vim.keymap.set("n", "<C-space>", "van", { remap = true, desc = "Start treesitter selection" })
    vim.keymap.set("x", "<C-space>", "an", { remap = true, desc = "Expand treesitter selection" })
    vim.keymap.set("x", "<bs>", "in", { remap = true, desc = "Shrink treesitter selection" })

    -- use bash parser for zsh files
    vim.treesitter.language.register("bash", "zsh")
  end,
}
