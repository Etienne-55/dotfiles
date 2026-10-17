# Quick setup for a new mac

## On the new machine

```bash
git clone <this-repo> ~/.config/nvim
~/.config/nvim/setup/bootstrap.sh
```

That's it. The script asks for your password once (Homebrew) and takes a while on
the `brew bundle` step.

## What the script does

1. Installs the Xcode command line tools and Homebrew if they're missing.
2. Installs everything in `Brewfile` (16 formulas, 2 casks) — just what neovim,
   ghostty and the dotfiles need: neovim, git, lazygit, ripgrep, fd, eza, node,
   go, tree-sitter, tmux, fzf, zoxide, git-delta, powerlevel10k,
   zsh-autosuggestions, zsh-syntax-highlighting, the symbols nerd font and ghostty.
3. Symlinks the dotfiles in `dotfiles/` into your home folder, backing up
   anything already there into `~/.dotfiles-backup/<date>/`.
4. Adds an `[include]` of `dotfiles/gitconfig` to the top of `~/.gitconfig`,
   keeping everything already in it.
5. Installs tmux's plugin manager and your tmux plugins.
6. Installs pokemon-colorscripts (the random Pokémon on the neovim dashboard).
7. Installs the neovim plugins, language servers and formatters.

Because the dotfiles are **symlinks**, editing `~/.zshrc` edits the copy in this
repo — commit it and the next machine gets it.

`~/.gitconfig` is the exception: it stays a real file for this machine's own
settings (identity, `core.hooksPath`, git-lfs, ...), which override the shared
ones, and `git config --global` writes there, never into this repo.

## Files

| File | Goes to |
|---|---|
| `dotfiles/zshrc` | `~/.zshrc` |
| `dotfiles/p10k.zsh` | `~/.p10k.zsh` (powerlevel10k prompt) |
| `dotfiles/tmux.conf` | `~/.tmux.conf` |
| `dotfiles/ghostty/` | `~/.config/ghostty/` (terminal config + the Neon theme) |
| `dotfiles/gitconfig` | included from `~/.gitconfig` |
| `dotfiles/tmux-cht.sh` | `~/.tmux-cht.sh` (prefix + i cheat sheet) |
| `dotfiles/claude-settings.json` | `~/.claude/settings.json` (Claude Code settings, including the sounds it plays when it's done) |



The tmux popups prefix + e (gaufre) and prefix + Space (hex) run the binaries in
`../tools/` straight from the repo, so they need no install step.
