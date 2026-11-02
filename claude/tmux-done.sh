#!/usr/bin/env bash
# Claude Stop hook: flags this claude's tmux window (@claude_done) so the bar shows a claude icon
# after its name; tmux.conf clears it when you switch to that window. Works for claude inside nvim
# too (the terminal inherits TMUX_PANE). Skipped when you're already looking at the window.
[ -n "$TMUX_PANE" ] || exit 0
[ "$(tmux display -p -t "$TMUX_PANE" '#{&&:#{window_active},#{session_attached}}')" = 1 ] && exit 0
tmux set -w -t "$TMUX_PANE" @claude_done 1
tmux refresh-client -S 2>/dev/null
exit 0
