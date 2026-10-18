package keymaps

import (
	"path/filepath"
	"testing"
)

const fixture = "../../testdata/dotfiles/nvim"

// find returns the entry bound to keys (as written in the config) in modes.
func find(t *testing.T, entries []Entry, keys, modes string) Entry {
	t.Helper()
	for _, e := range entries {
		if e.Keys == keys && e.Modes == modes {
			return e
		}
	}
	t.Fatalf("no binding %q (%s) in %d entries", keys, modes, len(entries))
	return Entry{}
}

func TestParseNvim(t *testing.T) {
	entries, err := ParseNvim(fixture)
	if err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		name, keys, modes string
		want              Entry
	}{
		{"no desc: the rhs stands in", "<M-Up>", "n",
			Entry{Display: "⌥↑", Desc: "<C-u>zz", DescIsCode: true, Category: Navigation}},
		{"function rhs, desc in opts", "<leader>zz", "n",
			Entry{Display: "␣zz", Desc: "Toggle Zen Mode", Action: `require("zen-mode").toggle()`, Category: UI}},
		{"telescope mapping with a trailing comment", "<C-k>", "i",
			Entry{Display: "⌃k", Desc: "move to prev result", Scope: "picker", Category: Telescope}},
		{"telescope mapping without one", "<C-q>", "i",
			Entry{Display: "⌃q", Desc: "send selected to qflist", Scope: "picker", Category: Telescope}},
		{"git keys outside gitsigns", "<leader>gd", "n",
			Entry{Display: "␣gd", Desc: "Changed files", Category: Git}},
		{"gitsigns' map helper", "ih", "ox",
			Entry{Display: "ih", Desc: "Select hunk", Category: Git}},
		{"opts.desc set before the call", "gD", "n",
			Entry{Display: "gD", Desc: "Go to declaration", Category: LSP}},
		{"diagnostics wherever they are", "]d", "n",
			Entry{Display: "]d", Desc: "Go to next diagnostic", Category: Diagnostics}},
		{"lazy keys, mode before the function", "z", "nxo",
			Entry{Display: "z", Desc: "Flash", Category: Navigation}},
		{"lazy keys over several lines, with ft", "<leader>mr", "n",
			Entry{Display: "␣mr", Desc: "Toggle markdown rendering", Scope: "markdown", Category: UI}},
		{"a loop over a literal list", `<leader>) "`, "n",
			Entry{Display: `␣) "`, Desc: `Wrap word in ) "`, Category: Editing}},
		{"plugin defaults", "<C-h> <C-j> <C-k> <C-l>", "n",
			Entry{Display: "⌃h ⌃j ⌃k ⌃l", Category: Navigation}},
		{"diffview tab keys", "<Tab> <S-Tab>", "n",
			Entry{Display: "⇥ ⇧⇥", Desc: "Diff view: next / previous file", Scope: "diff view", Category: Git}},
		{"blink keymap, insert mode, trailing comment", "<C-j>", "i",
			Entry{Display: "⌃j", Desc: "next suggestion", Scope: "completion menu", Category: Completion}},
		{"blink keymap without a comment", "<C-e>", "i",
			Entry{Display: "⌃e", Desc: "hide", Scope: "completion menu", Category: Completion}},
		{"blink cmdline keymap", "<Down>", "c",
			Entry{Display: "↓", Desc: "select next", Scope: "completion menu", Category: Completion}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := find(t, entries, tt.keys, tt.modes)
			if got.Display != tt.want.Display {
				t.Errorf("display %q, want %q", got.Display, tt.want.Display)
			}
			if tt.want.Desc != "" && got.Desc != tt.want.Desc {
				t.Errorf("desc %q, want %q", got.Desc, tt.want.Desc)
			}
			if got.DescIsCode != tt.want.DescIsCode {
				t.Errorf("desc is code %v, want %v", got.DescIsCode, tt.want.DescIsCode)
			}
			if tt.want.Action != "" && got.Action != tt.want.Action {
				t.Errorf("action %q, want %q", got.Action, tt.want.Action)
			}
			if got.Scope != tt.want.Scope {
				t.Errorf("scope %q, want %q", got.Scope, tt.want.Scope)
			}
			if got.Category != tt.want.Category {
				t.Errorf("category %v, want %v", got.Category, tt.want.Category)
			}
		})
	}

	for _, e := range entries {
		if e.Keys == "<leader>c" {
			t.Errorf("a lazy group label was read as a binding: %+v", e)
		}
		if e.Keys == "l" {
			t.Errorf("the map helper's own body was read as a binding: %+v", e)
		}
	}
	if e := find(t, entries, "<leader>ff", "n"); e.File != filepath.Join("lua", "me", "plugins", "telescope.lua") || e.Line != 15 {
		t.Errorf("location %s:%d", e.File, e.Line)
	}
}

