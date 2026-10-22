package ui

import (
	"os/exec"
	"strconv"

	"github.com/charmbracelet/bubbles/key"
	tea "github.com/charmbracelet/bubbletea"
)

// editedMsg reports that nvim, opened on a binding's definition, exited.
type editedMsg struct{ err error }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.scrollToSelection()
		return m, nil

	case flameMsg:
		m.frame++
		return m, flameTick()

	case editedMsg:
		// the definition may have changed: read the config again
		m.reload()
		m.status = "reloaded"
		if msg.err != nil {
			m.status = "nvim: " + msg.err.Error()
		}
		return m, nil

	case tea.MouseMsg:
		if msg.Action == tea.MouseActionPress {
			switch msg.Button {
			case tea.MouseButtonWheelUp:
				m.move(-3)
			case tea.MouseButtonWheelDown:
				m.move(3)
			}
		}
		return m, nil

	case tea.KeyMsg:
		m.status = ""
		if m.filtering {
			return m.updateFilter(msg)
		}
		return m.updateList(msg)
	}
	return m, nil
}

func (m Model) updateList(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	k := ListKeys
	switch {
	case key.Matches(msg, k.Quit):
		return m, tea.Quit
	case key.Matches(msg, k.Clear):
		// esc clears the filter, and once there is none closes the popup
		if m.filter.Value() == "" {
			return m, tea.Quit
		}
		m.filter.SetValue("")
		m.rebuild(true)
	case key.Matches(msg, k.Filter):
		m.filtering = true
		m.filter.CursorEnd()
		return m, m.filter.Focus()
	case key.Matches(msg, k.Up):
		m.move(-1)
	case key.Matches(msg, k.Down):
		m.move(1)
	case key.Matches(msg, k.PageUp):
		m.move(-max(m.listHeight()/2, 1))
	case key.Matches(msg, k.PageDown):
		m.move(max(m.listHeight()/2, 1))
	case key.Matches(msg, k.Top):
		m.move(-len(m.entryRows))
	case key.Matches(msg, k.Bottom):
		m.move(len(m.entryRows))
	case key.Matches(msg, k.PrevTab):
		m.switchTab(-1)
	case key.Matches(msg, k.NextTab):
		m.switchTab(1)
	case key.Matches(msg, k.Open):
		return m, m.openDefinition()
	default:
		// 0 is All, 1-9 the categories in order
		if s := msg.String(); len(s) == 1 && s[0] >= '0' && s[0] <= '9' {
			if t := int(s[0] - '0'); t < len(m.tabs) {
				m.tab = t
				m.rebuild(true)
			}
		}
	}
	return m, nil
}

func (m Model) updateFilter(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	k := FilterKeys
	switch {
	case key.Matches(msg, k.Quit):
		return m, tea.Quit
	case key.Matches(msg, k.Cancel):
		m.filtering = false
		m.filter.Blur()
		m.filter.SetValue("")
		m.rebuild(true)
	case key.Matches(msg, k.Accept):
		m.filtering = false
		m.filter.Blur()
	case key.Matches(msg, k.Up):
		m.move(-1)
	case key.Matches(msg, k.Down):
		m.move(1)
	case key.Matches(msg, k.PrevTab):
		m.switchTab(-1)
	case key.Matches(msg, k.NextTab):
		m.switchTab(1)
	default:
		before := m.filter.Value()
		var cmd tea.Cmd
		m.filter, cmd = m.filter.Update(msg)
		if m.filter.Value() != before {
			// a new query starts from its best match, at the top
			m.rebuild(false)
		}
		return m, cmd
	}
	return m, nil
}

// openDefinition opens the selected binding's definition in nvim, in the
// same terminal. The list comes back, re-read, when nvim exits.
func (m Model) openDefinition() tea.Cmd {
	e, ok := m.selected()
	if !ok || e.Path == "" {
		return nil
	}
	var args []string
	if e.Line > 0 {
		args = append(args, "+"+strconv.Itoa(e.Line))
	}
	cmd := exec.Command("nvim", append(args, e.Path)...)
	cmd.Dir = m.ConfigDir
	return tea.ExecProcess(cmd, func(err error) tea.Msg { return editedMsg{err} })
}
