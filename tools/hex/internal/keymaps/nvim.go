package keymaps

import (
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// luaDirs are the config directories neovim loads Lua from.
var luaDirs = []string{"lua", "plugin", "after", "ftplugin"}

// scopes names where a file's buffer-local and in-plugin mappings apply.
var scopes = map[string]string{
	"telescope": "picker",
	"blink-cmp": "completion menu",
	"oil":       "oil",
	"dashboard": "dashboard",
}

// ParseNvim reads the bindings of the neovim config in dir.
func ParseNvim(dir string) ([]Entry, error) {
	paths, err := luaFiles(dir)
	if err != nil {
		return nil, err
	}

	files := make([]*luaFile, 0, len(paths))
	leader := `\`
	for _, path := range paths {
		src, err := os.ReadFile(path)
		if err != nil {
			return nil, err
		}
		f := newLuaFile(dir, path, string(src))
		if l, ok := f.leader(); ok {
			leader = l
		}
		files = append(files, f)
	}

	var entries []Entry
	for _, f := range files {
		for _, e := range f.scan() {
			e.Display = prettyVimKeys(e.Keys, leader)
			e.Category = categorize(e)
			entries = append(entries, e)
		}
	}
	return append(entries, pluginDefaults(files, leader)...), nil
}

// luaFiles lists init.lua and every Lua file neovim loads, sorted.
func luaFiles(dir string) ([]string, error) {
	var paths []string
	if _, err := os.Stat(filepath.Join(dir, "init.lua")); err == nil {
		paths = append(paths, filepath.Join(dir, "init.lua"))
	}
	for _, sub := range luaDirs {
		root := filepath.Join(dir, sub)
		if _, err := os.Stat(root); err != nil {
			continue
		}
		var found []string
		err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() && strings.HasPrefix(d.Name(), ".") {
				return filepath.SkipDir
			}
			if !d.IsDir() && strings.HasSuffix(path, ".lua") {
				found = append(found, path)
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
		sort.Strings(found)
		paths = append(paths, found...)
	}
	if len(paths) == 0 {
		return nil, fs.ErrNotExist
	}
	return paths, nil
}

// luaFile is one config file being scanned.
type luaFile struct {
	parser
	path, rel string
	src       string
	comments  map[int]string

	// mapHelper is set when the file defines a local map(mode, lhs, rhs,
	// desc) helper, as gitsigns' on_attach does. Elsewhere map is only a
	// parameter (telescope's attach_mappings), and its calls are skipped.
	mapHelper bool
}

func newLuaFile(dir, path, src string) *luaFile {
	toks, comments := lexLua(src)
	rel, err := filepath.Rel(dir, path)
	if err != nil {
		rel = path
	}
	f := &luaFile{parser: parser{toks: toks}, path: path, rel: rel, src: src, comments: comments}
	for i := range toks {
		if (f.is(i, "function") && f.is(i+1, "map") && f.is(i+2, "(")) ||
			(f.is(i, "local") && f.is(i+1, "map") && f.is(i+2, "=")) {
			f.mapHelper = true
		}
	}
	return f
}

// leader finds `vim.g.mapleader = "x"`.
func (f *luaFile) leader() (string, bool) {
	for i := range f.toks {
		if f.is(i, "mapleader") && f.is(i+1, "=") && f.tok(i+2).kind == tkString {
			return f.tok(i + 2).val, true
		}
	}
	return "", false
}

func (f *luaFile) stem() string {
	return strings.TrimSuffix(filepath.Base(f.path), ".lua")
}

// loopVar is a for loop over a literal list, whose variable the bindings in
// its body can use: `for _, char in ipairs({ "]", ")" }) do ... end`.
type loopVar struct {
	name   string
	values string // joined with spaces
	end    int    // token index past the loop's end
}

// scan walks the file's tokens once, picking up every binding. It keeps a
// stack of what each open bracket belongs to ("mappings", "i", a call's
// name...), which tells a mapping table's entries their mode.
func (f *luaFile) scan() []Entry {
	var (
		entries  []Entry
		descVars = map[string]string{} // opts.desc = "..." set before a call
		loops    []loopVar
		stack    []string
	)

	for i := 0; i < len(f.toks); {
		live := loops[:0]
		for _, l := range loops {
			if l.end > i {
				live = append(live, l)
			}
		}
		loops = live
		env := map[string]string{}
		for _, l := range loops {
			env[l.name] = l.values
		}

		switch {
		case f.is(i, "{") || f.is(i, "("):
			stack = append(stack, f.label(i))
			i++

		case f.is(i, "}") || f.is(i, ")"):
			if len(stack) > 0 {
				stack = stack[:len(stack)-1]
			}
			i++

		case f.keymapCall(i) > 0:
			var found []Entry
			found, i = f.parseKeymapCall(i, f.keymapCall(i), descVars, env)
			entries = append(entries, found...)

		case f.is(i, "keys") && f.is(i+1, "=") && f.is(i+2, "{"):
			var found []Entry
			found, i = f.parseLazyKeys(i+2, env)
			entries = append(entries, found...)

		case f.isMappingField(i, stack):
			var found []Entry
			found, i = f.parseMappingField(i, stack)
			entries = append(entries, found...)

		case f.tok(i).kind == tkName && f.is(i+1, ".") && f.is(i+2, "desc") && f.is(i+3, "=") && f.tok(i+4).kind == tkString:
			descVars[f.tok(i).text] = f.tok(i + 4).val
			i += 5

		case f.is(i, "for"):
			if l, ok := f.parseLoop(i); ok {
				loops = append(loops, l)
			}
			i++

		default:
			i++
		}
	}
	return entries
}

// label names what the bracket at i belongs to: the call it opens, or the
// field or variable the table is assigned to.
func (f *luaFile) label(i int) string {
	switch {
	case f.is(i, "("):
		return f.chainBefore(i)
	case f.is(i-1, "=") && f.tok(i-2).kind == tkName:
		return f.tok(i - 2).text
	case f.is(i-1, "=") && f.is(i-2, "]") && f.tok(i-3).kind == tkString:
		return f.tok(i - 3).val
	}
	return ""
}

// chainBefore returns the dotted name ending just before token i.
func (f *luaFile) chainBefore(i int) string {
	var parts []string
	for k := i - 1; f.tok(k).kind == tkName; k -= 2 {
		parts = append([]string{f.tok(k).text}, parts...)
		if !f.is(k-1, ".") && !f.is(k-1, ":") {
			break
		}
	}
	return strings.Join(parts, ".")
}

// keymapCall reports whether a call to vim.keymap.set (or the file's map
// helper) starts at token i, returning the index of its ( or 0.
func (f *luaFile) keymapCall(i int) int {
	if f.tok(i).kind != tkName || f.is(i-1, ".") || f.is(i-1, ":") || f.is(i-1, "function") {
		return 0
	}
	var parts []string
	k := i
	for {
		parts = append(parts, f.tok(k).text)
		if f.is(k+1, ".") && f.tok(k+2).kind == tkName {
			k += 2
			continue
		}
		break
	}
	if !f.is(k+1, "(") {
		return 0
	}
	chain := strings.Join(parts, ".")
	switch {
	case strings.HasSuffix(chain, "keymap.set"), strings.HasSuffix(chain, "nvim_set_keymap"):
		return k + 1
	case chain == "map" && f.mapHelper:
		return k + 1
	}
	return 0
}

// parseKeymapCall reads keymap.set(mode, lhs, rhs, opts) - or the map
// helper's map(mode, lhs, rhs, desc) - whose ( is at token open.
func (f *luaFile) parseKeymapCall(start, open int, descVars, env map[string]string) ([]Entry, int) {
	args, next := f.callArgs(open)
	if len(args) < 3 {
		return nil, next
	}
	lhs, ok := eval(args[1], env)
	if !ok || lhs == "" {
		return nil, next
	}
	modes := strings.Join(args[0].strs(), "")
	if modes == "" {
		modes = "n"
	}

	var desc, scope string
	if len(args) > 3 {
		switch opts := args[3]; opts.kind {
		case nStr:
			desc = opts.str
		case nTable:
			desc, _ = eval(opts.field("desc"), env)
			if opts.field("buffer") != nil {
				scope = scopes[f.stem()]
			}
		case nName:
			desc = descVars[opts.name]
		}
	}

	e := f.entry(lhs, modes, desc, args[2], f.tok(start).line)
	e.Scope = scope
	return []Entry{e}, next
}

// parseLazyKeys reads a lazy.nvim `keys = { ... }` spec whose { is at token
// i: a list of { lhs, rhs, mode = ..., desc = ..., ft = ... }. The named
// entries of snacks' window keys ({ name = { lhs, rhs, ... } }) read the same.
func (f *luaFile) parseLazyKeys(i int, env map[string]string) ([]Entry, int) {
	tbl, next := f.table(i)
	var entries []Entry
	for _, fl := range tbl.fields {
		spec := fl.value
		if spec == nil || spec.kind != nTable {
			continue
		}
		pos := spec.positional()
		// { "<leader>c", nil, desc = "..." } only names a group
		if len(pos) < 2 || pos[0].kind != nStr || pos[1].kind == nNil {
			continue
		}
		modes := strings.Join(spec.field("mode").strs(), "")
		if modes == "" {
			modes = "n"
		}
		desc, _ := eval(spec.field("desc"), env)
		e := f.entry(pos[0].str, modes, desc, pos[1], f.tok(spec.start).line)
		if ft := spec.field("ft").strs(); len(ft) > 0 {
			e.Scope = strings.Join(ft, ", ")
		} else if modes == "t" {
			e.Scope = "terminal"
		}
		entries = append(entries, e)
	}
	return entries, next
}

var keyLike = regexp.MustCompile(`^(<[^<>]+>|[^\s<>]{1,2})$`)

// isMappingField reports whether a `["<C-k>"] = action` entry of a mapping
// table (telescope's mappings, blink.cmp's keymap, oil's keymaps) starts at i.
func (f *luaFile) isMappingField(i int, stack []string) bool {
	if !f.is(i, "[") || f.tok(i+1).kind != tkString || !f.is(i+2, "]") || !f.is(i+3, "=") {
		return false
	}
	if !keyLike.MatchString(f.tok(i + 1).val) {
		return false
	}
	for _, label := range stack {
		if label == "mappings" || label == "keymap" || label == "keymaps" || label == "keys" || strings.Contains(label, "mapping") {
			return true
		}
	}
	return false
}

var modeLetter = regexp.MustCompile(`^[nvxsoict]$`)

// defaultModes is the mode of a file's mapping-table entries that say none.
var defaultModes = map[string]string{"blink-cmp": "i"}

func (f *luaFile) parseMappingField(i int, stack []string) ([]Entry, int) {
	lhs := f.tok(i + 1).val
	value, next := f.expr(i + 4)

	// the mode: the value's own ({ c = action }, { action, mode = "n" }),
	// else the table it sits in (mappings = { i = { ... } }, cmp's
	// preset.insert / preset.cmdline, blink.cmp's cmdline = { keymap = ... }),
	// else the file's own default (blink.cmp's keymap is insert mode)
	var modes string
	action := value
	if value.kind == nTable {
		for _, fl := range value.fields {
			if modeLetter.MatchString(fl.name) {
				modes += fl.name
				action = fl.value
			}
		}
		if m := value.field("mode").strs(); len(m) > 0 {
			modes = strings.Join(m, "")
		}
		if pos := value.positional(); len(pos) > 0 {
			action = pos[0]
		}
	}
	for k := len(stack) - 1; k >= 0 && modes == ""; k-- {
		switch label := stack[k]; {
		case modeLetter.MatchString(label):
			modes = label
		case strings.HasSuffix(label, "preset.insert"):
			modes = "i"
		case strings.HasSuffix(label, "preset.cmdline"), label == "cmdline":
			modes = "c"
		}
	}
	if modes == "" {
		modes = defaultModes[f.stem()]
	}
	if modes == "" {
		modes = "n"
	}

	line := f.tok(i).line
	desc := f.comments[line]
	if desc == "" {
		desc = f.comments[f.tok(next-1).line]
	}
	e := f.entry(lhs, modes, desc, action, line)
	if desc == "" {
		e.Desc, e.DescIsCode = humanize(e.Action), false
	}
	e.Scope = scopes[f.stem()]
	if e.Scope == "" {
		e.Scope = f.stem()
	}
	return []Entry{e}, next
}

// parseLoop reads `for _, v in ipairs({ "a", "b" }) do` at token i.
func (f *luaFile) parseLoop(i int) (loopVar, bool) {
	if f.tok(i+1).kind != tkName || !f.is(i+2, ",") || f.tok(i+3).kind != tkName || !f.is(i+4, "in") ||
		!(f.is(i+5, "ipairs") || f.is(i+5, "pairs")) || !f.is(i+6, "(") || !f.is(i+7, "{") {
		return loopVar{}, false
	}
	tbl, j := f.table(i + 7)
	values := tbl.strs()
	if len(values) == 0 || !f.is(j, ")") || !f.is(j+1, "do") {
		return loopVar{}, false
	}
	return loopVar{name: f.tok(i + 3).text, values: strings.Join(values, " "), end: f.skipBlock(j + 2)}, true
}

// entry builds a binding, falling back to its code for the description.
func (f *luaFile) entry(lhs, modes, desc string, rhs *node, line int) Entry {
	e := Entry{
		Keys:   lhs,
		Modes:  modes,
		Desc:   desc,
		Action: f.action(rhs),
		File:   f.rel,
		Path:   f.path,
		Line:   line,
	}
	if e.Desc == "" {
		e.Desc, e.DescIsCode = describeAction(rhs, e.Action), true
	}
	return e
}

// action returns a mapping's right-hand side as text: a string's value, a
// function's body, or the expression.
func (f *luaFile) action(rhs *node) string {
	if rhs == nil {
		return ""
	}
	switch rhs.kind {
	case nStr:
		return rhs.str
	case nFunc:
		// skip the parameter list: function(...) body end
		body := rhs.start + 1
		if f.is(body, "(") {
			body = f.skipBalanced(body)
		}
		return f.text(body, rhs.end-1)
	}
	return f.text(rhs.start, rhs.end)
}

var cmdRHS = regexp.MustCompile(`(?i)^(?:<cmd>|:)(.*?)(?:<cr>)?$`)

// describeAction stands in for a missing description: `<cmd>qa<cr>`
// reads ":qa", a function its body.
func describeAction(rhs *node, action string) string {
	if rhs != nil && rhs.kind == nStr {
		if m := cmdRHS.FindStringSubmatch(action); m != nil && !strings.Contains(m[1], "<") {
			return ":" + m[1]
		}
	}
	return action
}

var (
	callArgsRe = regexp.MustCompile(`\(([^()]*)\)`)
	noiseWords = map[string]bool{"actions": true, "custom_actions": true, "cmp": true, "mapping": true, "preset": true}
)

// humanize turns a plugin action into words:
// cmp.mapping.select_prev_item() reads "select prev item".
func humanize(action string) string {
	action = callArgsRe.ReplaceAllStringFunc(action, func(m string) string {
		inner := strings.TrimSpace(m[1 : len(m)-1])
		if inner == "" || strings.ContainsAny(inner, "{}=") {
			return ""
		}
		return " (" + inner + ")"
	})
	var words []string
	for _, w := range strings.FieldsFunc(action, func(r rune) bool { return r == '.' || r == ' ' || r == '"' }) {
		if !noiseWords[w] {
			words = append(words, strings.ReplaceAll(w, "_", " "))
		}
	}
	return strings.Join(words, " ")
}

// pluginDefaults adds the bindings a plugin makes without any config, for
// the plugins the config installs.
func pluginDefaults(files []*luaFile, leader string) []Entry {
	var entries []Entry
	for _, f := range files {
		for i, t := range f.toks {
			if t.kind == tkString && t.val == "dlyongemallo/diffview-plus.nvim" {
				for _, d := range diffviewDefaults {
					entries = append(entries, Entry{
						Keys:     d.keys,
						Display:  prettyVimKeys(d.keys, leader),
						Modes:    "n",
						Desc:     d.desc,
						Note:     "keys of the diffview tab",
						Action:   d.action,
						Scope:    "diff view",
						Category: Git,
						File:     f.rel,
						Path:     f.path,
						Line:     f.toks[i].line,
					})
				}
			}
			if t.kind == tkString && t.val == "christoomey/vim-tmux-navigator" {
				keys := "<C-h> <C-j> <C-k> <C-l>"
				entries = append(entries, Entry{
					Keys:     keys,
					Display:  prettyVimKeys(keys, leader),
					Modes:    "n",
					Desc:     "Move to the split or tmux pane left / down / up / right",
					Note:     "vim-tmux-navigator's default keys, the same in nvim and tmux",
					Action:   "TmuxNavigateLeft / Down / Up / Right",
					Category: Navigation,
					File:     f.rel,
					Path:     f.path,
					Line:     f.toks[i].line,
				})
			}
		}
	}
	return entries
}

// diffviewDefaults are the keys of a diffview tab (`git diff dev`, <leader>gv):
// diffview's own, and the q that diffview.lua sets through a shared local
var diffviewDefaults = []struct{ keys, desc, action string }{
	{"<Tab> <S-Tab>", "Diff view: next / previous file", "select_next_entry / select_prev_entry"},
	{"]c [c", "Diff view: next / previous change", "]c / [c (vim diff mode)"},
	{"q", "Diff view: close (quits nvim when opened by `git diff dev`)", "DiffviewClose"},
}
