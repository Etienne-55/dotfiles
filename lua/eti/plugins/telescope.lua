return {
  "nvim-telescope/telescope.nvim",
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-tree/nvim-web-devicons",
    "folke/todo-comments.nvim",
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local builtin = require("telescope.builtin")
    local finders = require("telescope.finders")
    local pickers = require("telescope.pickers")
    local previewers = require("telescope.previewers")
    local conf = require("telescope.config").values
    local transform_mod = require("telescope.actions.mt").transform_mod

    local trouble = require("trouble")
    local trouble_telescope = require("trouble.sources.telescope")

    local custom_actions = transform_mod({
      open_trouble_qflist = function(prompt_bufnr)
        trouble.toggle("quickfix")
      end,
    })

    telescope.setup({
      defaults = {
        path_display = { "smart" },
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous, -- move to prev result
            ["<C-j>"] = actions.move_selection_next, -- move to next result
            ["<C-q>"] = actions.send_selected_to_qflist + custom_actions.open_trouble_qflist,
            ["<C-t>"] = trouble_telescope.open,
          },
        },
      },
    })

    telescope.load_extension("fzf")

    -- when nvim was launched from the shell only to host a picker, <Esc> should
    -- quit back to the terminal; inside a session it just closes the picker
    local function quit_on_escape(prompt_bufnr, map)
      map({ "i", "n" }, "<Esc>", function()
        actions.close(prompt_bufnr)
        vim.cmd("qall")
      end)
      return true
    end

    local function picker_opts(opts, from_shell)
      if from_shell then
        opts.attach_mappings = quit_on_escape
      end
      return opts
    end

    -- pick a directory, then find files in it (<cr>) or grep in it (<C-g>)
    local function find_directory(from_shell)
      pickers
        .new({}, {
          prompt_title = "Directories",
          finder = finders.new_oneshot_job(
            { "fd", "--type", "d", "--hidden", "--exclude", ".git" },
            { entry_maker = function(line)
              return { value = line, display = line, ordinal = line }
            end }
          ),
          sorter = conf.generic_sorter({}),
          previewer = previewers.new_termopen_previewer({
            get_command = function(entry)
              return { "eza", "--all", "--long", "--git", "--icons=always", "--color=always", entry.value }
            end,
          }),
          attach_mappings = function(prompt_bufnr, map)
            local function pick(fn)
              return function()
                local dir = action_state.get_selected_entry().value
                actions.close(prompt_bufnr)
                fn(dir)
              end
            end
            actions.select_default:replace(pick(function(dir)
              builtin.find_files(picker_opts({ cwd = dir, prompt_title = "Files in " .. dir }, from_shell))
            end))
            map({ "i", "n" }, "<C-g>", pick(function(dir)
              builtin.live_grep(
                picker_opts({ search_dirs = { dir }, prompt_title = "Grep in " .. dir }, from_shell)
              )
            end))
            if from_shell then
              quit_on_escape(prompt_bufnr, map)
            end
            return true
          end,
        })
        :find()
    end

    -- files a commit touched, opened in their current (working tree) state;
    -- files deleted or renamed since then are skipped. A merge lists what it
    -- brought in (diff against its first parent).
    local function commit_files(sha, back)
      local root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
      local files = vim.tbl_filter(function(file)
        return vim.fn.filereadable(root .. "/" .. file) == 1
      end, vim.fn.systemlist({
        "git", "-c", "core.quotepath=off", "show", "--diff-merges=first-parent", "--name-only", "--format=", sha,
      }))
      if #files == 0 then
        vim.notify("None of the files in " .. sha .. " exist anymore", vim.log.levels.WARN)
        return back()
      end
      pickers
        .new({}, {
          prompt_title = "Files of " .. sha,
          finder = finders.new_table({
            results = files,
            entry_maker = require("telescope.make_entry").gen_from_file({ cwd = root }),
          }),
          sorter = conf.file_sorter({}),
          previewer = conf.file_previewer({}),
          -- <Esc> goes back to the commit list
          attach_mappings = function(prompt_bufnr, map)
            map({ "i", "n" }, "<Esc>", function()
              actions.close(prompt_bufnr)
              back()
            end)
            return true
          end,
        })
        :find()
    end

    -- browse commits (diff preview); <cr> lists the commit's files instead of checking it out
    local function commits(opts, from_shell)
      opts.attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          -- reopened with the same search and selection when coming back from the files
          local reopen = vim.tbl_extend("force", opts, {
            default_text = picker:_get_prompt(),
            default_selection_index = picker:get_index(picker:get_selection_row()),
          })
          local sha = action_state.get_selected_entry().value
          actions.close(prompt_bufnr)
          commit_files(sha, function()
            commits(reopen, from_shell)
          end)
        end)
        if from_shell then
          quit_on_escape(prompt_bufnr, map)
        end
        return true
      end
      builtin.git_commits(opts)
    end

    local function my_commits(from_shell)
      local me = vim.fn.systemlist({ "git", "config", "user.email" })[1]
      commits({
        prompt_title = "My commits",
        git_command = { "git", "log", "--pretty=oneline", "--abbrev-commit", "--author=" .. me, "--", "." },
      }, from_shell)
    end

    -- files of my latest commit (merges included); <Esc> goes to my commit list
    local function my_last_commit(from_shell)
      local me = vim.fn.systemlist({ "git", "config", "user.email" })[1]
      local sha = vim.fn.systemlist({ "git", "log", "-1", "--format=%h", "--author=" .. me, "--", "." })[1]
      if not sha or sha == "" then
        vim.notify("No commit of yours here", vim.log.levels.WARN)
        return my_commits(from_shell)
      end
      commit_files(sha, function()
        my_commits(from_shell)
      end)
    end

    -- pickers `:Pick` can open, besides the builtins
    local own_pickers = {
      directory = find_directory,
      worktrees = require("eti.extras.worktrees").pick,
      commits = function(from_shell)
        commits({}, from_shell)
      end,
      my_commits = my_commits,
      my_last_commit = my_last_commit,
    }

    vim.api.nvim_create_user_command("FindDirectory", function()
      find_directory()
    end, { desc = "Pick a directory" })

    -- entry point for the shell aliases: `nvim "+Pick find_files"`
    vim.api.nvim_create_user_command("Pick", function(o)
      -- launched from the shell on the empty startup buffer: nothing behind the
      -- picker but the terminal's own background, until a file is opened in that window
      local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_get_name(buf) == "" and not vim.bo[buf].modified then
        local blank = {
          fillchars = "eob: ", -- no ~ lines
          number = false,
          relativenumber = false,
          cursorline = false,
          signcolumn = "no",
          foldcolumn = "0",
          statuscolumn = "",
        }
        local saved = {}
        for opt, value in pairs(blank) do
          saved[opt] = vim.wo[win][opt]
          vim.wo[win][opt] = value
        end
        local laststatus = vim.o.laststatus
        vim.o.laststatus = 0
        -- `:edit` reuses the empty startup buffer (same number), so it gaining a
        -- name counts as a file being opened too
        vim.api.nvim_create_autocmd("BufWinEnter", {
          callback = function()
            local shown = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win)
            if shown and (shown ~= buf or vim.api.nvim_buf_get_name(buf) ~= "") then
              for opt, value in pairs(saved) do
                vim.wo[win][opt] = value
              end
              vim.o.laststatus = laststatus
              return true
            end
          end,
        })
      end
      if own_pickers[o.args] then
        return own_pickers[o.args](true)
      end
      if type(builtin[o.args]) ~= "function" then
        return vim.notify("Pick: no such picker: " .. o.args, vim.log.levels.ERROR)
      end
      builtin[o.args](picker_opts({}, true))
    end, {
      nargs = 1,
      desc = "Open a picker whose <Esc> quits nvim",
      complete = function(lead)
        local names = vim.tbl_keys(own_pickers)
        for name, fn in pairs(builtin) do
          if type(fn) == "function" then
            names[#names + 1] = name
          end
        end
        return vim.tbl_filter(function(name)
          return vim.startswith(name, lead)
        end, names)
      end,
    })

    local keymap = vim.keymap

    keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
    keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
    keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
    keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
    keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })
    keymap.set("n", "<leader>fd", find_directory, { desc = "Find directory, then files (<cr>) / grep (<C-g>)" })

    -- git (previews show the diff)
    keymap.set("n", "<leader>gd", "<cmd>Telescope git_status<cr>", { desc = "Changed files with diff preview" })
    keymap.set("n", "<leader>gc", function()
      commits({})
    end, { desc = "Browse commits, <cr> lists their files" })
    keymap.set("n", "<leader>gm", function()
      my_commits()
    end, { desc = "Browse my commits, <cr> lists their files" })
    keymap.set("n", "<leader>gn", function()
      my_last_commit()
    end, { desc = "Files of my last commit" })
    keymap.set("n", "<leader>gb", "<cmd>Telescope git_bcommits<cr>", { desc = "Browse buffer commits with diff preview" })
    keymap.set("n", "<leader>gB", "<cmd>Telescope git_branches<cr>", { desc = "Browse git branches" })
    keymap.set("n", "<leader>gw", function()
      require("eti.extras.worktrees").pick()
    end, { desc = "Switch git worktree" })
  end,
}
