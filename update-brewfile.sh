#!/usr/bin/env bash
# Save what is currently installed on this mac into Brewfile.
# Run this whenever you install something you want on the next machine.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
brew bundle dump --file="$REPO_DIR/Brewfile" --force

echo "Updated $REPO_DIR/Brewfile"
echo "Formulas: $(grep -c '^brew ' "$REPO_DIR/Brewfile")  Casks: $(grep -c '^cask ' "$REPO_DIR/Brewfile")"
