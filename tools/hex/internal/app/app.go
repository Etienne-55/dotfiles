package app

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"text/tabwriter"

	"hex/internal/keymaps"
	"hex/internal/ui"

	tea "github.com/charmbracelet/bubbletea"
)

// Run starts Hex on the neovim config in dir. popup is set when it runs
// inside a tmux popup, whose border then frames the app in place of its own.
func Run(dir string, popup bool) error {
	model := ui.NewModel(dir, popup)

	// The alternate screen gives Hex the whole terminal and restores
	// what was there on exit; the mouse is for scrolling with the wheel.
	p := tea.NewProgram(model, tea.WithAltScreen(), tea.WithMouseCellMotion())
	_, err := p.Run()
	return err
}

// List prints every binding as a table, for grep.
func List(w io.Writer, dir string) error {
	entries, warnings := keymaps.Load(dir)
	for _, warning := range warnings {
		fmt.Fprintln(os.Stderr, "warning:", warning)
	}
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	for _, e := range entries {
		loc := e.File
		if e.Line > 0 {
			loc = fmt.Sprintf("%s:%d", e.File, e.Line)
		}
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%s\t%s\n", e.Category, e.Modes, e.Display, e.Desc, e.Scope, loc)
	}
	return tw.Flush()
}

// ConfigDir picks the neovim config to read: the one given, else the one of
// the dotfiles repo this binary lives in (it is built into <repo>/tools/hex,
// the config is <repo>/nvim), else $XDG_CONFIG_HOME/nvim or ~/.config/nvim.
func ConfigDir(given string) string {
	if given != "" {
		if abs, err := filepath.Abs(given); err == nil {
			return abs
		}
		return given
	}
	if exe, err := os.Executable(); err == nil {
		if exe, err = filepath.EvalSymlinks(exe); err == nil {
			dir := filepath.Join(filepath.Dir(filepath.Dir(filepath.Dir(exe))), "nvim")
			if _, err := os.Stat(filepath.Join(dir, "init.lua")); err == nil {
				return dir
			}
		}
	}
	if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
		return filepath.Join(xdg, "nvim")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "nvim")
}
