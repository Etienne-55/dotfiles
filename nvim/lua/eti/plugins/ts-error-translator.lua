-- Rewrites cryptic TypeScript errors from ts_ls into plain English, wherever
-- diagnostics show up (virtual text, <leader>j float, trouble).
return {
  "dmmulroy/ts-error-translator.nvim",
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact", "svelte" },
  opts = {},
}
