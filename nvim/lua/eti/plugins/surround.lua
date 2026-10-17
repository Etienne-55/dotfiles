return {
  "kylechui/nvim-surround",
  version = "*",
  event = "VeryLazy",
  config = function()
    require("nvim-surround").setup({
    })

    -- <leader> + closing char wraps the word under cursor (or the visual selection)
    for _, char in ipairs({ "]", ")", "}", '"', "'", "`" }) do
      vim.keymap.set("n", "<leader>" .. char, "ysiw" .. char, { remap = true, desc = "Wrap word in " .. char })
      vim.keymap.set("x", "<leader>" .. char, "S" .. char, { remap = true, desc = "Wrap selection in " .. char })
    end
  end,
}
