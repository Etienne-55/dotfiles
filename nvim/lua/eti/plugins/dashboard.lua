-- Start screen: a random banner over the branch and worktree. Merged into the snacks.nvim spec by lazy.

-- the shell aliases (`nvim "+Pick find_files"`) go straight to a picker, and
-- `git diff dev` straight to diffview; the dashboard would only show through behind it
local from_pick = vim.iter(vim.v.argv):any(function(a)
  return vim.startswith(a, "+Pick") or vim.startswith(a, "+DiffviewOpen")
end)

local p = require("eti.core.palette")

local function mix(a, b, t) -- hex colors a and b, t of the way to b
  local out = "#"
  for i = 2, 6, 2 do
    local x, y = tonumber(a:sub(i, i + 1), 16), tonumber(b:sub(i, i + 1), 16)
    out = out .. ("%02x"):format(math.floor(x + (y - x) * t + 0.5))
  end
  return out
end

-- Effects color the banner one cell at a time: frame(tick, height, width) returns
-- row, col -> highlight, rows and cols counted from the banner's top-left letter.
-- `pad` adds blank cells around it, for effects that light up the empty space too;
-- `bg` paints the whole dashboard window that color

local function hsl(h, s, l) -- hue in degrees; saturation and lightness 0 to 1
  local a = s * math.min(l, 1 - l)
  local function channel(n)
    local k = (n + h / 30) % 12
    return math.floor(255 * (l - a * math.max(-1, math.min(k - 3, 9 - k, 1))) + 0.5)
  end
  return ("#%02x%02x%02x"):format(channel(0), channel(8), channel(4))
end

-- three neon colors evenly spaced around the color wheel, starting at `hue`
local function triad(hue)
  return { hsl(hue, 1, 0.62), hsl(hue + 120, 1, 0.62), hsl(hue + 240, 1, 0.62) }
end

