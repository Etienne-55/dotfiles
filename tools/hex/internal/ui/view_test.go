package ui

import (
	"strings"
	"testing"

	"hex/internal/keymaps"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
)

func newTestModel(t *testing.T, width, height int) Model {
	t.Helper()
	// no ~/.tmux.conf or ~/.zshrc there: the fixture's tmux/ and zsh/ are read
	home, original := t.TempDir(), keymaps.HomeDir
	keymaps.HomeDir = func() (string, error) { return home, nil }
	t.Cleanup(func() { keymaps.HomeDir = original })

	m := NewModel("../../testdata/dotfiles/nvim", true)
	return send(m, tea.WindowSizeMsg{Width: width, Height: height})
}

func send(m Model, msgs ...tea.Msg) Model {
	for _, msg := range msgs {
		next, _ := m.Update(msg)
		m = next.(Model)
	}
	return m
}

func typed(s string) []tea.Msg {
	var msgs []tea.Msg
	for _, r := range s {
		msgs = append(msgs, tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{r}})
	}
	return msgs
}

// The frame is exactly the terminal's size at any size: a line one column
// too wide wraps, and shifts everything under it.
func TestViewFillsTheTerminal(t *testing.T) {
	for _, size := range [][2]int{{150, 40}, {100, 24}, {80, 16}, {60, 12}} {
		for _, popup := range []bool{true, false} {
			m := newTestModel(t, size[0], size[1])
			m.Popup = popup
			m = send(m, tea.KeyMsg{Type: tea.KeyDown}, tea.KeyMsg{Type: tea.KeyDown})
			lines := strings.Split(m.View(), "\n")
			if len(lines) != size[1] {
				t.Errorf("%dx%d: %d lines", size[0], size[1], len(lines))
			}
			for i, l := range lines {
				if w := lipgloss.Width(l); w != size[0] {
					t.Errorf("%dx%d popup=%v: line %d is %d wide: %q", size[0], size[1], popup, i, w, ansi.Strip(l))
				}
			}
		}
	}
}

func TestFilter(t *testing.T) {
	m := newTestModel(t, 120, 30)
	all := len(m.entryRows)

	m = send(m, typed("/git")...)
	if !m.filtering || len(m.entryRows) == 0 || len(m.entryRows) >= all {
		t.Fatalf("filtering %v: %d of %d rows", m.filtering, len(m.entryRows), all)
	}
	for _, r := range m.entryRows {
		if e := m.entries[m.rows[r].entry]; !strings.Contains(strings.ToLower(e.Desc+e.Action+e.Category.String()+e.File), "git") {
			t.Errorf("%q doesn't match", e.Keys)
		}
	}

	// q types while filtering, instead of quitting
	if _, cmd := m.Update(typed("q")[0]); cmd != nil {
		if _, quit := cmd().(tea.QuitMsg); quit {
			t.Error("q quit while typing a filter")
		}
	}

	// enter keeps the filter, esc then clears it, and esc again quits
	m = send(m, tea.KeyMsg{Type: tea.KeyEnter})
	if m.filtering || m.filter.Value() != "git" {
		t.Fatalf("after enter: filtering %v, filter %q", m.filtering, m.filter.Value())
	}
	m = send(m, tea.KeyMsg{Type: tea.KeyEsc})
	if m.filter.Value() != "" || len(m.entryRows) != all {
		t.Fatalf("after esc: filter %q, %d rows", m.filter.Value(), len(m.entryRows))
	}
	if _, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEsc}); cmd == nil {
		t.Error("esc with no filter didn't quit")
	} else if _, quit := cmd().(tea.QuitMsg); !quit {
		t.Error("esc with no filter didn't quit")
	}
}

func TestTabs(t *testing.T) {
	m := newTestModel(t, 120, 30)
	if !m.tabs[0].all {
		t.Fatal("the first tab isn't All")
	}
	m = send(m, tea.KeyMsg{Type: tea.KeyRight})
	cat := m.tabs[m.tab].cat
	for _, r := range m.rows {
		if r.kind != rowEntry || m.entries[r.entry].Category != cat {
			t.Fatalf("tab %v lists %+v", cat, r)
		}
	}
	// wraps around to All
	m = send(m, tea.KeyMsg{Type: tea.KeyLeft}, tea.KeyMsg{Type: tea.KeyLeft})
	if m.tab != len(m.tabs)-1 {
		t.Errorf("left from All went to tab %d of %d", m.tab, len(m.tabs))
	}
}
