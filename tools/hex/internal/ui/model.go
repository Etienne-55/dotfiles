package ui

import (
	"strings"

	"hex/internal/keymaps"

	"github.com/charmbracelet/bubbles/cursor"
	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
)

type rowKind int

const (
	rowEntry rowKind = iota
	rowHeader
	rowSpacer
)

// row is one line of the list: a binding, or in the All tab a category's
// header and the blank line before it.
type row struct {
	kind  rowKind
	cat   keymaps.Category
	entry int // rowEntry: index into Model.entries
	count int // rowHeader: bindings in the section
}

// tab is one of the tabs; the first, all, lists every category.
type tab struct {
	all bool
	cat keymaps.Category
}

type Model struct {
	// ConfigDir is the neovim config the bindings are read from.
	ConfigDir string

	// Popup is set when running inside a tmux popup (--popup). The popup's
	// border frames the app, so its own is hidden - kept at the same size,
	// so the layout is the same either way.
	Popup bool

	entries  []keymaps.Entry
	haystack []string // what each entry is filtered on, lowercased
	warnings []string

	tabs   []tab
	tab    int
	counts []int // per tab, the bindings matching the filter

	filter    textinput.Model
	filtering bool // typing in the filter

	rows      []row
	entryRows []int // indices of the rows that are bindings
	sel       int   // selected binding, an index into entryRows
	offset    int   // first row shown

	width, height int

	help   help.Model
	status string // result of the last action, until the next key

	frame int // of the logo's flames
}

func NewModel(configDir string, popup bool) Model {
	ti := textinput.New()
	ti.Prompt = "/ "
	ti.Placeholder = "keys, description, file…"
	ti.PromptStyle = accentStyle
	ti.TextStyle = textStyle
	ti.PlaceholderStyle = mutedStyle
	ti.Cursor.SetMode(cursor.CursorStatic)

	h := help.New()
	h.Styles.ShortKey = accentStyle
	h.Styles.ShortDesc = mutedStyle
	h.Styles.ShortSeparator = mutedStyle

	m := Model{ConfigDir: configDir, Popup: popup, filter: ti, help: h}
	m.load()
	m.rebuild(false)
	return m
}

func (m Model) Init() tea.Cmd { return flameTick() }

// load reads the bindings, and the tabs of the categories that have some.
func (m *Model) load() {
	m.entries, m.warnings = keymaps.Load(m.ConfigDir)
	m.haystack = make([]string, len(m.entries))
	present := map[keymaps.Category]bool{}
	for i, e := range m.entries {
		m.haystack[i] = strings.ToLower(strings.Join([]string{
			e.Keys, e.Display, e.Desc, e.Note, e.Action, e.Scope, e.Category.String(), e.File,
		}, " "))
		present[e.Category] = true
	}
	m.tabs = []tab{{all: true}}
	for _, c := range keymaps.Categories {
		if present[c] {
			m.tabs = append(m.tabs, tab{cat: c})
		}
	}
	if m.tab >= len(m.tabs) {
		m.tab = 0
	}
}

// reload re-reads the config after it was edited, staying on the same tab
// and binding.
func (m *Model) reload() {
	current := m.tabs[m.tab]
	var file, keys string
	if e, ok := m.selected(); ok {
		file, keys = e.File, e.Keys
	}

	m.load()
	m.tab = 0
	for t, tb := range m.tabs {
		if tb == current {
			m.tab = t
		}
	}
	m.rebuild(false)
	for k, r := range m.entryRows {
		if e := m.entries[m.rows[r].entry]; e.File == file && e.Keys == keys {
			m.sel = k
			break
		}
	}
	m.scrollToSelection()
}