-- Most effects loop through a few colors (palette names or hex), each blending into
-- the next; `pattern` places every cell somewhere on that loop, 1 being once around
local function animated(colors, pattern)
  local STEPS = 8 -- shades blended between two colors, so the gradient is smooth
  local shades = {}
  for i, c in ipairs(colors) do
    local a, b = p[c] or c, p[colors[i % #colors + 1]] or colors[i % #colors + 1]
    for s = 0, STEPS - 1 do
      shades[#shades + 1] = mix(a, b, s / STEPS)
    end
  end
  return {
    frame = function(tick, h, w)
      return function(row, col)
        return { fg = shades[math.floor(pattern(row, col, tick, h, w) * #shades) % #shades + 1] }
      end
    end,
  }
end

-- Bands slanting along the diagonal, a full loop every 24 cells and every 24 ticks
local function bands(colors)
  return animated(colors, function(row, col, tick)
    return (col - row + tick) / 24
  end)
end

-- Rings spreading out from the middle, like a stone dropped in water
local function ripple(colors)
  return animated(colors, function(row, col, tick, h, w)
    local d = math.sqrt(((col - (w + 1) / 2) / 2) ^ 2 + (row - (h + 1) / 2) ^ 2)
    return d / 6 - tick / 40
  end)
end

-- Twinkle: a slow drift through the colors, and each cell flashing white now and
-- then at its own pace, like stars
local function twinkle(colors)
  local drift = animated(colors, function(row, col, tick)
    return (col + 2 * row) / 48 + tick / 150
  end)
  local function rand(row, col, salt) -- fixed per cell, 0 to 1
    return (math.sin(row * 12.9898 + col * 78.233 + salt) * 43758.5453) % 1
  end
  return {
    frame = function(tick, h, w)
      local color = drift.frame(tick, h, w)
      return function(row, col)
        -- a high power keeps only the tip of the sine: short flashes, long rests
        local flash = math.max(0, math.sin(tick * (0.05 + 0.1 * rand(row, col, 1)) + 6.3 * rand(row, col, 2))) ^ 16
        return { fg = mix(color(row, col).fg, "#FFFFFF", flash) }
      end
    end,
  }
end

-- Flashlight: the banner sits in the `dark` (the background color, so it's hidden
-- until lit) and a round white `beam` wanders over it looking for ghosts; letters
-- it catches glow in bands of `ghost` and `ghost2` that ripple across them
local function flashlight(o)
  local R = 4.2 -- beam radius in rows (a cell is twice as tall as wide)
  return {
    pad = math.ceil(R),
    -- solid, so Ghostty draws it opaque (its background-opacity only applies to
    -- cells without a color of their own): pitch black, letters hidden in it
    bg = o.dark,
    frame = function(tick, h, w)
      -- sines at unrelated speeds never retrace the same path, so it reads as
      -- searching; the fast small ones are the hand shaking
      local t = tick * 0.05
      local cx = (w + 1) / 2 + (w - 1) / 2 * math.sin(t) + math.sin(t * 9)
      local cy = (h + 1) / 2 + (h - 1) / 2 * math.sin(t * 1.618 + 1) + 0.3 * math.sin(t * 7)
      return function(row, col)
        local d = math.sqrt(((col - cx) / 2) ^ 2 + (row - cy) ^ 2)
        if d >= R then
          return { fg = o.dark } -- no bg: the terminal shows through (transparent theme)
        end
        -- steep, so letters are mostly one color or the other: halfway between
        -- two colors as far apart as green and purple is a muddy grey
        local wave = math.max(0, math.min(1, 0.5 + 1.5 * math.sin(col * 0.6 + row * 0.9 - tick * 0.25)))
        return {
          -- stays green until near the edge, then fades into the dark
          fg = mix(mix(o.ghost, o.ghost2, wave), o.dark, (d / R) ^ 3),
          bg = mix(o.dark, o.beam, 0.35 * (1 - (d / R) ^ 2)), -- bright disc, soft edge
        }
      end
    end,
  }
end

-- one is picked at random on each open; `effect` defaults to purple bands
local banners = {
  -- {
  --   "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
  --   "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
  --   "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
  --   "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
  --   "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
  --   "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
  -- },
  -- {
  --   [[ /\\\\\_____/\\\_______________________________/\\\________/\\\___________________________         ]],
  --   [[ \/\\\\\\___\/\\\______________________________\/\\\_______\/\\\__________________________         ]],
  --   [[ _\/\\\/\\\__\/\\\______________________________\//\\\______/\\\___/\\\_____________________       ]],
  --   [[  _\/\\\//\\\_\/\\\_____/\\\\\\\\______/\\\\\_____\//\\\____/\\\___\///_____/\\\\\__/\\\\\__       ]],
  --   [[   _\/\\\\//\\\\/\\\___/\\\/////\\\___/\\\///\\\____\//\\\__/\\\_____/\\\__/\\\///\\\\\///\\\_     ]],
  --   [[    _\/\\\_\//\\\/\\\__/\\\\\\\\\\\___/\\\__\//\\\____\//\\\/\\\_____\/\\\_\/\\\_\//\\\__\/\\\     ]],
  --   [[     _\/\\\__\//\\\\\\_\//\\///////___\//\\\__/\\\______\//\\\\\______\/\\\_\/\\\__\/\\\__\/\\\_   ]],
  --   [[      _\/\\\___\//\\\\\__\//\\\\\\\\\\__\///\\\\\/________\//\\\_______\/\\\_\/\\\__\/\\\__\/\\\   ]],
  --   [[       _\///_____\/////____\//////////_____\/////___________\///________\///__\///___\///___\///__ ]],
  -- },
  -- {
  --   [[ -. . --- ...- .. -- ]],
  -- },
  {
    effect = bands(triad(270)), -- violet, orange, spring green
    [[    ▄   ▄███▄   ████▄     ▄   ▄█ █▀▄▀█ ]],
    [[     █  █▀   ▀  █   █      █  ██ █ █ █ ]],
    [[ ██   █ ██▄▄    █   █ █     █ ██ █ ▄ █ ]],
    [[ █ █  █ █▄   ▄▀ ▀████  █    █ ▐█ █   █ ]],
    [[ █  █ █ ▀███▀           █  █   ▐    █  ]],
    [[ █   ██                  █▐        ▀   ]],
    [[                         ▐             ]],
  },
  {
    effect = twinkle(triad(90)), -- chartreuse, azure, rose
    [[  ▐ ▄ ▄▄▄ .       ▌ ▐·▪  • ▌ ▄ ·.  ]],
    [[ •█▌▐█▀▄.▀·▪     ▪█·█▌██ ·██ ▐███▪ ]],
    [[ ▐█▐▐▌▐▀▀▪▄ ▄█▀▄ ▐█▐█•▐█·▐█ ▌▐▌▐█· ]],
    [[ ██▐█▌▐█▄▄▌▐█▌.▐▌ ███ ▐█▌██ ██▌▐█▌ ]],
    [[ ▀▀ █▪ ▀▀▀  ▀█▄▀▪. ▀  ▀▀▀▀▀  █▪▀▀▀ ]],
  },
  {
    effect = ripple(triad(0)), -- red, green, blue
    [[     /\__\        /\  \         /\  \         /\__\          ___        /\__\     ]],
    [[    /::|  |       /::\  \       /::\  \       /:/  /         /\  \      /::|  |    ]],
    [[   /:|:|  |      /:/\:\  \     /:/\:\  \     /:/  /          \:\  \    /:|:|  |    ]],
    [[  /:/|:|  |__   /::\~\:\  \   /:/  \:\  \   /:/__/  ___      /::\__\  /:/|:|__|__  ]],
    [[ /:/ |:| /\__\ /:/\:\ \:\__\ /:/__/ \:\__\  |:|  | /\__\  __/:/\/__/ /:/ |::::\__\ ]],
    [[ \/__|:|/:/  / \:\~\:\ \/__/ \:\  \ /:/  /  |:|  |/:/  / /\/:/  /    \/__/~~/:/  / ]],
    [[     |:/:/  /   \:\ \:\__\    \:\  /:/  /   |:|__/:/  /  \::/__/           /:/  /  ]],
    [[     |::/  /     \:\ \/__/     \:\/:/  /     \::::/__/    \:\__\          /:/  /   ]],
    [[     /:/  /       \:\__\        \::/  /       ~~~~         \/__/         /:/  /    ]],
    [[     \/__/         \/__/         \/__/                                   \/__/     ]],
  },
  {
    effect = flashlight({ ghost = "#8BFF2E", ghost2 = "#B44CFF", beam = "#F2FFE8", dark = "#000000" }), -- ectoplasm green, neon purple
    [[      .-') _   ('-.                     (`-.           _   .-')    ]],
    [[     ( OO ) )_(  OO)                  _(OO  )_        ( '.( OO )_  ]],
    [[ ,--./ ,--,'(,------. .-'),-----. ,--(_/   ,. \ ,-.-') ,--.   ,--.)]],
    [[ |   \ |  |\ |  .---'( OO'  .-.  '\   \   /(__/ |  |OO)|   `.'   | ]],
    [[ |    \|  | )|  |    /   |  | |  | \   \ /   /  |  |  \|         | ]],
    [[ |  .     |/(|  '--. \_) |  |\|  |  \   '   /,  |  |(_/|  |'.'|  | ]],
    [[ |  |\    |  |  .--'   \ |  | |  |   \     /__),|  |_.'|  |   |  | ]],
    [[ |  | \   |  |  `---.   `'  '-'  '    \   /   (_|  |   |  |   |  | ]],
    [[ `--'  `--'  `------'     `-----'      `-'      `--'   `--'   `--' ]],
  },
}

-- where am I: the branch and the worktree folder (re-read on every redraw,
-- so a worktree switch shows up)
local function location()
  local function git(...)
    local r = vim.system({ "git", ... }, { text = true }):wait()
    return r.code == 0 and vim.trim(r.stdout) or nil
  end
  local root = git("rev-parse", "--show-toplevel")
  local dir = { "  " .. vim.fn.fnamemodify(root or vim.fn.getcwd(), ":~"), hl = "SnacksDashboardDir" }
  if not root then
    return { dir }
  end
  local branch = git("branch", "--show-current")
  if branch == "" then -- detached HEAD
    branch = "detached @ " .. git("rev-parse", "--short", "HEAD")
  end
  return { { "  ", hl = "SnacksDashboardIcon" }, { branch, hl = "SnacksDashboardFile" }, { "\n" }, dir }
end

local banner -- picked on open, kept across redraws (resize, worktree switch)
local default_effect = bands({ "purple", "magenta", "yellow" })

-- Every cell of the banner gets its own DashboardCell<row>_<col> group and a timer
-- recolors the groups, so the effect moves without rewriting the buffer
local FRAME_MS = 60
local tick = 0
local timer
local cells = {} -- { group, row, col } of the picked banner
local painted = {} -- group -> colors it was last set to, so unchanged cells are skipped

local function effect()
  return banner.effect or default_effect
end

local function window_bg()
  local bg = effect().bg
  vim.api.nvim_set_hl(0, "SnacksDashboardNormal", bg and { bg = bg } or { link = "Normal" })
end

local function banner_text()
  local pad = effect().pad or 0
  local w = vim.api.nvim_strwidth(banner[1])
  local text = {}
  cells = {}
  for row = 1 - pad, #banner + pad do
    local chars = vim.fn.split(banner[row] or "", [[\zs]])
    for col = 1 - 2 * pad, w + 2 * pad do -- twice as many cols, so the pad is as wide as tall
      local ch = chars[col] or " "
      if ch ~= " " or pad > 0 then -- blanks only need coloring when the effect lights the background
        local group = ("DashboardCell%d_%d"):format(row + pad, col + 2 * pad)
        cells[#cells + 1] = { group, row, col }
        text[#text + 1] = { ch, hl = group }
      else
        text[#text + 1] = { ch }
      end
    end
    if row < #banner + pad then
      text[#text + 1] = { "\n" }
    end
  end
  return text
end

local function paint()
  local at = effect().frame(tick, #banner, vim.api.nvim_strwidth(banner[1]))
  for _, cell in ipairs(cells) do
    local hl = at(cell[2], cell[3])
    local key = (hl.fg or "") .. (hl.bg or "")
    if painted[cell[1]] ~= key then
      painted[cell[1]] = key
      vim.api.nvim_set_hl(0, cell[1], hl)
    end
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    painted = {} -- the scheme cleared the groups
    if banner then
      window_bg()
      paint()
    end
  end,
})

local function sections()
  local new = not banner
  if new then
    -- true random from the OS (math.random is seeded from the clock in seconds,
    -- so opens within the same second would pick the same one)
    banner = banners[vim.uv.random(1):byte() % #banners + 1]
    tick = 0
  end
  local text = banner_text()
  if new then
    window_bg()
    paint()
    timer = timer or vim.uv.new_timer()
    timer:start(FRAME_MS, FRAME_MS, vim.schedule_wrap(function()
      tick = tick + 1
      paint()
      -- a highlight change alone waits for the next keypress to show
      if vim.fn.mode() == "n" then
        vim.cmd.redraw()
      end
    end))
  end
  return {
    { text = text, align = "center", padding = 2 },
    { text = location(), align = "center" },
  }
end

vim.api.nvim_create_autocmd("User", {
  pattern = "SnacksDashboardClosed",
  callback = function()
    banner = nil -- next open picks a new one
    if timer then
      timer:stop()
    end
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

return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      enabled = not from_pick,
      sections = { sections },
    },
  },
}
