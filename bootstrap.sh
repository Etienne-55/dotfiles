#!/usr/bin/env bash
# Set up a new mac: homebrew packages, dotfiles, tmux plugins, neovim.
# Safe to run more than once - existing files are backed up, nothing is deleted.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*"; }

[ "$(uname -s)" = "Darwin" ] || { echo "This script is for macOS."; exit 1; }
# tmux.conf runs the popup tools from ~/dotfiles/tools; and run from ~/.config/nvim
# (the old layout), linking nvim would move this very repo into the backup folder
[ "$REPO_DIR" = "$HOME/dotfiles" ] || { echo "Clone this repo to ~/dotfiles (it is at $REPO_DIR)."; exit 1; }

# ---------------------------------------------------------------- xcode tools
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing the Xcode command line tools (compilers, git)"
  xcode-select --install || true
  echo "Accept the dialog, wait for it to finish, then run this script again."
  exit 1
fi

# ------------------------------------------------------------------ homebrew
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew (this asks for your password)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

log "Installing everything in Brewfile (this is the long part)"
brew bundle --file="$REPO_DIR/Brewfile"

# ------------------------------------------------------------------ dotfiles
# symlinked, so editing ~/.zshrc edits the file in this repo
link() {
  src="$REPO_DIR/$1"
  dest="$2"
  [ -e "$src" ] || { warn "missing in repo: $1"; return; }
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    log "already linked: $dest"
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dest" "$BACKUP_DIR/"
    warn "moved your existing $dest into $BACKUP_DIR"
  fi
  ln -s "$src" "$dest"
  log "linked $dest"
}

log "Linking dotfiles"
mkdir -p "$HOME/.config"
link nvim            "$HOME/.config/nvim"
link zsh/zshrc       "$HOME/.zshrc"
link zsh/p10k.zsh    "$HOME/.p10k.zsh"
link tmux/tmux.conf  "$HOME/.tmux.conf"
link tmux/tmux-cht.sh "$HOME/.tmux-cht.sh"
link tmux/tmux-cht-languages "$HOME/.tmux-cht-languages"
link tmux/tmux-cht-command   "$HOME/.tmux-cht-command"
link ghostty         "$HOME/.config/ghostty"
# real dir (not a symlink into this repo) so claude doesn't think it's in a git project
mkdir -p "$HOME/.claude-chat"
link claude/chat.md "$HOME/.claude-chat/CLAUDE.md"
# claude code settings, including the sounds it plays when it's done
mkdir -p "$HOME/.claude"
link claude/settings.json "$HOME/.claude/settings.json"

# ----------------------------------------------------------------------- git
# Not a symlink: ~/.gitconfig stays a real file for this machine's own settings
# (identity, core.hooksPath, git-lfs, ...) and pulls in git/gitconfig with an
# [include] at the top, so whatever is set below it wins. Re-running never replaces
# it, and `git config --global` writes land there instead of in this repo.
include_gitconfig() {
  src="$REPO_DIR/git/gitconfig"
  dest="$HOME/.gitconfig"
  if [ ! -L "$dest" ] && git config --file "$dest" --type=path --get-all include.path 2>/dev/null | grep -xF "$src" >/dev/null; then
    log "already included: $src"
    return
  fi
  tmp="$dest.bootstrap-tmp"
  {
    printf '[include]\n\tpath = %s\n' "$src"
    # keep what's there, unless it's the symlink into this repo that older versions made
    if [ -f "$dest" ] && ! [ "$dest" -ef "$src" ]; then
      cat "$dest"
    fi
  } > "$tmp"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dest" "$BACKUP_DIR/"
    warn "added the include to your $dest, previous version in $BACKUP_DIR"
  fi
  mv "$tmp" "$dest"
  log "included $src from $dest"
}
include_gitconfig

# --------------------------------------------------------------------- tmux
TPM="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM" ]; then
  log "Installing tmux plugin manager"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM"
fi
log "Installing tmux plugins"
"$TPM/bin/install_plugins" || warn "could not install tmux plugins - open tmux and press prefix + I"

# ------------------------------------------------------ pokemon-colorscripts
# random Pokémon on the neovim dashboard; not in homebrew, so installed per-user (no sudo)
POKE="$HOME/.local/share/pokemon-colorscripts"
if [ ! -d "$POKE" ]; then
  log "Installing pokemon-colorscripts"
  git clone --depth 1 https://gitlab.com/phoneybadger/pokemon-colorscripts.git "$POKE"
fi
mkdir -p "$HOME/.local/bin"
ln -sf "$POKE/pokemon-colorscripts.py" "$HOME/.local/bin/pokemon-colorscripts"

# ------------------------------------------------------------------ neovim
log "Installing neovim plugins"
nvim --headless "+Lazy! sync" +qa

log "Installing language servers and formatters (a few minutes)"
nvim --headless \
  -c 'autocmd User MasonToolsUpdateCompleted quitall' \
  -c 'lua vim.defer_fn(function() vim.cmd("cquit 1") end, 300000)' \
  -c 'MasonToolsInstall' || warn "run :Mason inside neovim to check"

# -------------------------------------------------------------------- done
cat <<'EOF'

Done. Still to do by hand:

  1. Restart your terminal (or: exec zsh) so the new shell config loads.
  2. GitHub: create an ssh key and add it to your account
       ssh-keygen -t ed25519 -C "your@email"
       cat ~/.ssh/id_ed25519.pub
  3. Claude Code, if you want it:
       curl -fsSL https://claude.ai/install.sh | bash
       then add to ~/.zshrc: export PATH="$HOME/.local/bin:$PATH"
  4. Open neovim once and let treesitter finish installing parsers.

Optional, makes vim navigation much nicer (needs a logout to take effect):
  defaults write -g KeyRepeat -int 2
  defaults write -g InitialKeyRepeat -int 15
  defaults write -g ApplePressAndHoldEnabled -bool false

EOF
