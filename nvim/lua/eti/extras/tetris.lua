-- Customisations for alec-gibson/nvim-tetris: the original 1984 look
-- (Electronika 60): green phosphor text, "[]" blocks, " ." for empty cells, a
-- "<! !>" well, stats on the left and the key help on the right. Plus chiptune
-- Korobeiniki (mutable with `m`) and a toggle that hides the game and freezes it (game + music)
-- until it's shown again.
local M = {}

local api, uv = vim.api, vim.uv
local buf, win, win_cfg, hiding = nil, nil, nil, false
local lines = 0

-- ---------------------------------------------------------------- music ---

local song = require("eti.extras.tetris_song")
-- job: the afplay process; pending: position to start from once the songs are
-- rendered; paused_at: position to resume from; muted: `m`, for the session (off by default)
local music = { job = nil, pending = nil, paused_at = nil, rendering = false, poll = nil, song = 1, speed = "normal", muted = true }
-- like the NES, the song speeds up while the stack is close to the top
local songs = {
  { id = "korobeiniki", bpm = 150 },
}
local all_tracks = {}
for _, s in ipairs(songs) do
  -- the notes' hash is in the file name, so editing a song re-renders it
  local notes = song.songs[s.id]
  local hash = vim.fn.sha256(notes.melody .. notes.bass):sub(1, 8)
  for speed, bpm in pairs({ normal = s.bpm, fast = math.floor(s.bpm * 4 / 3) }) do
    s[speed] = { id = s.id, bpm = bpm, path = ("%s/tetris-%s-%d-%s.wav"):format(vim.fn.stdpath("cache"), s.id, bpm, hash) }
    all_tracks[#all_tracks + 1] = s[speed]
  end
end

local function current_track()
  return songs[music.song][music.speed]
end

local function rendered()
  for _, track in ipairs(all_tracks) do
    if not uv.fs_stat(track.path) then
      return false
    end
  end
  return true
end

local play

-- drop songs rendered from notes that have since changed (or songs since removed)
local function prune()
  local keep = { [vim.fn.stdpath("cache") .. "/tetris-resume.wav"] = true }
  for _, track in ipairs(all_tracks) do
    keep[track.path] = true
  end
  for _, old in ipairs(vim.fn.glob(vim.fn.stdpath("cache") .. "/tetris-*.wav", false, true)) do
    if not keep[old] then
      os.remove(old)
    end
  end
end

-- synthesising the songs takes a moment, so do it in a separate nvim process
local function render()
  if music.rendering then
    return
  end
  music.rendering = true
  local cmd = { vim.v.progpath, "--clean", "-l", api.nvim_get_runtime_file("lua/eti/extras/tetris_song.lua", false)[1] }
  for _, track in ipairs(all_tracks) do
    if not uv.fs_stat(track.path) then
      vim.list_extend(cmd, { track.path, track.id, tostring(track.bpm) })
    end
  end
  vim.system(cmd, {}, vim.schedule_wrap(function()
    music.rendering = false
    if music.pending and rendered() then
      local from = music.pending
      music.pending = nil
      play(from)
    end
  end))
end

-- afplay can't seek, and freezing it (SIGSTOP) makes CoreAudio replay its last
-- buffer, so pausing kills it and remembers where it was; resuming plays a copy
-- of the song cut at that point, then loops the whole thing again.
function play(from)
  if not rendered() then
    music.pending = from
    return render()
  end
  local track = current_track()
  local path = track.path
  if from > 0 then
    if not track.data then
      local f = assert(io.open(track.path, "rb"))
      track.data = f:read("a"):sub(45) -- skip the 44-byte header
      f:close()
    end
    local skip = 2 * math.floor(from * song.RATE)
    -- in the last moments of the song just start over; a tiny clip would also
    -- trip the "afplay is failing" check below
    if skip < #track.data - 2 * song.RATE * 1.5 then
      path = vim.fn.stdpath("cache") .. "/tetris-resume.wav"
      song.write_wav(path, track.data:sub(skip + 1))
    else
      from = 0
    end
  end
  music.offset, music.started = from, uv.hrtime()
  local job
  job = vim.system({ "afplay", path }, {}, function()
    vim.schedule(function()
      -- ended by itself, not killed: loop from the top (unless afplay is failing)
      if music.job == job then
        music.job = nil
        if (uv.hrtime() - music.started) / 1e9 > 1 then
          play(0)
        end
      end
    end)
  end)
  music.job = job
end

local function kill()
  local job = music.job
  music.job = nil -- before the kill, so its exit callback doesn't loop
  if job then
    pcall(uv.kill, job.pid, "sigterm")
  end
end

function M.music_start()
  if music.job or music.pending or vim.fn.executable("afplay") == 0 then
    return
  end
  music.paused_at, music.speed = nil, "normal"
  prune()
  if music.muted then
    music.paused_at = 0 -- where to start once unmuted
  else
    play(0)
  end
end

function M.music_stop()
  music.paused_at, music.pending = nil, nil
  kill()
end

local function music_pause()
  if music.job then
    music.paused_at = music.offset + (uv.hrtime() - music.started) / 1e9
    kill()
  elseif music.pending then -- still rendering
    music.paused_at, music.pending = music.pending, nil
  end
end

local function music_resume()
  if music.paused_at and not music.muted then
    local from = music.paused_at
    music.paused_at = nil
    play(from)
  end
end

-- switch between normal and fast, keeping the place in the song
local function set_speed(speed)
  if music.speed == speed then
    return
  end
  local playing = music.job or music.pending
  music_pause()
  local scale = current_track().bpm / songs[music.song][speed].bpm
  music.speed = speed
  if music.paused_at then
    music.paused_at = music.paused_at * scale
    if playing then
      music_resume()
    end
  end
end

-- `m`: silence the music, keeping its place, or bring it back
local function toggle_mute()
  if music.muted then
    music.muted = false
    music_resume()
  else
    music_pause()
    music.muted = true
  end
end

-- -------------------------------------------------------------- pausing ---

-- The game's state lives in locals of nvim-tetris.game; its exported
-- functions close over them, so fish them out of their upvalues.
local function game_local(fn_name, name)
  local f = require("nvim-tetris.game")[fn_name]
  for i = 1, math.huge do
    local n, val = debug.getupvalue(f, i)
    if not n then
      return nil
    end
    if n == name then
      return val
    end
  end
end

local function game_timer()
  return game_local("stop_game", "timer")
end

-- highest occupied row (0 = empty board), counted from the bottom
local function stack_height()
  local occupied = game_local("move_left", "occupied_squares") or {}
  for row = #occupied, 1, -1 do
    for _, filled in pairs(occupied[row]) do
      if filled then
        return row
      end
    end
  end
  return 0
end

local function game_running()
  local t = game_timer()
  return t and not t:is_closing() and t or nil
end

local function pause()
  local t = game_running()
  if t then
    t:stop()
  end
  music_pause()
end

local function resume()
  local t = game_running()
  if t then
    t:again()
    music_resume()
  else
    M.music_stop() -- game over while hidden
  end
end

-- ----------------------------------------------------------------- look ---

local ns = api.nvim_create_namespace("eti_tetris")
local board_ns = api.nvim_create_namespace("eti_tetris_board")
local green, dim_green, black = "#33FF33", "#1A7A1A", "#000000"

local function set_highlights()
  local hl = api.nvim_set_hl
  hl(0, "TetrisBoard", { fg = black, bg = black })
  hl(0, "TetrisFrame", { fg = green, bg = black })
  hl(0, "TetrisBlock", { fg = green, bg = black, bold = true })
  hl(0, "TetrisDot", { fg = dim_green, bg = black })
  hl(0, "TetrisCurtain", { fg = dim_green, bg = black })
  hl(0, "TetrisText", { fg = dim_green, bg = black })
  hl(0, "TetrisStat", { fg = green, bg = black, bold = true })
  hl(0, "TetrisCursor", { blend = 100, nocombine = true }) -- blend=100 hides the cursor
end

-- no cursor blinking in the board's top-left corner while you play
local saved_guicursor
local function hide_cursor()
  saved_guicursor = saved_guicursor or vim.o.guicursor
  vim.o.guicursor = saved_guicursor .. ",n-v:TetrisCursor" -- the command line keeps its cursor
end
local function show_cursor()
  if saved_guicursor then
    vim.o.guicursor = saved_guicursor
    saved_guicursor = nil
  end
end

-- The screen around the board. Left: stats and the next piece (the original
-- showed it with key 5); middle: the well, under the board window; right: the
-- key help, laid out like the original's but with this game's keys.
local LEFT, GAP, RIGHT = 20, 2, 26
local help = {
  [1] = "←: НАЛЕВО   →: НАПРАВО",
  [2] = "     ↑: ПОВОРОТ",
  [3] = "↓: УСКОРИТЬ",
  [4] = "  ПРОБЕЛ - СБРОСИТЬ",
  [6] = "Q: ПАУЗА    R: ЗАНОВО",
}
local upcoming -- the piece the game gets next
local frame_buf, frame_win

local function frame_size()
  local const = require("nvim-tetris.const")
  return LEFT + 2 * const.screen_cols + 4 + GAP + RIGHT, const.screen_rows + 3
end

local function pad(text, width)
  return text .. string.rep(" ", width - vim.fn.strdisplaywidth(text))
end

local function draw_frame()
  if not (frame_buf and api.nvim_buf_is_valid(frame_buf)) then
    return
  end
  local const = require("nvim-tetris.const")
  local cols, rows = const.screen_cols, const.screen_rows
  local left = {
    [1] = "ПОЛНЫХ СТРОК: " .. lines,
    [2] = "УРОВЕНЬ: " .. math.floor(lines / const.lines_per_level),
  }
  if upcoming then
    local filled, minx, maxx = {}, math.huge, -math.huge
    for _, o in ipairs(upcoming.square_offsets) do
      filled[o[2] * 10 + o[1]] = true
      minx, maxx = math.min(minx, o[1]), math.max(maxx, o[1])
    end
    left[4] = "СЛЕДУЮЩАЯ:"
    for line = 0, 1 do
      local text = "  "
      for x = minx, maxx do
        text = text .. (filled[(1 - line) * 10 + x] and "[]" or "  ") -- y = 1 is the top row
      end
      left[5 + line] = text
    end
  end
  local right = vim.deepcopy(help)
  right[7] = music.muted and "M: ЗВУК ВЫКЛ" or "M: ЗВУК ВКЛ" -- sound off / on
  local out = {}
  local _, height = frame_size()
  for i = 0, height - 1 do
    local well
    if i == 0 then
      well = string.rep(" ", 2 * cols + 4) -- behind the board's (blank) top line
    elseif i <= rows then
      well = "<!" .. string.rep(" ", 2 * cols) .. "!>"
    elseif i == rows + 1 then
      well = "<!" .. string.rep("=", 2 * cols) .. "!>"
    else
      well = "  " .. string.rep("\\/", cols) .. "  "
    end
    out[#out + 1] = pad(left[i] or "", LEFT) .. well .. string.rep(" ", GAP) .. pad(right[i] or "", RIGHT)
  end
  api.nvim_buf_set_lines(frame_buf, 0, -1, false, out)
end

local function close_frame()
  if frame_win and api.nvim_win_is_valid(frame_win) then
    api.nvim_win_close(frame_win, true)
  end
  frame_win = nil
end

-- open the screen centred in the editor and fit the board into its well
local function open_frame()
  if not (win and api.nvim_win_is_valid(win)) then
    return
  end
  local width, height = frame_size()
  -- a float's row/col is where its border starts; the text is one in from it
  local row = math.max(0, math.floor((vim.o.lines - height - 2) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width - 2) / 2))
  if not (frame_buf and api.nvim_buf_is_valid(frame_buf)) then
    frame_buf = api.nvim_create_buf(false, true)
  end
  local cfg = {
    relative = "editor", row = row, col = col, width = width, height = height,
    style = "minimal", focusable = false, zindex = 40, border = "rounded",
  }
  if frame_win and api.nvim_win_is_valid(frame_win) then
    api.nvim_win_set_config(frame_win, cfg)
  else
    frame_win = api.nvim_open_win(frame_buf, false, cfg)
  end
  vim.wo[frame_win].winhighlight = "NormalFloat:TetrisFrame,FloatBorder:TetrisFrame"
  -- the board sits inside the well, between "<!" and "!>"
  api.nvim_win_set_config(win, { relative = "editor", row = row + 1, col = col + 1 + LEFT + 2, border = "none" })
  draw_frame()
end

local last_piece = {} -- squares of the falling piece, as last drawn by the game

-- The plugin draws coloured blocks; every row is drawn over that as text from
-- the game's state instead.
local function draw_board()
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, board_ns, 0, -1)
  local const = require("nvim-tetris.const")
  local occupied = game_local("move_left", "occupied_squares") or {}
  local piece = {}
  for _, sq in ipairs(last_piece) do
    piece[sq.coords[2] * 100 + sq.coords[1]] = true
  end
  -- the stats live in the frame; blank the plugin's title line
  api.nvim_buf_set_extmark(buf, board_ns, 0, 0, {
    virt_text = { { string.rep(" ", 2 * const.screen_cols), "TetrisBoard" } }, virt_text_pos = "overlay", priority = 9000,
  })
  for l = 1, const.screen_rows do
    local row = const.screen_rows - l + 1
    local chunks = {}
    for col = 1, const.screen_cols do
      local full = (occupied[row] and occupied[row][col]) or piece[row * 100 + col]
      chunks[col] = full and { "[]", "TetrisBlock" } or { " .", "TetrisDot" }
    end
    api.nvim_buf_set_extmark(buf, board_ns, l, 0, { virt_text = chunks, virt_text_pos = "overlay", priority = 9000 })
  end
