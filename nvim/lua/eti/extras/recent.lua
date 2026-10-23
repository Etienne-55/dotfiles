-- Recent files, in lualine right after the current file's name: the last 3 other files you
-- were in, most recent first (the current file is never in the list). <leader>1-3 opens the
-- 1st-3rd, so <leader>1 is always the file you were just in. Each shows its icon and name at
-- half brightness in its icon's color, like the tmux windows that aren't selected.
-- Set up in plugins/lualine.lua.
local p = require("eti.core.palette")
local devicons = require("nvim-web-devicons")

local M = {}

local SHOWN = 3
local history = {} -- file paths, most recent first

-- half brightness: halfway from the color to the background, like the tmux bar
local function dim(hex)
  local bg = tonumber(p.bg:sub(2), 16)
  local c = tonumber(hex:sub(2), 16)
  local out = 0
  for shift = 16, 0, -8 do
    local a, b = bit.band(bit.rshift(c, shift), 0xff), bit.band(bit.rshift(bg, shift), 0xff)
    out = out + bit.lshift(math.floor((a + b) / 2 + 0.5), shift)
  end
  return string.format("#%06x", out)
end

-- one highlight group per color, created the first time it's used
local groups = {}
local function hl(color)
  local name = "RecentEti" .. color:sub(2)
  if not groups[name] then
    vim.api.nvim_set_hl(0, name, { fg = color })
    groups[name] = true
  end
  return "%#" .. name .. "#"
end

-- statusline text: a % in a file name has to be doubled
local function escape(s)
  return (s:gsub("%%", "%%%%"))
end

local function is_file(buf)
  return vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
end

local function remove(path)
  for i = #history, 1, -1 do
    if history[i] == path then
      table.remove(history, i)
    end
  end
end

-- the files shown: the most recent ones that aren't the current file
local function others()
  local current = vim.api.nvim_buf_get_name(0)
  local list = {}
  for _, path in ipairs(history) do
    if path ~= current then
      list[#list + 1] = path
      if #list == SHOWN then
        break
      end
    end
  end
  return list
end

-- the lualine component
function M.component()
  local parts = {}
  for _, path in ipairs(others()) do
    local name = vim.fn.fnamemodify(path, ":t")
    local icon, color = devicons.get_icon_color(name, vim.fn.fnamemodify(name, ":e"), { default = true })
    parts[#parts + 1] = hl(dim(color)) .. escape(icon .. " " .. name)
  end
  if #parts == 0 then
    return ""
  end
  return hl(p.dark3) .. "│ " .. table.concat(parts, "  ")
end

function M.setup()
  local group = vim.api.nvim_create_augroup("UserRecentFiles", {})
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      if is_file(ev.buf) then
        local path = vim.api.nvim_buf_get_name(ev.buf)
        remove(path)
        table.insert(history, 1, path)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(ev)
      remove(vim.api.nvim_buf_get_name(ev.buf))
    end,
  })
  -- the highlight groups are lost when the colorscheme reloads
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      groups = {}
    end,
  })
  if is_file(0) then
    table.insert(history, 1, vim.api.nvim_buf_get_name(0))
  end

  for i = 1, SHOWN do
    vim.keymap.set("n", "<leader>" .. i, function()
      local path = others()[i]
      if path then
        vim.cmd.edit(vim.fn.fnameescape(path))
      end
    end, { desc = "Go to recent file " .. i })
  end
end

return M
