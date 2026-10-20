-- Shows the search position ([1/3]) as virtual text next to the match, instead of in
-- the statusline where long file names pushed it around. Starts by itself after a
-- / or ? search; n, N, * and # need to call start() to update it. Every jump also
-- centers the match (zz), like <CR> on a search does (core/keymaps).
local function lens(keys)
  return keys .. "zz<Cmd>lua require('hlslens').start()<CR>"
end

return {
  "kevinhwang91/nvim-hlslens",
  event = "VeryLazy",
  keys = {
    { "n", lens("<Cmd>execute('normal! ' . v:count1 . 'n')<CR>"), desc = "Next match" },
    { "N", lens("<Cmd>execute('normal! ' . v:count1 . 'N')<CR>"), desc = "Prev match" },
    { "*", lens("*"), desc = "Search word forward" },
    { "#", lens("#"), desc = "Search word backward" },
  },
  opts = {
    nearest_only = true, -- the count only on the match under the cursor, not on every one
  },
}
