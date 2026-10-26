# dotfiles

neovim, zsh, tmux, ghostty, git and Claude Code config for macOS, one folder per tool.

# Quick setup for a new mac

## On the new machine

```bash
git clone <this-repo> ~/dotfiles
~/dotfiles/bootstrap.sh
```

That's it. The script asks for your password once (Homebrew) and takes a while on
the `brew bundle` step.

## What the script does

1. Installs the Xcode command line tools and Homebrew if they're missing.
2. Installs everything in `Brewfile` (16 formulas, 2 casks) — just what neovim,
   ghostty and the dotfiles need: neovim, git, lazygit, ripgrep, fd, eza, node,
   go, tree-sitter, tmux, fzf, zoxide, git-delta, powerlevel10k,
   zsh-autosuggestions, zsh-syntax-highlighting, the symbols nerd font and ghostty.
3. Symlinks each tool's folder/files (table below) into your home folder, backing up
   anything already there into `~/.dotfiles-backup/<date>/`.
4. Adds an `[include]` of `git/gitconfig` to the top of `~/.gitconfig`,
   keeping everything already in it.
5. Installs tmux's plugin manager and your tmux plugins.
6. Installs the neovim plugins, language servers and formatters.

Because the dotfiles are **symlinks**, editing `~/.zshrc` edits the copy in this
repo — commit it and the next machine gets it.

`~/.gitconfig` is the exception: it stays a real file for this machine's own
settings (identity, `core.hooksPath`, git-lfs, ...), which override the shared
ones, and `git config --global` writes there, never into this repo.

## Files

| File | Goes to |
|---|---|
| `nvim/` | `~/.config/nvim/` |
| `zsh/zshrc` | `~/.zshrc` |
| `zsh/p10k.zsh` | `~/.p10k.zsh` (powerlevel10k prompt) |
| `tmux/tmux.conf` | `~/.tmux.conf` |
| `tmux/tmux-cht.sh` (+ `-languages`, `-command`) | `~/.tmux-cht.sh` (prefix + i cheat sheet) |
| `ghostty/` | `~/.config/ghostty/` (terminal config + the Neon theme) |
| `tuicr/` | `~/.config/tuicr/` (code review TUI config + the Neon theme) |
| `git/gitconfig` | included from `~/.gitconfig` |
| `claude/settings.json` | `~/.claude/settings.json` (Claude Code settings, including the sounds it plays when it's done) |
| `claude/chat.md` | `~/.claude-chat/CLAUDE.md` (the prefix + p claude popup) |
| `Brewfile` | `brew bundle`; `update-brewfile.sh` refreshes it from this mac |



The tmux popup prefix + Space (hex) runs the binary in `tools/hex` straight from
`~/dotfiles`, so it needs no install step.
