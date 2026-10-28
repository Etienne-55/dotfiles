return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns

      local function map(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end

      -- Navigation: the hunk always lands in the middle of the screen, even when it
      -- was already visible. nav_hunk is async, so center from its callback.
      local function nav(direction)
        return function()
          gs.nav_hunk(direction, nil, vim.schedule_wrap(function() vim.cmd("normal! zz") end))
        end
      end
      map("n", "]h", nav("next"), "Next Hunk")
      map("n", "[h", nav("prev"), "Prev Hunk")
      -- shift+[ / shift+] too; normal mode only, so d} / v} keep their paragraph motion
      -- these two also flash the minimap (extras/minimap.lua)
      local function nav_with_minimap(direction)
        local jump = nav(direction)
        return function()
          jump()
          require("eti.extras.minimap").peek()
        end
      end
      map("n", "}", nav_with_minimap("next"), "Next Hunk")
      map("n", "{", nav_with_minimap("prev"), "Prev Hunk")

      -- Actions
      map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
      map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
      map("v", "<leader>hs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Stage hunk")
      map("v", "<leader>hr", function()
        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Reset hunk")

      map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
      map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")

      map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")

      map("n", "<leader>hb", function()
        gs.blame_line({ full = true })
      end, "Blame line")
      map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle line blame")

      map("n", "<leader>hi", function()
        local on = gs.toggle_linehl()
        gs.toggle_deleted(on)
        gs.toggle_word_diff(on)
      end, "Toggle inline diff")

      map("n", "<leader>hd", gs.diffthis, "Diff this")
      map("n", "<leader>hD", function()
        gs.diffthis("~")
      end, "Diff this ~")

      -- Text object
      map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Gitsigns select hunk")
    end,
  },
}