// rebuild lays out the rows of the current tab under the filter. With
// keep, the selection stays on the same binding while it is still listed;
// otherwise it goes back to the top.
func (m *Model) rebuild(keep bool) {
	previous := -1
	if keep && len(m.entryRows) > 0 {
		previous = m.rows[m.entryRows[m.sel]].entry
	}

	terms := strings.Fields(strings.ToLower(m.filter.Value()))
	byCat := map[keymaps.Category][]int{}
	total := 0
	for i := range m.entries {
		if matches(m.haystack[i], terms) {
			c := m.entries[i].Category
			byCat[c] = append(byCat[c], i)
			total++
		}
	}
	m.counts = make([]int, len(m.tabs))
	for t, tb := range m.tabs {
		if tb.all {
			m.counts[t] = total
		} else {
			m.counts[t] = len(byCat[tb.cat])
		}
	}

	m.rows, m.entryRows = nil, nil
	current := m.tabs[m.tab]
	for _, c := range keymaps.Categories {
		found := byCat[c]
		if len(found) == 0 || (!current.all && c != current.cat) {
			continue
		}
		if current.all {
			if len(m.rows) > 0 {
				m.rows = append(m.rows, row{kind: rowSpacer})
			}
			m.rows = append(m.rows, row{kind: rowHeader, cat: c, count: len(found)})
		}
		for _, i := range found {
			m.entryRows = append(m.entryRows, len(m.rows))
			m.rows = append(m.rows, row{kind: rowEntry, cat: c, entry: i})
		}
	}

	m.sel = 0
	for k, r := range m.entryRows {
		if m.rows[r].entry == previous {
			m.sel = k
			break
		}
	}
	m.offset = 0
	m.scrollToSelection()
}

func matches(haystack string, terms []string) bool {
	for _, t := range terms {
		if !strings.Contains(haystack, t) {
			return false
		}
	}
	return true
}

func (m Model) selected() (keymaps.Entry, bool) {
	if len(m.entryRows) == 0 {
		return keymaps.Entry{}, false
	}
	return m.entries[m.rows[m.entryRows[m.sel]].entry], true
}

// move moves the selection by delta bindings.
func (m *Model) move(delta int) {
	if len(m.entryRows) == 0 {
		return
	}
	m.sel = clamp(m.sel+delta, 0, len(m.entryRows)-1)
	m.scrollToSelection()
}

func (m *Model) switchTab(delta int) {
	m.tab = (m.tab + delta + len(m.tabs)) % len(m.tabs)
	m.rebuild(true)
}

// scrollToSelection scrolls just enough to show the selected binding, and
// the header of its section when it is the section's first.
func (m *Model) scrollToSelection() {
	h := m.listHeight()
	if len(m.entryRows) == 0 {
		m.offset = 0
		return
	}
	r := m.entryRows[m.sel]
	top := r
	switch {
	case m.sel == 0:
		top = 0
	case r > 0 && m.rows[r-1].kind == rowHeader:
		top = r - 1
	}
	if top < m.offset {
		m.offset = top
	}
	if r >= m.offset+h {
		m.offset = r - h + 1
	}
	m.offset = clamp(m.offset, 0, max(len(m.rows)-h, 0))
}

// The frame: a border and a column of padding on each side.
func (m Model) innerWidth() int  { return max(m.width-4, 20) }
func (m Model) innerHeight() int { return max(m.height-2, 6) }

// compact drops the logo and a detail line on short terminals.
func (m Model) compact() bool { return m.innerHeight() < 18 }

// headerHeight is the rows above the tabs: the big logo when there is room
// for it and a list under it, the mini one otherwise, or a single line.
func (m Model) headerHeight() int {
	switch h := m.innerHeight(); {
	case h < 18:
		return 1
	case h < 32:
		return len(miniLogo)
	}
	return len(bigLogo)
}

func (m Model) listHeight() int {
	fixed := m.headerHeight() + 7 // header, blank, tabs, rule, rule, detail (2), help
	if m.compact() {
		fixed = 6 // search, tabs, rule, rule, detail, help
	}
	return max(m.innerHeight()-fixed, 1)
}

func clamp(v, lo, hi int) int {
	return max(lo, min(v, hi))
}
