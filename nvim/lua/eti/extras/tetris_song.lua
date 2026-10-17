-- The game's song, synthesised as an NES-style chiptune WAV (pulse-wave melody,
-- triangle-wave bass). Korobeiniki is a public domain Russian folk song.
-- Rendering takes a moment, so tetris.lua runs this file as its own process:
--   nvim -l tetris_song.lua <path> <song id> <bpm> [<path> <song id> <bpm> ...]
local M = {}

-- bass: one root per bar; `bar(root, up)` spells the bar, `up` being the root an octave higher
local function bass_line(roots, bar)
  local out = {}
  for root in roots:gmatch("%S+") do
    local up = root:gsub("%d", function(d) return tostring(d + 1) end)
    out[#out + 1] = bar(root, up)
  end
  return table.concat(out)
end

-- Korobeiniki, the Tetris Type A theme ("note:beats"): A part twice, then the slow B part
local kor_a = "E5:1 B4:.5 C5:.5 D5:1 C5:.5 B4:.5 A4:1 A4:.5 C5:.5 E5:1 D5:.5 C5:.5 "
  .. "B4:1.5 C5:.5 D5:1 E5:1 C5:1 A4:1 A4:2 "
  .. "D5:1.5 F5:.5 A5:1 G5:.5 F5:.5 E5:1.5 C5:.5 E5:1 D5:.5 C5:.5 "
  .. "B4:1 B4:.5 C5:.5 D5:1 E5:1 C5:1 A4:1 A4:1 R:1 "
local kor_b = "E5:2 C5:2 D5:2 B4:2 C5:2 A4:2 G#4:2 B4:2 E5:2 C5:2 D5:2 B4:2 C5:1 E5:1 A5:2 G#5:4 "

M.songs = {
  korobeiniki = {
    melody = kor_a .. kor_a .. kor_b,
    bass = bass_line("E2 A2 E2 A2 D2 C2 E2 A2 E2 A2 E2 A2 D2 C2 E2 A2 A2 G#2 A2 E2 A2 G#2 A2 E2",
      function(root, up) return string.rep(root .. ":.5 " .. up .. ":.5 ", 4) end),
  },
}

local semitone = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
local function freq(name)
  local l, sharp, oct = name:match("^(%a)(#?)(%d)$")
  if not l then
    return 0 -- rest
  end
  local midi = 12 * (oct + 1) + semitone[l] + (sharp == "#" and 1 or 0)
  return 440 * 2 ^ ((midi - 69) / 12)
end

-- Render one voice into `out` (summed in). wave(phase) -> -1..1
local function render(out, score, rate, beat, wave, amp)
  local i = 1
  for name, beats in score:gmatch("(%S+):([%d.]+)") do
    local n = math.floor(beats * beat * rate)
    local f, phase = freq(name), 0
    local on = math.floor(n * 0.9) -- short gap so repeated notes articulate
    for k = 0, n - 1 do
      local v = 0
      if f > 0 and k < on then
        local env = (1 - 0.35 * k / on) * math.min(1, k / 40, (on - k) / 40)
        v = wave(phase) * amp * env
        phase = (phase + f / rate) % 1
      end
      out[i] = (out[i] or 0) + v
      i = i + 1
    end
  end
end

local RATE = 22050
M.RATE = RATE

local function le(n, size)
  local t = {}
  for i = 1, size do
    t[i] = string.char(n % 256)
    n = math.floor(n / 256)
  end
  return table.concat(t)
end

function M.write_wav(path, data) -- data: 16-bit mono PCM
  local header = "RIFF" .. le(36 + #data, 4) .. "WAVE" .. "fmt " .. le(16, 4) .. le(1, 2) .. le(1, 2)
    .. le(RATE, 4) .. le(RATE * 2, 4) .. le(2, 2) .. le(16, 2) .. "data" .. le(#data, 4)
  local f = assert(io.open(path, "wb"))
  f:write(header, data)
  f:close()
end

function M.render_song(path, id, bpm)
  local song = M.songs[id]
  local beat = 60 / bpm
  local samples = {}
  render(samples, song.melody, RATE, beat, function(p) return p < 0.25 and 1 or -1 end, 0.16) -- NES pulse, 25% duty
  render(samples, song.bass, RATE, beat, function(p) return 4 * math.abs(p - 0.5) - 1 end, 0.3) -- NES triangle
  local bytes = {}
  for i, v in ipairs(samples) do
    local s = math.floor(math.max(-1, math.min(1, v)) * 32767) % 65536
    bytes[i] = string.char(s % 256, math.floor(s / 256))
  end
  -- via a temp file, so a half-written song is never mistaken for a finished one
  M.write_wav(path .. ".tmp", table.concat(bytes))
  assert(os.rename(path .. ".tmp", path))
end

if _G.arg and _G.arg[0] and _G.arg[0]:match("tetris_song%.lua$") then
  for i = 1, #_G.arg, 3 do
    M.render_song(_G.arg[i], _G.arg[i + 1], tonumber(_G.arg[i + 2]))
  end
end

return M
