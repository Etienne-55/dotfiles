package ui

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"hex/internal/keymaps"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
)

func (m Model) View() string {
	if m.width == 0 {
		return ""
	}
	w := m.innerWidth()

	var lines []string
	if m.compact() {
		lines = append(lines, m.renderSearchLine(w))
	} else {
		lines = append(lines, m.renderHeader(w)...)
		lines = append(lines, "")
	}
	lines = append(lines, m.renderTabs(w), rule(w, ""))
	lines = append(lines, m.renderList(w, m.listHeight())...)
	lines = append(lines, rule(w, m.position()))
	lines = append(lines, m.renderDetail(w)...)
	lines = append(lines, m.renderHelp(w))

	border := lipgloss.RoundedBorder()
	if m.Popup {
		border = lipgloss.HiddenBorder()
	}
	return lipgloss.NewStyle().
		Border(border).
		BorderForeground(ColorBorder).
		Padding(0, 1).
		Render(strings.Join(lines, "\n"))
}

// renderHeader draws the logo, with the filter and the key legend beside
// it, in headerHeight rows. A terminal too narrow for the big logo gets the
// mini one, and one narrower still neither.
func (m Model) renderHeader(w int) []string {
	const gap = 4
	n := m.headerHeight()

	var logo []string
	for _, rows := range [][]string{bigLogo, miniLogo} {
		if len(rows) <= n && w-lipgloss.Width(rows[0])-gap >= 40 {
			logo = strings.Split(renderLogo(rows, m.frame), "\n")
			break
		}
	}
	// beside the logo, each row drawn at the width left for it
	legend := func(int) string { return m.renderLegend() }
	right := []func(int) string{m.renderSearchLine, legend}
	if n >= 5 {
		right = []func(int) string{m.renderSearchLine, func(int) string { return "" }, legend}
	}

	indent, rest := "", w
	if logo != nil {
		indent = strings.Repeat(" ", lipgloss.Width(logo[0])+gap)
		rest = w - len(indent)
	}
	lines := make([]string, n)
	for i := range lines {
		left := indent
		if k := i - (n-len(logo))/2; logo != nil && k >= 0 && k < len(logo) {
			left = logo[k] + strings.Repeat(" ", gap)
		}
		text := ""
		if k := i - (n-len(right))/2; k >= 0 && k < len(right) {
			text = right[k](rest)
		}
		lines[i] = left + fit(text, rest)
	}
	return lines
}

// renderSearchLine puts the filter and the counts at the two ends of a
// w-wide line.
func (m Model) renderSearchLine(w int) string {
	return spread(m.renderSearch(), m.renderStats(), w)
}

func (m Model) renderSearch() string {
	switch {
	case m.filtering:
		return m.filter.View()
	case m.filter.Value() != "":
		return accentStyle.Render("/ ") + textStyle.Render(m.filter.Value()) + mutedStyle.Render("   esc clears")
	}
	return accentStyle.Render("/") + mutedStyle.Render(" filter")
}

func (m Model) renderStats() string {
	total := m.counts[0]
	stats := fmt.Sprintf("%d bindings", total)
	if m.filter.Value() != "" {
		stats = fmt.Sprintf("%d of %d bindings", total, len(m.entries))
	}
	return mutedStyle.Render(stats + " · " + tildePath(m.ConfigDir))
}

func (m Model) renderLegend() string {
	var parts []string
	for _, l := range [][2]string{{"␣", "leader"}, {"⌃", "ctrl"}, {"⌥", "alt"}, {"⇧", "shift"}, {"⏎", "enter"}} {
		parts = append(parts, accentStyle.Render(l[0])+" "+mutedStyle.Render(l[1]))
	}
	return strings.Join(parts, "   ")
}

// renderTabs draws the category tabs, each with its count of matching
// bindings. When they don't all fit, the ones around the current tab show.
func (m Model) renderTabs(w int) string {
	labels := make([]string, len(m.tabs))
	for t, tb := range m.tabs {
		name, color := "ALL", ColorAccent
		if !tb.all {
			name, color = strings.ToUpper(tb.cat.String()), categoryColors[tb.cat]
		}
		count := fmt.Sprint(m.counts[t])
		switch {
		case t == m.tab:
			labels[t] = lipgloss.NewStyle().Bold(true).Foreground(ColorDark).Background(color).
				Render(" " + name + " " + count + " ")
		case m.counts[t] == 0:
			labels[t] = mutedStyle.Render(" " + name + " " + count + " ")
		default:
			labels[t] = " " + lipgloss.NewStyle().Foreground(color).Render(name) + " " + mutedStyle.Render(count) + " "
		}
	}

	width := func(from, to int) int {
		n := 0
		for _, l := range labels[from : to+1] {
			n += lipgloss.Width(l) + 1
		}
		return n
	}
	from, to := 0, len(labels)-1
	if width(from, to) > w {
		const markers = 4 // "‹ " and " ›"
		from, to = m.tab, m.tab
		for grew := true; grew; {
			grew = false
			if to+1 < len(labels) && width(from, to+1) <= w-markers {
				to++
				grew = true
			}
			if from > 0 && width(from-1, to) <= w-markers {
				from--
				grew = true
			}
		}
	}

	line := strings.Join(labels[from:to+1], " ")
	if from > 0 {
		line = mutedStyle.Render("‹ ") + line
	}
	if to < len(labels)-1 {
		line += mutedStyle.Render(" ›")
	}
	return fit(line, w)
}