end

-- closing the window any way other than the toggle ends the game
local function watch_close()
  local b = buf -- not `buf` at callback time: on restart that's already the new game
  api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if not hiding then
        vim.schedule(function()
          if api.nvim_buf_is_valid(b) then
            api.nvim_buf_delete(b, { force = true })
          end
        end)
      end
    end,
  })
end

local best_path = vim.fn.stdpath("state") .. "/tetris-best"

local function read_best()
  local f = io.open(best_path)
  if not f then
    return 0
  end
  local n = tonumber(f:read("a")) or 0
  f:close()
  return n
end

-- game over: the well fills with blocks row by row, then the message
local function game_over(b)
  local best = read_best()
  local new_best = lines > best
  if new_best then
    local f = io.open(best_path, "w")
    if f then
      f:write(tostring(lines))
      f:close()
    end
  end
  local const = require("nvim-tetris.const")
  local rows, width = const.screen_rows, 2 * const.screen_cols
  local function centre(text)
    local w = vim.fn.strdisplaywidth(text)
    local left = math.floor((width - w) / 2)
    return string.rep(" ", left) .. text .. string.rep(" ", width - left - w)
  end
  local row = 0
  local t = assert(uv.new_timer())
  t:start(0, 35, vim.schedule_wrap(function()
    if not api.nvim_buf_is_valid(b) then
      return t:close()
    end
    row = row + 1
    if row <= rows then
      api.nvim_buf_set_extmark(b, ns, row, 0, {
        virt_text = { { string.rep("[]", const.screen_cols), "TetrisCurtain" } }, virt_text_pos = "overlay", priority = 10000,
      })
      return
    end
    t:close()
    local msg = {
      { "" }, { "КОНЕЦ ИГРЫ", true }, { "" },
      { "СТРОК: " .. lines },
      new_best and { "НОВЫЙ РЕКОРД!", true } or { "РЕКОРД: " .. best },
      { "" }, { "R: ЗАНОВО" }, { "" },
    }
    local top = math.floor((rows - #msg) / 2)
    for i, m in ipairs(msg) do
      api.nvim_buf_set_extmark(b, ns, top + i, 0, {
        virt_text = { { centre(m[1]), m[2] and "TetrisStat" or "TetrisText" } },
        virt_text_pos = "overlay", priority = 10001,
      })
    end
  end))
end

-- Throw the current game away and start a new one (init_window ends the old one).
function M.restart()
  vim.cmd("Tetris")
end

function M.setup()
  local tio = require("nvim-tetris.io")

  -- The game calls its io functions through the module table, so wrapping
  -- them is enough to restyle it.
  local init_window = tio.init_window
  tio.init_window = function(...)
    -- a hidden game still owns the "tetris" buffer name, and the plugin names its
    -- new buffer that; end the old game first (its BufWipeout stops its timer)
    if buf and api.nvim_buf_is_valid(buf) then
      api.nvim_buf_delete(buf, { force = true })
    end
    init_window(...)
    buf, win, lines = api.nvim_get_current_buf(), api.nvim_get_current_win(), 0
    vim.bo[buf].bufhidden = "hide" -- survive the toggle; watch_close wipes it otherwise
    set_highlights()
    upcoming, last_piece = nil, {}
    vim.wo[win].winhighlight = "NormalFloat:TetrisBoard"
    watch_close()
    open_frame()
    draw_board()

    api.nvim_create_autocmd("BufWipeout", {
      buffer = buf,
      once = true,
      callback = function()
        M.music_stop()
        close_frame()
        show_cursor()
      end,
    })
    hide_cursor()
    api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, { buffer = buf, callback = hide_cursor })
    api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, { buffer = buf, callback = show_cursor })
    M.music_start()
    -- the game ends itself on game over without telling anyone; poll for it
    local b = buf
    music.poll = music.poll or uv.new_timer()
    music.poll:start(250, 250, vim.schedule_wrap(function()
      if not game_running() then
        M.music_stop()
        music.poll:stop()
        if b == buf and api.nvim_buf_is_valid(b) then
          game_over(b)
        end
        return
      end
      local height = stack_height()
      if height >= 16 then
        set_speed("fast")
      elseif height <= 13 then
        set_speed("normal")
      end
    end))
  end

  local remove_row = tio.remove_row
  tio.remove_row = function(row)
    remove_row(row)
    lines = lines + 1
    draw_frame()
  end

  -- the game asks for a random piece when it needs one; hand it the one shown
  -- as next and pick the following one
  local util = require("nvim-tetris.util")
  local random_piece = util.get_random_piece
  util.get_random_piece = function()
    local piece = upcoming or random_piece()
    upcoming = random_piece()
    draw_frame()
    return piece
  end

  local draw_piece_squares = tio.draw_piece_squares
  tio.draw_piece_squares = function(squares)
    draw_piece_squares(squares)
    last_piece = squares
    draw_board()
  end

  tio.draw_shadow_squares = function() end -- the original has no ghost piece

  -- In the game Space is hard drop and every letter is disabled, so <leader>tt
  -- can't reach us from there; q / Esc hide (and pause) instead.
  local set_game_maps = tio.set_game_maps
  tio.set_game_maps = function(...)
    set_game_maps(...)
    for _, key in ipairs({ "q", "<Esc>" }) do
      vim.keymap.set("n", key, M.toggle, { buffer = buf, nowait = true, desc = "Hide & pause Tetris" })
    end
    vim.keymap.set("n", "r", M.restart, { buffer = buf, nowait = true, desc = "Restart Tetris" })
    vim.keymap.set("n", "m", function()
      toggle_mute()
      draw_frame()
    end, { buffer = buf, nowait = true, desc = "Mute / unmute Tetris music" })
  end

  -- the game prints "Level: n" every frame (60/s), flooding :messages
  local quiet = setmetatable({ print = function() end }, { __index = _G })
  for _, name in ipairs({ "do_frame", "do_game_over" }) do
    local f = require("nvim-tetris.game")["aniseed/locals"][name]
    if f then
      setfenv(f, quiet)
    end
  end

  api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      M.music_stop()
      show_cursor()
    end,
  })
end

-- Hide the game (frozen) / bring it back; starts a new game if there is none.
function M.toggle()
  if not (buf and api.nvim_buf_is_valid(buf)) then
    vim.cmd("Tetris")
    return
  end
  if win and api.nvim_win_is_valid(win) then
    win_cfg = api.nvim_win_get_config(win)
    pause()
    hiding = true
    api.nvim_win_close(win, false)
    hiding = false
    win = nil
    close_frame()
  else
    win = api.nvim_open_win(buf, true, win_cfg)
    vim.wo[win].winhighlight = "NormalFloat:TetrisBoard"
    watch_close()
    open_frame()
    resume()
  end
end

return M
