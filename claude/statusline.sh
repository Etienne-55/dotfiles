#!/usr/bin/env bash
# Claude Code status line (statusLine in settings.json): effort and plan usage (the 5-hour
# window), in the Neon colors (nvim/lua/eti/core/palette.lua). Claude Code
# pipes the session as JSON on stdin; a field it doesn't send yet is skipped.
input=$(cat)

rgb() { printf '\033[38;2;%d;%d;%dm' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"; }
dim=$(rgb "#6B5A8E") reset=$'\033[0m'

# green under 50%, yellow under 80%, red above
pct() {
  local n=${1%.*} color="#6FE0B0"
  ((n >= 50)) && color="#E8D287"
  ((n >= 80)) && color="#E8668E"
  printf '%s%s %s%d%%%s' "$dim" "$2" "$(rgb "$color")" "$n" "$reset"
}

# | separated: read collapses repeated tabs, which would shift the fields after an empty one
IFS='|' read -r effort five < <(jq -r '[
  .effort.level // "",
  .rate_limits.five_hour.used_percentage // ""
] | map(tostring) | join("|")' <<<"$input")

parts=()
[[ -n $effort ]] && parts+=("${dim}effort $(rgb "#A884E8")$effort$reset")
[[ -n $five ]] && parts+=("$(pct "$five" 5h)")

sep="$(rgb "#5A4A78") │ $reset"
out=""
for part in "${parts[@]}"; do
  out+=${out:+$sep}$part
done
printf '%s' "$out"
