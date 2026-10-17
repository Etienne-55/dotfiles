package keymaps

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
)

// HomeDir is where ~/.tmux.conf and ~/.zshrc are looked for; tests point it
// elsewhere.
var HomeDir = os.UserHomeDir

// Load reads every binding: neovim's from the config in dir, tmux's and the
// shell's from the home directory - falling back to the copies in the dotfiles
// repo dir sits in (../tmux, ../zsh). Files that can't be read are reported in
// warnings; the rest still load.
func Load(dir string) (entries []Entry, warnings []string) {
	nvim, err := ParseNvim(dir)
	if err != nil {
		warnings = append(warnings, fmt.Sprintf("neovim config %s: %v", dir, err))
	}
	entries = append(entries, nvim...)

	sources := []struct {
		home, repo string
		parse      func(path, display string) ([]Entry, error)
	}{
		{".tmux.conf", "tmux/tmux.conf", ParseTmux},
		{".zshrc", "zsh/zshrc", ParseShell},
	}
	home, _ := HomeDir()
	for _, s := range sources {
		path, display := filepath.Join(home, s.home), "~/"+s.home
		if _, err := os.Stat(path); err != nil {
			path, display = filepath.Join(filepath.Dir(dir), s.repo), s.repo
		}
		found, err := s.parse(path, display)
		if err != nil {
			if !os.IsNotExist(err) {
				warnings = append(warnings, fmt.Sprintf("%s: %v", display, err))
			}
			continue
		}
		entries = append(entries, found...)
	}

	sort.SliceStable(entries, func(i, j int) bool { return entries[i].Category < entries[j].Category })
	return entries, warnings
}