// columns are the widths of the list's columns.
type columns struct {
	key, mode, desc, file int
}

func (m Model) columns(w int) columns {
	c := columns{key: 4, mode: 1}
	for _, r := range m.rows {
		if r.kind != rowEntry {
			continue
		}
		e := m.entries[r.entry]
		c.key = max(c.key, lipgloss.Width(e.Display))
		c.mode = max(c.mode, len(e.Modes))
		c.file = max(c.file, lipgloss.Width(filepath.Base(e.File)))
	}
	c.key = min(c.key, 18)
	c.mode = min(c.mode, 4)
	c.file = min(c.file, 24)
	if w < 90 {
		c.file = 0 // no room for the source column
	}
	// selection bar, space, key, gap, mode, gap, description, gap, file
	c.desc = w - 2 - c.key - 2 - c.mode - 2
	if c.file > 0 {
		c.desc -= c.file + 2
	}
	c.desc = max(c.desc, 10)
	return c
}

func (m Model) renderList(w, h int) []string {
	lines := make([]string, 0, h)
	if len(m.rows) == 0 {
		msg := "no bindings found in " + tildePath(m.ConfigDir)
		if m.filter.Value() != "" {
			msg = fmt.Sprintf("no binding matches “%s”", m.filter.Value())
		}
		lines = append(lines, "", fit("  "+mutedStyle.Render(msg), w))
		for _, warning := range m.warnings {
			lines = append(lines, fit("  "+badStyle.Render(warning), w))
		}
	}

	cols := m.columns(w)
	selectedRow := -1
	if len(m.entryRows) > 0 {
		selectedRow = m.entryRows[m.sel]
	}
	for r := m.offset; r < len(m.rows) && len(lines) < h; r++ {
		switch row := m.rows[r]; row.kind {
		case rowSpacer:
			lines = append(lines, "")
		case rowHeader:
			lines = append(lines, renderSectionHeader(row, w))
		default:
			lines = append(lines, m.renderEntry(m.entries[row.entry], r == selectedRow, cols, w))
		}
	}
	for len(lines) < h {
		lines = append(lines, "")
	}
	for i := range lines {
		lines[i] = fit(lines[i], w)
	}
	return lines[:h]
}

// renderSectionHeader titles a school of hexes like a page of a spell
// book: a star, the name in spaced capitals, a rule in the school's color.
func renderSectionHeader(r row, w int) string {
	color := categoryColors[r.cat]
	title := lipgloss.NewStyle().Foreground(color).Render("✦ ") +
		lipgloss.NewStyle().Bold(true).Foreground(color).Render(spaced(strings.ToUpper(r.cat.String())))
	count := mutedStyle.Render(fmt.Sprint(r.count))
	fill := w - 1 - lipgloss.Width(title) - 2 - lipgloss.Width(count) - 1
	return " " + title + " " + lipgloss.NewStyle().Foreground(shade(color, 0.4)).Render(strings.Repeat("─", max(fill, 0))) + " " + count
}

// spaced letter-spaces a word: "GIT" reads "G I T".
func spaced(s string) string {
	return strings.Join(strings.Split(s, ""), " ")
}

func (m Model) renderEntry(e keymaps.Entry, selected bool, c columns, w int) string {
	color := categoryColors[e.Category]
	style := func(s lipgloss.Style) lipgloss.Style {
		if selected {
			return s.Background(ColorSelected)
		}
		return s
	}
	plain := style(lipgloss.NewStyle())

	// each hex has its rune, lit when selected
	bar, barColor := "◇", shade(color, 0.55)
	if selected {
		bar, barColor = "◆", color
	}

	descStyle := textStyle
	if e.DescIsCode {
		descStyle = subtleStyle.Italic(true)
	}
	desc := ansi.Truncate(e.Desc, c.desc, "…")
	var scope string
	if room := c.desc - lipgloss.Width(desc) - 2; e.Scope != "" && room >= 4 {
		scope = ansi.Truncate(e.Scope, room, "…")
	}

	var b strings.Builder
	b.WriteString(style(lipgloss.NewStyle().Foreground(barColor)).Render(bar))
	b.WriteString(plain.Render(" "))
	b.WriteString(style(lipgloss.NewStyle().Bold(true).Foreground(color)).Render(pad(ansi.Truncate(e.Display, c.key, "…"), c.key)))
	b.WriteString(plain.Render("  "))
	b.WriteString(style(mutedStyle).Render(pad(e.Modes, c.mode)))
	b.WriteString(plain.Render("  "))
	b.WriteString(style(descStyle).Render(desc))
	used := lipgloss.Width(desc)
	if scope != "" {
		b.WriteString(plain.Render("  "))
		b.WriteString(style(mutedStyle.Italic(true)).Render(scope))
		used += 2 + lipgloss.Width(scope)
	}
	b.WriteString(plain.Render(strings.Repeat(" ", max(c.desc-used, 0))))
	if c.file > 0 {
		file := ansi.Truncate(filepath.Base(e.File), c.file, "…")
		b.WriteString(plain.Render("  " + strings.Repeat(" ", c.file-lipgloss.Width(file))))
		b.WriteString(style(mutedStyle).Render(file))
	}
	line := b.String()
	if extra := w - lipgloss.Width(line); extra > 0 {
		line += plain.Render(strings.Repeat(" ", extra))
	}
	return line
}

