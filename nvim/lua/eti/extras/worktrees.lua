-- Git worktree picker: <leader>gw, and `gw` in the shell through `:Pick worktrees`
-- (both registered in plugins/telescope.lua).
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.sorters")

local M = {}

-- opened from the shell: <Esc> quits nvim too, like the other :Pick pickers
local function quit_on_escape(prompt_bufnr, map)
  map({ "i", "n" }, "<Esc>", function()
    actions.close(prompt_bufnr)
    vim.cmd("qall")
  end)
end

-- git worktrees; <cr> moves nvim into the picked one: cwd (same subfolder if
-- it exists there), current file (same path, else oil at the root; the dashboard
-- stays), file tree.
-- Unmodified buffers of the worktree being left are closed; modified ones stay.
-- <cr> on a typed branch name with a "/" (feature/swtrk-1590) or one matching
-- nothing makes a worktree for it (no fetch: origin as last fetched by hand),
-- copying node_modules/.env* into it;
-- <Space>dd (any mode; branch names have no spaces) deletes the selected one and
-- its branch after one confirm, uncommitted changes included.
-- Both show a spinner in the list's title while git works.
function M.pick(from_shell)
  local root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
  if vim.v.shell_error ~= 0 then
    vim.notify("Not in a git repo", vim.log.levels.WARN)
    -- from the shell, :Pick has already blanked the window: nothing left to show
    if from_shell then
      vim.cmd("qall")
    end
    return
  end
  -- forget worktrees whose folder was deleted by hand, so their branch and
  -- folder name can be used again (git's bookkeeping only, no branch touched)
  vim.fn.system({ "git", "worktree", "prune" })
  local list = {}
  for _, line in ipairs(vim.fn.systemlist({ "git", "worktree", "list", "--porcelain" })) do
    local key, value = line:match("^(%S+) ?(.*)$")
    if key == "worktree" then
      list[#list + 1] = { path = value, branch = "(detached)" }
    elseif key == "branch" then
      list[#list].branch = (value:gsub("^refs/heads/", ""))
    elseif key == "bare" or key == "prunable" then
      list[#list] = nil -- no files to switch to (prunable: its folder is gone)
    end
  end

  -- the worktree a file belongs to: the deepest one containing it (they can nest)
  local function owner(file)
    local best
    for _, wt in ipairs(list) do
      if vim.startswith(file, wt.path .. "/") and (not best or #wt.path > #best) then
        best = wt.path
      end
    end
    return best
  end

  -- whether the current window can show a file or oil: not the tree, a terminal,
  -- help, a float (oil's), or a window locked to its buffer (gitsigns blame)
  local function hosts_files()
    if vim.bo.filetype == "snacks_dashboard" then
      return true
    end
    if vim.bo.filetype == "NvimTree" or vim.wo.winfixbuf or vim.api.nvim_win_get_config(0).relative ~= "" then
      return false
    end
    return vim.bo.buftype == "" or vim.bo.buftype == "acwrite" -- acwrite: oil
  end

  local function switch(path)
    if not hosts_files() then
      vim.cmd.wincmd("p")
    end
    if not hosts_files() then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        vim.api.nvim_set_current_win(win)
        if hosts_files() then
          break
        end
      end
    end
    local rel_cwd = (vim.uv.fs_realpath(vim.fn.getcwd()) or ""):sub(#root + 2)
    local cwd = path .. "/" .. rel_cwd
    if rel_cwd == "" or vim.fn.isdirectory(cwd) == 0 then
      cwd = path
    end
    vim.cmd.cd(vim.fn.fnameescape(cwd))

    local file = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0))
    local target = file and owner(file) == root and path .. file:sub(#root + 1)
    -- pcall: a failed :edit must not skip the cleanup below (cwd already moved)
    local ok, err = pcall(function()
      if target and vim.fn.filereadable(target) == 1 then
        vim.cmd.edit(vim.fn.fnameescape(target))
      elseif vim.bo.filetype == "snacks_dashboard" then
        Snacks.dashboard.update() -- stays; its recent files follow the new cwd
      elseif from_shell then
        -- `gw` from the shell lands on the dashboard, in this window (not a float),
        -- so :Pick's blank window options on it are restored
        Snacks.dashboard.open({ win = vim.api.nvim_get_current_win() })
      else
        vim.cmd.edit(vim.fn.fnameescape(cwd))
      end
    end)
    if not ok then
      vim.notify(tostring(err), vim.log.levels.WARN, { title = "Worktree" })
    end

    local kept = 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(buf)
      if vim.bo[buf].buflisted and name ~= "" and owner(vim.uv.fs_realpath(name) or name) == root then
        if vim.bo[buf].modified then
          kept = kept + 1
        else
          Snacks.bufdelete({ buf = buf })
        end
      end
    end

    -- nvim-tree follows the :cd itself (sync_root_with_cwd)
    local msg = "cwd → " .. vim.fn.fnamemodify(cwd, ":~")
    if kept > 0 then
      msg = msg .. "\n" .. kept .. " modified buffer(s) of the old worktree kept open"
    end
    vim.notify(msg, vim.log.levels.INFO, { title = "Worktree" })

    -- the zsh `nvim` wrapper follows into the worktree on exit
    if vim.env.NVIM_CWD_FILE then
      vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("eti_worktree_cwd", { clear = true }),
        callback = function()
          vim.fn.writefile({ vim.fn.getcwd(-1, -1) }, vim.env.NVIM_CWD_FILE) -- global cwd, not a window's
        end,
      })
    end
  end

  -- runs git; a failure shows its error
  local function git(args)
    local res = vim.system(vim.list_extend({ "git" }, args), { text = true }):wait()
    if res.code ~= 0 then
      vim.notify(vim.trim(res.stderr), vim.log.levels.ERROR, { title = "Worktree" })
    end
    return res.code == 0
  end

  -- same, in the background (checkouts and removals take seconds): the picker
  -- keeps drawing, then next(ok)
  local function git_async(args, next)
    vim.system(vim.list_extend({ "git" }, args), { text = true }, vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        vim.notify(vim.trim(res.stderr), vim.log.levels.ERROR, { title = "Worktree" })
      end
      next(res.code == 0)
    end))
  end

  -- the gitignored things a fresh worktree needs to run: node_modules folders and
  -- .env* files, cloned from the current worktree. APFS clone: 1.4G of
  -- node_modules in ~2s, no extra disk, in a libuv thread so the spinner keeps
  -- going. They may lag the new branch's lockfile. Then done().
  local function copy_ignored(dir, done)
    local res = vim.system({ "git", "-C", root, "ls-files", "--others", "--ignored", "--exclude-standard", "--directory" }, { text = true })
      :wait()
    local rels = {}
    for _, entry in ipairs(vim.split(res.stdout or "", "\n", { trimempty = true })) do
      local rel = (entry:gsub("/$", ""))
      local name = vim.fs.basename(rel)
      local dst = dir .. "/" .. rel
      if (name == "node_modules" or name:match("^%.env")) and not vim.uv.fs_lstat(dst) and vim.uv.fs_stat(vim.fs.dirname(dst)) then
        rels[#rels + 1] = rel
      end
    end
    if #rels == 0 then
      return done()
    end
    -- the thread has its own Lua state: no `vim`, upvalues or tables, only strings in and out
    vim.uv.new_work(function(src_root, dst_root, list_str)
      local ffi = require("ffi")
      pcall(ffi.cdef, "int clonefile(const char *src, const char *dst, uint32_t flags);")
      local failed = {}
      for rel in list_str:gmatch("[^\n]+") do
        local ok, code = pcall(function()
          return ffi.C.clonefile(src_root .. "/" .. rel, dst_root .. "/" .. rel, 1) -- 1: CLONE_NOFOLLOW
        end)
        if not (ok and code == 0) then
          failed[#failed + 1] = rel
        end
      end
      return table.concat(failed, "\n")
    end, vim.schedule_wrap(function(failed_str)
      local failed = vim.split(failed_str, "\n", { trimempty = true })
      local copied = vim.tbl_filter(function(rel)
        return not vim.tbl_contains(failed, rel)
      end, rels)
      if #copied > 0 then
        vim.notify("Copied " .. table.concat(copied, ", "), vim.log.levels.INFO, { title = "Worktree" })
      end
      if #failed > 0 then
        vim.notify("Not copied: " .. table.concat(failed, ", "), vim.log.levels.WARN, { title = "Worktree" })
      end
      done()
    end)):queue(root, dir, table.concat(rels, "\n"))
  end

  -- worktree on <branch> next to the main one, named after the branch's trailing
  -- number: feature/swtrk-1590 -> swc-tracking-1590. When that folder is taken
  -- (hotfix/swtrk-1590 too), its last part, then the whole branch name.
  -- A local branch is reused as it is. Otherwise origin's branch (as last fetched,
  -- no network here) if it has one, else a new one from the branch the current
  -- worktree is on (its local state).
  -- done(dir) gets the new worktree's folder, nil when it failed.
  local function create(branch, done)
    if not git({ "check-ref-format", "--branch", branch }) then
      return done()
    end

    local function add(on_origin)
      local main = list[1].path
      local prefix = vim.fs.dirname(main) .. "/" .. vim.fs.basename(main) .. "-"
      local names = { branch:match("(%d+)$") or false, branch:match("[^/]+$"), (branch:gsub("/", "-")) }
      local dir = prefix .. names[#names] -- all taken: git says so
      for _, name in ipairs(names) do
        if name and not vim.uv.fs_stat(prefix .. name) then
          dir = prefix .. name
          break
        end
      end

      -- HEAD here is the current worktree's, since git runs in nvim's cwd
      -- --no-track: the new branch must not pull from / push to its base
      local args = on_origin and { "worktree", "add", dir, branch } or { "worktree", "add", "--no-track", "-b", branch, dir, "HEAD" }
      git_async(args, function(ok)
        if not ok then
          return done()
        end
        copy_ignored(dir, function()
          done(dir)
        end)
      end)
    end

    local function has(ref)
      return vim.system({ "git", "show-ref", "--quiet", ref }):wait().code == 0
    end
    add(has("refs/heads/" .. branch) or has("refs/remotes/origin/" .. branch))
  end

  -- force-removes the worktree (uncommitted changes go with it) and deletes its
  -- local branch, like lazygit. Never touches origin: no push, no merge, no
  -- remote delete (that would close the MR).
  -- done() runs once it's over, either way.
  local function remove(wt, done)
    git_async({ "worktree", "remove", "--force", wt.path }, function(ok)
      if not ok then
        return done()
      end
      local msg = "Removed " .. vim.fn.fnamemodify(wt.path, ":~")
      if wt.branch == "(detached)" then
        vim.notify(msg, vim.log.levels.INFO, { title = "Worktree" })
        return done()
      end
      git_async({ "branch", "-D", wt.branch }, function(deleted)
        if deleted then
          msg = msg .. "\nBranch " .. wt.branch .. " deleted"
        end
        vim.notify(msg, vim.log.levels.INFO, { title = "Worktree" })
        done()
      end)
    end)
  end

  -- the picked worktree; already in it: from the shell, the dashboard
  local function go(path)
    if path ~= root then
      switch(path)
    elseif from_shell then
      Snacks.dashboard.open({ win = vim.api.nvim_get_current_win() })
    end
  end

  local width = 0
  for _, wt in ipairs(list) do
    width = math.max(width, #wt.branch)
  end
  pickers
    .new({}, {
      prompt_title = "Worktrees  <cr> go/create · <Space>dd delete",
      finder = finders.new_table({
        results = list,
        entry_maker = function(wt)
          local mark = wt.path == root and "* " or "  "
          local path = vim.fn.fnamemodify(wt.path, ":~")
          return {
            value = wt.path,
            wt = wt,
            display = mark .. wt.branch .. string.rep(" ", width - #wt.branch + 2) .. path,
            ordinal = wt.branch .. " " .. path,
          }
        end,
      }),
      -- plain substring match, not fuzzy: a new branch name matches nothing, so
      -- <cr> creates it instead of jumping to some fuzzy hit
      sorter = sorters.get_substr_matcher(),
      -- status of the worktree, then its latest commits
      previewer = previewers.new_termopen_previewer({
        get_command = function(entry)
          return {
            "sh", "-c",
            'git -C "$1" -c color.status=always status -sb && echo && git -C "$1" log --oneline --color=always -20',
            "sh", entry.value,
          }
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        -- while git creates or deletes, the list stays up with a spinner in its
        -- title, and <cr>/<Space>dd do nothing. Returns the function ending it.
        local busy = false
        local function spin(text)
          busy = true
          local picker = action_state.get_current_picker(prompt_bufnr)
          local frames, i = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }, 0
          local timer = vim.uv.new_timer()
          timer:start(0, 80, vim.schedule_wrap(function()
            if timer:is_closing() then
              return -- a tick scheduled just before the stop
            end
            i = i % #frames + 1
            pcall(function()
              picker.prompt_border:change_title(frames[i] .. " " .. text .. "…")
            end)
          end))
          return function()
            busy = false
            timer:stop()
            timer:close()
            pcall(function()
              picker.prompt_border:change_title(picker.prompt_title)
            end)
          end
        end
        local function close()
          if vim.api.nvim_buf_is_valid(prompt_bufnr) then
            actions.close(prompt_bufnr)
          end
        end

        -- the worktree on exactly the typed branch; else a typed full branch name
        -- ("/" in it) is created even when it matches others (feature/swtrk-159
        -- vs feature/swtrk-1590), while a search ("1590") goes to the selection;
        -- nothing matching: created, then entered. A failed create (bad name,
        -- folder taken, branch open elsewhere) leaves the list up, name typed.
        actions.select_default:replace(function()
          if busy then
            return
          end
          local typed = vim.trim(action_state.get_current_line())
          local entry = action_state.get_selected_entry()
          for _, wt in ipairs(list) do
            if wt.branch == typed then
              close()
              return go(wt.path)
            end
          end
          if entry and not typed:find("/", 1, true) then
            close()
            go(entry.value)
          elseif typed ~= "" then
            local stop = spin("Creating " .. typed)
            create(typed, function(dir)
              stop()
              if dir then
                close()
                switch(dir)
              end
            end)
          end
        end)
        -- <Space>dd: remove the selected worktree and its branch (<cr> confirms),
        -- then reopen the list. The confirm names what is lost, if anything.
        map({ "i", "n" }, "<Space>dd", function()
          local entry = action_state.get_selected_entry()
          if not entry or busy then
            return
          end
          local wt = entry.wt
          if wt.path == list[1].path or wt.path == root then
            return vim.notify("Can't remove the main worktree or the current one", vim.log.levels.WARN, { title = "Worktree" })
          end
          local lost = {}
          local status = vim.system({ "git", "-C", wt.path, "status", "--porcelain" }, { text = true }):wait()
          if vim.trim(status.stdout or "") ~= "" then
            lost[#lost + 1] = "uncommitted changes"
          end
          if wt.branch ~= "(detached)" then
            local res = vim.system({ "git", "rev-list", "--count", "refs/heads/" .. wt.branch, "--not", "--remotes", "--" }, { text = true }):wait()
            local count = tonumber(vim.trim(res.stdout or "")) or 0
            if count > 0 then
              lost[#lost + 1] = count .. " commit(s) on no remote (unpushed or squash-merged)"
            end
          end
          local question = "Delete worktree + branch " .. wt.branch .. "?"
          if #lost > 0 then
            question = question .. "\nLost: " .. table.concat(lost, ", ")
          end
          if vim.fn.confirm(question, "&Yes\n&No", 1) ~= 1 then
            return
          end
          local stop = spin("Deleting " .. wt.branch)
          remove(wt, function()
            stop()
            close()
            M.pick(from_shell)
          end)
        end)
        if from_shell then
          quit_on_escape(prompt_bufnr, map)
        end
        return true
      end,
    })
    :find()
end

return M
