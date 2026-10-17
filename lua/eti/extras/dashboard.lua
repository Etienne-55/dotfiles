-- Pokémon start screen for the snacks dashboard; the spec is in plugins/dashboard.lua.
-- Headers; each Pokémon group further down picks which of these it shows with
local titles = {
  -- {
  --   "                                                     ",
  --   "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
  --   "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
  --   "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
  --   "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
  --   "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
  --   "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
  --   "                                                     ",
  -- },
  -- {
  --   [[                                                                                                   ]],
  --   [[ /\\\\\_____/\\\_______________________________/\\\________/\\\___________________________         ]],
  --   [[ \/\\\\\\___\/\\\______________________________\/\\\_______\/\\\__________________________         ]],
  --   [[ _\/\\\/\\\__\/\\\______________________________\//\\\______/\\\___/\\\_____________________       ]],
  --   [[  _\/\\\//\\\_\/\\\_____/\\\\\\\\______/\\\\\_____\//\\\____/\\\___\///_____/\\\\\__/\\\\\__       ]],
  --   [[   _\/\\\\//\\\\/\\\___/\\\/////\\\___/\\\///\\\____\//\\\__/\\\_____/\\\__/\\\///\\\\\///\\\_     ]],
  --   [[    _\/\\\_\//\\\/\\\__/\\\\\\\\\\\___/\\\__\//\\\____\//\\\/\\\_____\/\\\_\/\\\_\//\\\__\/\\\     ]],
  --   [[     _\/\\\__\//\\\\\\_\//\\///////___\//\\\__/\\\______\//\\\\\______\/\\\_\/\\\__\/\\\__\/\\\_   ]],
  --   [[      _\/\\\___\//\\\\\__\//\\\\\\\\\\__\///\\\\\/________\//\\\_______\/\\\_\/\\\__\/\\\__\/\\\   ]],
  --   [[       _\///_____\/////____\//////////_____\/////___________\///________\///__\///___\///___\///__ ]],
  --   [[                                                                                                   ]],
  -- },
  red = {
    accent = "red",
    [[                                                     ]],
    [[  ███▄    █ ▓█████  ▒█████   ██▒   █▓ ██▓ ███▄ ▄███▓ ]],
    [[  ██ ▀█   █ ▓█   ▀ ▒██▒  ██▒▓██░   █▒▓██▒▓██▒▀█▀ ██▒ ]],
    [[ ▓██  ▀█ ██▒▒███   ▒██░  ██▒ ▓██  █▒░▒██▒▓██    ▓██░ ]],
    [[ ▓██▒  ▐▌██▒▒▓█  ▄ ▒██   ██░  ▒██ █░░░██░▒██    ▒██  ]],
    [[ ▒██░   ▓██░░▒████▒░ ████▓▒░   ▒▀█░  ░██░▒██▒   ░██▒ ]],
    [[ ░ ▒░   ▒ ▒ ░░ ▒░ ░░ ▒░▒░▒░    ░ ▐░  ░▓  ░ ▒░   ░  ░ ]],
    [[ ░ ░░   ░ ▒░ ░ ░  ░  ░ ▒ ▒░    ░ ░░   ▒ ░░  ░      ░ ]],
    [[    ░   ░ ░    ░   ░ ░ ░ ▒       ░░   ▒ ░░      ░    ]],
    [[          ░    ░  ░    ░ ░        ░   ░         ░    ]],
    [[                                 ░                   ]],
    [[                                                     ]],
  },
  -- {
  --   [[                     ]],
  --   [[ -. . --- ...- .. -- ]],
  --   [[                     ]],
  -- },
  purple = {
    accent = "purple",
    [[                                       ]],
    [[    ▄   ▄███▄   ████▄     ▄   ▄█ █▀▄▀█ ]],
    [[     █  █▀   ▀  █   █      █  ██ █ █ █ ]],
    [[ ██   █ ██▄▄    █   █ █     █ ██ █ ▄ █ ]],
    [[ █ █  █ █▄   ▄▀ ▀████  █    █ ▐█ █   █ ]],
    [[ █  █ █ ▀███▀           █  █   ▐    █  ]],
    [[ █   ██                  █▐        ▀   ]],
    [[                         ▐             ]],
    [[                                       ]],
  },
  elite = {
    accent = "green", -- plant green
    [[                                   ]],
    [[  ▐ ▄ ▄▄▄ .       ▌ ▐·▪  • ▌ ▄ ·.  ]],
    [[ •█▌▐█▀▄.▀·▪     ▪█·█▌██ ·██ ▐███▪ ]],
    [[ ▐█▐▐▌▐▀▀▪▄ ▄█▀▄ ▐█▐█•▐█·▐█ ▌▐▌▐█· ]],
    [[ ██▐█▌▐█▄▄▌▐█▌.▐▌ ███ ▐█▌██ ██▌▐█▌ ]],
    [[ ▀▀ █▪ ▀▀▀  ▀█▄▀▪. ▀  ▀▀▀▀▀  █▪▀▀▀ ]],
    [[                                   ]],
  },
  isometric = {
    accent = "cyan",
    [[                                                                                   ]],
    [[     /\__\         /\  \         /\  \         /\__\          ___        /\__\     ]],
    [[    /::|  |       /::\  \       /::\  \       /:/  /         /\  \      /::|  |    ]],
    [[   /:|:|  |      /:/\:\  \     /:/\:\  \     /:/  /          \:\  \    /:|:|  |    ]],
    [[  /:/|:|  |__   /::\~\:\  \   /:/  \:\  \   /:/__/  ___      /::\__\  /:/|:|__|__  ]],
    [[ /:/ |:| /\__\ /:/\:\ \:\__\ /:/__/ \:\__\  |:|  | /\__\  __/:/\/__/ /:/ |::::\__\ ]],
    [[ \/__|:|/:/  / \:\~\:\ \/__/ \:\  \ /:/  /  |:|  |/:/  / /\/:/  /    \/__/~~/:/  / ]],
    [[     |:/:/  /   \:\ \:\__\    \:\  /:/  /   |:|__/:/  /  \::/__/           /:/  /  ]],
    [[     |::/  /     \:\ \/__/     \:\/:/  /     \::::/__/    \:\__\          /:/  /   ]],
    [[     /:/  /       \:\__\        \::/  /       ~~~~         \/__/         /:/  /    ]],
    [[     \/__/         \/__/         \/__/                                   \/__/     ]],
    [[                                                                                   ]],
  },
}
-- same dripping art as red, in honey instead of blood
titles.honey = vim.deepcopy(titles.red)
titles.honey.accent = "orange"

-- header rows without the blank padding ones (sections handle spacing)
local function logo_lines(title)
  local lines = {}
  for _, l in ipairs(title) do
    if vim.trim(l) ~= "" then
      lines[#lines + 1] = l
    end
  end
  return lines
end

local function logo_width(lines)
  local w = 0
  for _, l in ipairs(lines) do
    w = math.max(w, vim.api.nvim_strwidth(l))
  end
  return w
end

-- Two columns (Pokémon | recent files) with no gap. The header is split down the
-- middle, one half on top of each column, so it still reads as one full-width logo.
-- Sized for the widest header, so the layout is the same whichever one comes up.
local PANE_W = 55
for _, title in pairs(titles) do
  PANE_W = math.max(PANE_W, math.ceil(logo_width(logo_lines(title)) / 2))
end

local function header(title)
  local lines = logo_lines(title)
  local w = logo_width(lines)
  local h = { title = title, lines = lines, left = {}, right = {} }
  for _, l in ipairs(lines) do
    local left = math.floor((2 * PANE_W - w) / 2)
    l = (" "):rep(left) .. l .. (" "):rep(2 * PANE_W - left - vim.api.nvim_strwidth(l))
    h.left[#h.left + 1] = vim.fn.strcharpart(l, 0, PANE_W)
    h.right[#h.right + 1] = vim.fn.strcharpart(l, PANE_W)
  end
  return h
end

-- Random Pokémon from these groups (pokemon-colorscripts sprites), drawn as highlighted
-- text (a terminal section flickers while the dashboard lays out). Each group lists
-- the headers its species show with; one is picked at random when there are several.
-- A group with `odds` is rare: it's rolled first and comes up 1 in `odds` encounters.
local POKE_DIR = vim.fn.expand("~/.local/share/pokemon-colorscripts")
local POKEMON = {
  { titles = { titles.honey }, odds = 100, "munchlax" },
  { titles = { titles.red, titles.purple }, "gengar", "gastly", "haunter", "spiritomb", "dusknoir" },
  { titles = { titles.elite }, "venusaur", "torterra" },
  { titles = { titles.isometric }, "porygon" },
}
-- the common groups flattened, so every species is equally likely whatever the size of its group
local SPECIES = {}
for _, group in ipairs(POKEMON) do
  for _, name in ipairs(group.odds and {} or group) do
    SPECIES[#SPECIES + 1] = { name = name, titles = group.titles }
  end
end
-- rolled on every dashboard open, like a wild encounter. 1 in 8192 is full odds
-- in Gen 2-5, where all of these come from (Gen 6+ games use 4096)
local SHINY_ODDS = 8192

-- true random from the OS (math.random is seeded from the clock in seconds, so
-- opens within the same second would roll the same). 8192 divides 2^32, so no bias
local function roll(n)
  local b = vim.uv.random(4)
  return (b:byte(1) * 2 ^ 24 + b:byte(2) * 2 ^ 16 + b:byte(3) * 2 ^ 8 + b:byte(4)) % n + 1
end

local function species()
  for _, group in ipairs(POKEMON) do
    if group.odds and roll(group.odds) == 1 then
      return { name = group[roll(#group)], titles = group.titles }
    end
  end
  return SPECIES[roll(#SPECIES)]
end

-- pick a species, one of its headers, and roll for shiny; falls back to regular
-- if there's no shiny sprite. Returns the sprite file and the header
local function encounter()
  local dir = POKE_DIR .. "/colorscripts/small/"
  local mon = species()
  local title = mon.titles[roll(#mon.titles)]
  if roll(SHINY_ODDS) == 1 and vim.fn.filereadable(dir .. "shiny/" .. mon.name) == 1 then
    return dir .. "shiny/" .. mon.name, title
  end
  return dir .. "regular/" .. mon.name, title
end

local function sprite(file)
  if vim.fn.filereadable(file) == 0 then
    return nil
  end

  local rows, max = {}, 0
  for _, line in ipairs(vim.fn.readfile(file)) do
    local chunks, w, fg, bg = {}, 0, nil, nil
    local function push(str)
      if str == "" then
        return
      end
      local hl
      if fg or bg then
        hl = ("Poke_%s_%s"):format(fg or "none", bg or "none")
        vim.api.nvim_set_hl(0, hl, { fg = fg and "#" .. fg, bg = bg and "#" .. bg })
      end
      chunks[#chunks + 1] = { str, hl = hl }
      w = w + vim.api.nvim_strwidth(str)
    end
    local pos = 1
    while true do
      local s, e, codes = line:find("\27%[([%d;]*)m", pos)
      push(line:sub(pos, (s or 0) - 1))
      if not s then
        break
      end
      local c = vim.split(codes, ";")
      if c[1] == "38" then
        fg = ("%02x%02x%02x"):format(c[3], c[4], c[5])
      elseif c[1] == "48" then
        bg = ("%02x%02x%02x"):format(c[3], c[4], c[5])
      else
        fg, bg = nil, nil
      end
      pos = e + 1
    end
    rows[#rows + 1] = { chunks = chunks, width = w }
    max = math.max(max, w)
  end

  -- pad rows to the same width so centering doesn't skew the sprite
  local text = {}
  for i, row in ipairs(rows) do
    vim.list_extend(text, row.chunks)
    text[#text + 1] = { (" "):rep(max - row.width) .. (i < #rows and "\n" or "") }
  end
  return { text = text, width = max }
end

-- Idle bounce like the old Nintendo games: the sprite moves between two rows.
-- A blank row goes above or below it, so the column height (and the rest of the
-- screen) never changes. The blank row is real spaces: snacks' own top padding
-- is an empty row, which drags the right column's text on that row to the left.
local BOUNCE_MS = 400
local bounce = 0 -- 0 = up, 1 = down
local timer
local poke = false -- parsed sprite, cached across bounce redraws; false = roll a new one
local logo -- header for the current encounter, from header()

vim.api.nvim_create_autocmd("User", {
  pattern = "SnacksDashboardOpened",
  callback = function()
    timer = timer or vim.uv.new_timer()
    timer:start(BOUNCE_MS, BOUNCE_MS, vim.schedule_wrap(function()
      bounce = 1 - bounce
      Snacks.dashboard.update()
    end))
  end,
})
vim.api.nvim_create_autocmd("User", {
  pattern = "SnacksDashboardClosed",
  callback = function()
    poke = false -- next open is a new encounter
    if timer then
      timer:stop()
    end
  end,
})

-- Keep the cursor on its file across bounce frames. Sprite blocks are 3 bytes
-- and spaces 1, so when the sprite shifts a row, the file text on that line moves
-- in bytes; the cursor keeps its byte column, lands in the Pokémon column (no
-- items there) and snacks throws it back to the first file. Save it as a
-- character column before each redraw and put it back after.
local cursor -- { win, row, char } saved before a redraw
local function dashboard_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
      return win
    end
  end
end
local function line_at(win, row)
  return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), row - 1, row, false)[1] or ""
end

vim.api.nvim_create_autocmd("User", {
  pattern = "SnacksDashboardUpdatePre",
  callback = function()
    cursor = nil
    local win = dashboard_win()
    if win and vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win)) > 1 then -- skip the first render
      local pos = vim.api.nvim_win_get_cursor(win)
      cursor = { win = win, row = pos[1], char = vim.fn.charidx(line_at(win, pos[1]), pos[2]) }
    end
  end,
})
vim.api.nvim_create_autocmd("User", {
  pattern = "SnacksDashboardUpdatePost",
  callback = function()
    if not (cursor and vim.api.nvim_win_is_valid(cursor.win)) then
      return
    end
    local win = cursor.win
    if cursor.row <= vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win)) then
      local col = vim.fn.byteidx(line_at(win, cursor.row), cursor.char)
      if col >= 0 then
        vim.api.nvim_win_set_cursor(win, { cursor.row, col })
      end
    end
    cursor = nil
  end,
})

-- q or Esc quits nvim back to the terminal (snacks sets its filetype with
-- events off, so a FileType autocmd never fires; map on open instead)
vim.api.nvim_create_autocmd("User", {
  pattern = "SnacksDashboardOpened",
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].filetype == "snacks_dashboard" then
        for _, key in ipairs({ "q", "<esc>" }) do
          vim.keymap.set("n", key, "<cmd>qa<cr>", { buffer = buf, nowait = true, silent = true })
        end
      end
    end
  end,
})

-- each header's `accent` names a color of the palette (eti.core.palette)
local function logo_hl()
  local color = logo and require("eti.core.palette")[logo.title.accent]
  vim.api.nvim_set_hl(0, "DashboardLogo", color and { fg = color } or { link = "SnacksDashboardHeader" })
end
vim.api.nvim_create_autocmd("ColorScheme", { callback = logo_hl })

-- sprite text for the current bounce frame
local function poke_frame()
  local blank = { (" "):rep(poke.width) }
  if bounce == 1 then
    return vim.list_extend({ { blank[1] .. "\n" } }, poke.text)
  end
  local text = vim.list_extend({}, poke.text)
  text[#text + 1] = { "\n" .. blank[1] }
  return text
end

local function sections()
  if poke == false then
    local file, title = encounter()
    poke = sprite(file)
    logo = header(title)
    logo_hl()
  end
  local function section(l, extra)
    return vim.tbl_extend("force", { text = { { table.concat(l, "\n"), hl = "DashboardLogo" } }, padding = 2 }, extra or {})
  end
  local files = { icon = " ", title = "Recent Files", section = "recent_files", cwd = true, limit = 8, indent = 2, padding = 1 }

  -- window too narrow for two columns: stack everything, full header on top
  if vim.o.columns < 2 * PANE_W then
    return {
      section(logo.lines, { align = "center" }),
      files,
      poke and { text = poke_frame(), align = "center" } or { enabled = false },
    }
  end

  files.pane = 2
  return {
    section(logo.left, { pane = 1 }),
    section(logo.right, { pane = 2 }),
    poke and { pane = 1, text = poke_frame(), align = "center" } or { enabled = false },
    files,
  }
end

return { width = PANE_W, sections = sections }