func TestParseTmux(t *testing.T) {
	entries, err := ParseTmux(filepath.Join(fixture, "../tmux/tmux.conf"), "tmux.conf")
	if err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		keys, display, desc, note, scope string
	}{
		{"C-b h", "⌃b h", "Go to the pane left", "", ""},
		{"v", "v", `start selecting text with "v"`, "", "copy mode"},
		// the comment sits above an unbind of the same key
		{"C-b t", "⌃b t", "nyancat in a new window (replaces the default clock-mode)",
			"nyancat in a new window (replaces the default clock-mode); press ctrl-c to quit", ""},
		// continued over three lines; commented-out code isn't its description
		{"C-b p", "⌃b p", "", "", ""},
	}
	if len(entries) != len(tests) {
		t.Fatalf("%d entries, want %d: %+v", len(entries), len(tests), entries)
	}
	for i, tt := range tests {
		e := entries[i]
		if e.Keys != tt.keys || e.Display != tt.display || e.Scope != tt.scope {
			t.Errorf("entry %d: %q %q %q, want %q %q %q", i, e.Keys, e.Display, e.Scope, tt.keys, tt.display, tt.scope)
		}
		if tt.desc != "" && (e.Desc != tt.desc || e.Note != tt.note) {
			t.Errorf("%s: desc %q note %q, want %q %q", tt.keys, e.Desc, e.Note, tt.desc, tt.note)
		}
	}
	if p := entries[3]; p.Action != `if-shell -F '#{==:#{session_name},chat}' 'detach-client' 'display-popup -E "claude"'` {
		t.Errorf("continued command: %q", p.Action)
	}
}

func TestParseShell(t *testing.T) {
	entries, err := ParseShell(filepath.Join(fixture, "../zsh/zshrc"), "zshrc")
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 2 {
		t.Fatalf("%d entries: %+v", len(entries), entries)
	}
	if e := entries[0]; e.Keys != "lg" || e.Desc != "lazygit" || !e.DescIsCode {
		t.Errorf("lg: %+v", e)
	}
	if e := entries[1]; e.Keys != "ff" || e.Desc != "fuzzy find files in cwd (same as <space>ff in nvim)" ||
		e.Action != `nvim "+Pick find_files"` {
		t.Errorf("ff: %+v", e)
	}
}

func TestPrettyVimKeys(t *testing.T) {
	for lhs, want := range map[string]string{
		"<leader>ff": "␣ff",
		"<C-S-P>":    "⌃⇧P",
		"<c-s>":      "⌃s",
		"<C-Space>":  "⌃␣",
		"<M-Down>":   "⌥↓",
		"<CR>":       "⏎",
		"<bs>":       "⌫",
		"<C-\\>":     "⌃\\",
		"]h":         "]h",
		"<Plug>(x)":  "<Plug>(x)",
		"a<b":        "a<b",
	} {
		if got := prettyVimKeys(lhs, " "); got != want {
			t.Errorf("%q: %q, want %q", lhs, got, want)
		}
	}
}
