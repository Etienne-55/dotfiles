-- Start screen: a random banner over the branch and worktree. Merged into the snacks.nvim spec by lazy.

-- the shell aliases (`nvim "+Pick find_files"`) go straight to a picker, and
-- `git diff dev` straight to diffview; the dashboard would only show through behind it
local from_pick = vim.iter(vim.v.argv):any(function(a)
  return vim.startswith(a, "+Pick") or vim.startswith(a, "+DiffviewOpen")
end)

-- one is picked at random on each open
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
  -- {
  --   [[    ▄   ▄███▄   ████▄     ▄   ▄█ █▀▄▀█ ]],
  --   [[     █  █▀   ▀  █   █      █  ██ █ █ █ ]],
  --   [[ ██   █ ██▄▄    █   █ █     █ ██ █ ▄ █ ]],
  --   [[ █ █  █ █▄   ▄▀ ▀████  █    █ ▐█ █   █ ]],
  --   [[ █  █ █ ▀███▀           █  █   ▐    █  ]],
  --   [[ █   ██                  █▐        ▀   ]],
  --   [[                         ▐             ]],
  -- },
  -- {
  --   [[  ▐ ▄ ▄▄▄ .       ▌ ▐·▪  • ▌ ▄ ·.  ]],
  --   [[ •█▌▐█▀▄.▀·▪     ▪█·█▌██ ·██ ▐███▪ ]],
  --   [[ ▐█▐▐▌▐▀▀▪▄ ▄█▀▄ ▐█▐█•▐█·▐█ ▌▐▌▐█· ]],
  --   [[ ██▐█▌▐█▄▄▌▐█▌.▐▌ ███ ▐█▌██ ██▌▐█▌ ]],
  --   [[ ▀▀ █▪ ▀▀▀  ▀█▄▀▪. ▀  ▀▀▀▀▀  █▪▀▀▀ ]],
  -- },
  -- {
  --   [[     /\__\        /\  \         /\  \         /\__\          ___        /\__\     ]],
  --   [[    /::|  |       /::\  \       /::\  \       /:/  /         /\  \      /::|  |    ]],
  --   [[   /:|:|  |      /:/\:\  \     /:/\:\  \     /:/  /          \:\  \    /:|:|  |    ]],
  --   [[  /:/|:|  |__   /::\~\:\  \   /:/  \:\  \   /:/__/  ___      /::\__\  /:/|:|__|__  ]],
  --   [[ /:/ |:| /\__\ /:/\:\ \:\__\ /:/__/ \:\__\  |:|  | /\__\  __/:/\/__/ /:/ |::::\__\ ]],
  --   [[ \/__|:|/:/  / \:\~\:\ \/__/ \:\  \ /:/  /  |:|  |/:/  / /\/:/  /    \/__/~~/:/  / ]],
  --   [[     |:/:/  /   \:\ \:\__\    \:\  /:/  /   |:|__/:/  /  \::/__/           /:/  /  ]],
  --   [[     |::/  /     \:\ \/__/     \:\/:/  /     \::::/__/    \:\__\          /:/  /   ]],
  --   [[     /:/  /       \:\__\        \::/  /       ~~~~         \/__/         /:/  /    ]],
  --   [[     \/__/         \/__/         \/__/                                   \/__/     ]],
  -- },
  {
    colors = { "#8BFF2E", "#F2FFE8", "#8BFF2E", "#1A2612" }, -- ectoplasm green, with white and black bands
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
  -- {
  --   colors = { "cyan", "orange" },
  --   [[  _______                    .__          ]],
  --   [[  \      \   ____  _______  _|__| _____   ]],
  --   [[  /   |   \_/ __ \/  _ \  \/ /  |/     \  ]],
  --   [[ /    |    \  ___(  <_> )   /|  |  Y Y  \ ]],
  --   [[ \____|__  /\___  >____/ \_/ |__|__|_|  / ]],
  --   [[         \/     \/                    \/  ]],
  -- },
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

-- Neon rainbow: each column of the banner gets one of the DashboardRainbow<n> groups
-- and a timer rotates their colors, so the rainbow moves without rewriting the buffer.
-- A banner can set its own `colors` (palette names or hex); RAINBOW is the default
local RAINBOW = { "purple", "magenta", "yellow" }
local STEPS = 8 -- shades blended between two colors, so the gradient is smooth
local RAINBOW_MS = 60
local shades = {} -- of the picked banner

local function blend(colors)
  local p = require("eti.core.palette")
  local function mix(a, b, i, t) -- channel i (2, 4 or 6) of hex colors a and b, t of the way to b
    local x, y = tonumber(a:sub(i, i + 1), 16), tonumber(b:sub(i, i + 1), 16)
    return math.floor(x + (y - x) * t + 0.5)
  end
  local out = {}
  for i, name in ipairs(colors) do
    local a, b = p[name] or name, p[colors[i % #colors + 1]] or colors[i % #colors + 1]
    for s = 0, STEPS - 1 do
      local t = s / STEPS
      out[#out + 1] = ("#%02x%02x%02x"):format(mix(a, b, 2, t), mix(a, b, 4, t), mix(a, b, 6, t))
    end
  end
  return out
end
local offset = 0 -- how far the rainbow has moved
local timer

local function rainbow_hl()
  for i = 1, #shades do
    vim.api.nvim_set_hl(0, "DashboardRainbow" .. i, { fg = shades[(i + offset - 1) % #shades + 1] })
  end
end

-- one chunk per character; the diagonal (col - row) makes the bands slant
local function rainbow_text(lines)
  local text = {}
  for row, line in ipairs(lines) do
    for col, ch in ipairs(vim.fn.split(line, [[\zs]])) do
      text[#text + 1] = { ch, hl = ch ~= " " and "DashboardRainbow" .. ((col - row) % #shades + 1) or nil }
    end
    if row < #lines then
      text[#text + 1] = { "\n" }
    end
  end
  return text
end

vim.api.nvim_create_autocmd("ColorScheme", { callback = rainbow_hl })

local function sections()
  if not banner then
    -- true random from the OS (math.random is seeded from the clock in seconds,
    -- so opens within the same second would pick the same one)
    banner = banners[vim.uv.random(1):byte() % #banners + 1]
    shades = blend(banner.colors or RAINBOW)
    rainbow_hl()
    timer = timer or vim.uv.new_timer()
    timer:start(RAINBOW_MS, RAINBOW_MS, vim.schedule_wrap(function()
      offset = offset + 1
      rainbow_hl()
      -- a highlight change alone waits for the next keypress to show
      if vim.fn.mode() == "n" then
        vim.cmd.redraw()
      end
    end))
  end
  return {
    { text = rainbow_text(banner), align = "center", padding = 2 },
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
