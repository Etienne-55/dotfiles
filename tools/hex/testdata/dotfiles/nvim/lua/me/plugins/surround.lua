return {
  "kylechui/nvim-surround",
  config = function()
    for _, char in ipairs({ ")", '"' }) do
      vim.keymap.set("n", "<leader>" .. char, "ysiw" .. char, { remap = true, desc = "Wrap word in " .. char })
    end
  end,
}
