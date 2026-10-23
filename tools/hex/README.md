# Hex

A cheat sheet of every key binding in this config: neovim, tmux and zsh.
Built with Go and Bubble Tea, and opened in a tmux popup.

It reads the config each time it opens instead of keeping its own list, so a
binding you add or change shows up without rebuilding anything.

## Usage

`prefix + Space` in tmux (see `tmux/tmux.conf`), or run it directly:

```bash
~/dotfiles/tools/hex/hex          # full screen
~/dotfiles/tools/hex/hex --popup  # inside a tmux popup: the popup's border frames it
~/dotfiles/tools/hex/hex --list   # print every binding, for grep
```

### Keys

- `←/→` or `h/l`, `tab/shift+tab`: switch category (`0` is All, `1`-`9` the others)
- `↑/↓` or `j/k`: move; `ctrl+d/ctrl+u` half a page; `g/G` top/bottom; the mouse wheel scrolls
- `/`: filter on keys, description, command or file. Every word must match (`git diff`), and each tab shows how many bindings it matches
- `enter` (or `e`): open the binding's definition in nvim at its line. Hex comes back when you quit nvim, with the config read again
- `esc`: clear the filter, then quit; `q` quits

Keys are written compactly: `␣` is the leader (space), `⌃` ctrl, `⌥` alt, `⇧` shift.
A description in dim italics means the mapping has no `desc`, so Hex shows its code.

## What it reads

- **neovim**: `init.lua` and everything under `lua/`: `vim.keymap.set(...)` (with
  `desc` in its opts, or an `opts.desc = ...` set just before), lazy.nvim `keys = { ... }`
  specs, local `map(mode, lhs, rhs, desc)` helpers like gitsigns', the `["<C-k>"] = ...`
  tables of telescope / blink.cmp / oil (a trailing `-- comment` becomes the description), and
  `for _, c in ipairs({ ... })` loops. vim-tmux-navigator's default keys, and the keys of
  a diffview tab, are added when the plugin is installed.
- **tmux**: `~/.tmux.conf`. The description is the comment above a binding (`# prefix + e: ...`),
  or the one at the end of its line.
- **zsh**: the aliases in `~/.zshrc`, plus functions that have a comment above them.

Categories come from the file a binding is in, with a few exceptions (`<leader>g…` is
always Git, anything about diagnostics is Diagnostics). The rules are in
`internal/keymaps/categorize.go`.

## Development

```bash
cd ~/dotfiles/tools/hex
go run .                                # run
go test ./...                           # test (against the small config in testdata/)
go build -ldflags="-s -w" -o hex .  # build the binary tmux opens (apple silicon)
```
