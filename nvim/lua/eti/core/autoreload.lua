-- Keep buffers in sync with what Claude writes to disk.
--
-- `:checktime` on its own is not enough: when it is not *typed* (so: from a
-- timer or an autocommand) nvim postpones the check "until a moment the side
-- effects would be harmless", which may never come while you sit in the Claude
-- terminal split. So stat the files here and reload the buffer explicitly.
vim.opt.autoread = true

local group = vim.api.nvim_create_augroup("eti_autoreload", { clear = true })

local seen = {} -- bufnr -> fingerprint of the file on disk
local warned = {} -- bufnr -> true while a conflict is unresolved

local function fingerprint(name)
  local st = vim.uv.fs_stat(name)
  if not st then
    return nil
  end
  return string.format("%d.%d:%d", st.mtime.sec, st.mtime.nsec, st.size)
end

local function watchable(buf)
  return vim.api.nvim_buf_is_loaded(buf)
    and vim.bo[buf].buftype == ""
    and vim.api.nvim_buf_get_name(buf) ~= ""
end

local function reload(buf)
  local views = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    end
  end

  -- no bang: a modified buffer can never be clobbered by this
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("silent! edit")
  end)

  for win, view in pairs(views) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_call(win, function()
        vim.fn.winrestview(view)
      end)
    end
  end

  vim.notify(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":."), vim.log.levels.INFO, {
    title = "Reloaded from disk",
  })
end

local function scan()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if watchable(buf) then
      local current = fingerprint(vim.api.nvim_buf_get_name(buf))
      if current then
        local previous = seen[buf]
        seen[buf] = current
        if previous and previous ~= current then
          if vim.bo[buf].modified then
            -- unsaved edits here, reloading would throw them away: say so once
            if not warned[buf] then
              warned[buf] = true
              vim.notify(
                vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.") .. " changed on disk but has unsaved changes",
                vim.log.levels.WARN,
                { title = "Not reloaded" }
              )
            end
          else
            warned[buf] = nil
            reload(buf)
          end
        end
      end
    end
  end
end

-- remember the on-disk state we already have, so our own writes never
-- look like an outside change
local function refresh(buf)
  if watchable(buf) then
    seen[buf] = fingerprint(vim.api.nvim_buf_get_name(buf))
    warned[buf] = nil
  end
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "BufFilePost" }, {
  group = group,
  callback = function(ev)
    refresh(ev.buf)
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = group,
  callback = function(ev)
    seen[ev.buf] = nil
    warned[ev.buf] = nil
  end,
})

-- check on any move back into the editor, and poll so a buffer you are only
-- looking at updates while Claude works
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "WinEnter", "TermLeave", "TermClose", "CursorHold" }, {
  group = group,
  callback = vim.schedule_wrap(scan),
})

local timer = assert(vim.uv.new_timer())
timer:start(500, 500, vim.schedule_wrap(scan))
