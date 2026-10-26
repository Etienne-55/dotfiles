-- File icons (lualine, the recent files, nvim-tree, telescope, oil); only overrides here
return {
  "nvim-tree/nvim-web-devicons",
  opts = {
    override_by_extension = {
      -- Ferris the crab (nf-linux-ferris) instead of the gear-like Rust logo; same color
      rs = { icon = "\u{f323}", color = "#DEA584", cterm_color = "216", name = "Rs" },
    },
  },
}
