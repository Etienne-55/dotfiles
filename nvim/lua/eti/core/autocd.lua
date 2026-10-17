-- Move into the project when nvim was started from home (e.g. a file opened
-- from the dashboard), so pickers search the project instead of all of ~.
--
-- Only kicks in while the cwd is $HOME: a cwd you chose yourself is left alone.
-- Inside a project with a src/ folder, a file under src/ moves you to src/
-- (the root for anything else, like package.json).

-- resolved, so a symlinked home still compares equal to getcwd()
local home = vim.uv.fs_realpath(vim.uv.os_homedir()) or vim.uv.os_homedir()

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("eti_autocd", { clear = true }),
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= "" or vim.uv.fs_realpath(vim.fn.getcwd()) ~= home then
      return
    end
    local file = vim.api.nvim_buf_get_name(ev.buf)
    file = file ~= "" and vim.uv.fs_realpath(file)
    if not file then
      return
    end

    local root = vim.fs.root(file, { ".git", "package.json", "go.mod", "Cargo.toml", "pyproject.toml" })
    if not root or root == home then
      return
    end
    local src = root .. "/src"
    local dir = vim.startswith(file, src .. "/") and src or root

    vim.cmd.cd(vim.fn.fnameescape(dir))
    vim.notify("cwd → " .. vim.fn.fnamemodify(dir, ":~"), vim.log.levels.INFO, { title = "Project" })
  end,
})
