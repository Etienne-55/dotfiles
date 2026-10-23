package keymaps

import (
	"path/filepath"
	"regexp"
)

// rule puts the bindings matching all of its patterns in a category. The
// first matching rule wins; a binding no rule takes goes to UI.
type rule struct {
	file, lhs, desc *regexp.Regexp // file matches the base name
	cat             Category
}

func re(s string) *regexp.Regexp { return regexp.MustCompile(s) }

var rules = []rule{
	// git lives in several plugins: telescope's pickers, snacks' lazygit
	{lhs: re(`(?i)^<leader>(g|h)`), cat: Git},
	{desc: re(`(?i)diagnostic`), cat: Diagnostics},

	{file: re(`^telescope\.lua$`), cat: Telescope},
	{file: re(`^(gitsigns|diffview)\.lua$`), cat: Git},
	{file: re(`^(lspconfig|mason)\.lua$`), cat: LSP},
	{file: re(`^trouble\.lua$`), cat: Diagnostics},
	{file: re(`^claudecode\.lua$`), cat: Claude},
	{file: re(`^(recent|flash|oil|nvim-tree|todo-comments)\.lua$`), cat: Navigation},
	{file: re(`^blink-cmp\.lua$`), cat: Completion},
	{file: re(`^(surround|formatting|treesitter|undotree|autopairs|autotag|quicker)\.lua$`), cat: Editing},
	{file: re(`^snacks\.lua$`), desc: re(`(?i)^rename`), cat: Editing},
	{desc: re(`(?i)^replace`), cat: Editing},

	// init.lua's scrolling and centred search
	{lhs: re(`^(<[MmAa]-(Up|Down)>|[nN]|<[Cc]-[udfb]>)$`), cat: Navigation},
}

func categorize(e Entry) Category {
	base := filepath.Base(e.File)
	for _, r := range rules {
		if (r.file == nil || r.file.MatchString(base)) &&
			(r.lhs == nil || r.lhs.MatchString(e.Keys)) &&
			(r.desc == nil || r.desc.MatchString(e.Desc)) {
			return r.cat
		}
	}
	return UI
}
