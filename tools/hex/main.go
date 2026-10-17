package main

import (
	"flag"
	"fmt"
	"os"

	"hex/internal/app"
)

func main() {
	popup := flag.Bool("popup", false, "run inside a tmux popup: drop Hex's own frame for the popup's")
	config := flag.String("config", "", "neovim config to read (default: the dotfiles repo this binary is in, else ~/.config/nvim)")
	list := flag.Bool("list", false, "print every binding and exit")
	flag.Parse()

	dir := app.ConfigDir(*config)
	run := func() error { return app.Run(dir, *popup) }
	if *list {
		run = func() error { return app.List(os.Stdout, dir) }
	}
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}