// renderDetail describes the selected binding: what it runs and where it
// is defined, then its modes, scope and any longer note.
func (m Model) renderDetail(w int) []string {
	n := 2
	if m.compact() {
		n = 1
	}
	lines := make([]string, n)
	e, ok := m.selected()
	if !ok {
		return lines
	}

	loc := e.File
	if e.Line > 0 {
		loc = fmt.Sprintf("%s:%d", e.File, e.Line)
	}
	keys := lipgloss.NewStyle().Bold(true).Foreground(categoryColors[e.Category]).Render(e.Keys)
	room := w - lipgloss.Width(keys) - 5 - lipgloss.Width(loc) - 2
	action := ""
	if room > 5 && e.Action != "" {
		action = mutedStyle.Render("  →  ") + textStyle.Render(ansi.Truncate(e.Action, room, "…"))
	}
	lines[0] = spread(" "+keys+action, mutedStyle.Render(loc), w)

	if n > 1 {
		var info []string
		if modes := keymaps.ModeNames(e.Modes); modes != "" {
			info = append(info, modes)
		}
		if e.Scope != "" {
			info = append(info, "in "+e.Scope)
		}
		switch {
		case e.Note != "":
			info = append(info, e.Note)
		case lipgloss.Width(e.Desc) > m.columns(w).desc:
			info = append(info, e.Desc) // cut short in the list
		}
		lines[1] = fit(" "+subtleStyle.Render(ansi.Truncate(strings.Join(info, " · "), w-1, "…")), w)
	}
	return lines
}

func (m Model) renderHelp(w int) string {
	var bindings helpBindings
	if m.filtering {
		k := FilterKeys
		bindings = helpBindings{k.Up, k.NextTab, k.Accept, k.Cancel, k.Quit}
	} else {
		k := ListKeys
		bindings = helpBindings{k.Filter, k.NextTab, k.Up, k.Open}
		if m.filter.Value() != "" {
			bindings = append(bindings, k.Clear)
		}
		bindings = append(bindings, k.Quit)
	}

	right := ""
	switch {
	case m.status != "":
		right = accentStyle.Render(m.status)
	case len(m.warnings) > 0 && len(m.rows) > 0:
		right = badStyle.Render(m.warnings[0])
	}
	h := m.help
	h.Width = max(w-1-lipgloss.Width(right)-2, 10)
	return spread(" "+h.View(bindings), right, w)
}

// position is the selected binding's place in the list, for the rule
// under it.
func (m Model) position() string {
	if len(m.entryRows) <= m.listHeight() {
		return ""
	}
	return fmt.Sprintf("%d/%d", m.sel+1, len(m.entryRows))
}

// rule draws a divider, with a label at its right end, or else the moon
// in its middle.
func rule(w int, label string) string {
	if label == "" {
		const moon = " ☽ ✦ ☾ "
		left := (w - lipgloss.Width(moon)) / 2
		if left < 3 {
			return ruleStyle.Render(strings.Repeat("─", w))
		}
		return ruleStyle.Render(strings.Repeat("─", left)) + mutedStyle.Render(moon) +
			ruleStyle.Render(strings.Repeat("─", w-left-lipgloss.Width(moon)))
	}
	return ruleStyle.Render(strings.Repeat("─", max(w-len(label)-3, 0))) + mutedStyle.Render(" "+label+" ") + ruleStyle.Render("─")
}

// spread puts left and right at the two ends of a w-wide line.
func spread(left, right string, w int) string {
	space := w - lipgloss.Width(left) - lipgloss.Width(right)
	if space < 1 {
		return fit(left, w)
	}
	return left + strings.Repeat(" ", space) + right
}

// fit cuts or pads a styled line to exactly w columns.
func fit(s string, w int) string {
	if lipgloss.Width(s) > w {
		s = ansi.Truncate(s, w, "…")
	}
	return pad(s, w)
}

func pad(s string, w int) string {
	return s + strings.Repeat(" ", max(w-lipgloss.Width(s), 0))
}

func tildePath(p string) string {
	if home, err := os.UserHomeDir(); err == nil && strings.HasPrefix(p, home) {
		return "~" + strings.TrimPrefix(p, home)
	}
	return p
}
