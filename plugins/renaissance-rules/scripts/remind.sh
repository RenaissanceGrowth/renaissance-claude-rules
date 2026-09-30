#!/bin/sh
# Renaissance rules plugin, layer 2 of 2: reminders.
#
# When the user's request touches a rule's topic, repeat that rule right then, so it is fresh in
# Claude's view at the moment it matters. The trigger words sit next to each rule in RULEBOOK.md
# ("Remind when a request mentions: ..."), so the rulebook stays the only file anyone edits.
#
# Matching is forgiving on purpose: a trigger like "delete inbox" fires when the request contains
# both words in any order and in any form (deleting, deleted, inboxes), so a rule needs one or two
# plain triggers, not a list of phrasings. Words are compared by a crude stem (delete/deleting/
# deleted -> delet; inbox/inboxes -> inbox).
#
# The same rule is repeated at most once every 20 requests in a chat. The full rulebook is also
# reloaded whenever a long chat is compressed. Uses the latest rulebook fetched on this machine
# (see load-rulebook.sh), else the copy shipped with the plugin. Blocks nothing.
# Plain POSIX sh plus grep, sed and awk. Always exits 0.
#
# CREATED BY CLAUDE for david-Claude Code, 2026-09-24; matching by stems added 2026-09-30.

GAP=20
ROOT=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)
CACHE_DIR="${RR_CACHE_DIR:-${HOME:-.}/.claude/renaissance-rules}"
CACHE="$CACHE_DIR/RULEBOOK.md"
BOOK="$ROOT/RULEBOOK.md"
if [ -s "$CACHE" ] && grep -q "RENAISSANCE RULEBOOK" "$CACHE" 2>/dev/null; then BOOK="$CACHE"; fi
[ -s "$BOOK" ] || exit 0

input=$(cat 2>/dev/null)
# Only the user's request counts, never the rest of the hook input (folder names, file paths).
request=$(printf '%s' "$input" | grep -oE '"prompt"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -n 1)
[ -n "$request" ] || exit 0

# Per-chat memory of which rule was repeated when, so the same rule isn't repeated every request.
sid=$(printf '%s' "$input" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/' | tr -cd 'A-Za-z0-9_-')
count=1; prev=""; state=""
if [ -n "$sid" ]; then
  mkdir -p "$CACHE_DIR/chats" 2>/dev/null
  state="$CACHE_DIR/chats/$sid"
  if [ -s "$state" ]; then
    n=$(sed -n 's/^n=//p' "$state" | head -n 1); count=$(( ${n:-0} + 1 ))
    prev=$(sed -n 's/^last=//p' "$state" | head -n 1)
  fi
  find "$CACHE_DIR/chats" -type f -mtime +7 -exec rm -f {} \; 2>/dev/null   # forget chats older than a week
fi

out=$(REQ="$request" PREV="$prev" COUNT="$count" GAP="$GAP" awk '
  function stem(w) {
    if (length(w) > 5 && w ~ /ing$/) w = substr(w, 1, length(w) - 3)
    else if (length(w) > 4 && w ~ /(ed|es)$/) w = substr(w, 1, length(w) - 2)
    else if (length(w) > 3 && w ~ /s$/) w = substr(w, 1, length(w) - 1)
    if (length(w) > 4 && w ~ /e$/) w = substr(w, 1, length(w) - 1)
    return w
  }
  BEGIN {
    RS = ""; count = ENVIRON["COUNT"] + 0; gap = ENVIRON["GAP"] + 0
    req = tolower(ENVIRON["REQ"]); gsub(/[^a-z0-9]+/, " ", req)
    n = split(req, tok, " "); for (i = 1; i <= n; i++) if (tok[i] != "") have[stem(tok[i])] = 1
    np = split(ENVIRON["PREV"], pv, ",")
    for (k = 1; k <= np; k++) { split(pv[k], kv, ":"); if (kv[1] != "") last[kv[1]] = kv[2] + 0 }
  }
  /^\[R[0-9]+\]/ {
    id = $0; sub(/\].*/, "", id); sub(/^\[/, "", id)
    nl = split($0, lines, "\n"); words = ""
    for (i = 1; i <= nl; i++)
      if (tolower(lines[i]) ~ /^remind when a request mentions:/) { words = lines[i]; sub(/^[^:]*:/, "", words) }
    if (words == "") next
    m = split(tolower(words), trig, ",")
    for (j = 1; j <= m; j++) {
      t = trig[j]; gsub(/[^a-z0-9]+/, " ", t); nw = split(t, tw, " "); hit = 0; need = 0
      for (x = 1; x <= nw; x++) if (tw[x] != "") { need++; if (stem(tw[x]) in have) hit++ }
      if (need > 0 && hit == need) {
        if (!(id in last) || count - last[id] >= gap) { print $0; print ""; last[id] = count }
        break
      }
    }
  }
  END { s = ""; for (k in last) s = s (s == "" ? "" : ",") k ":" last[k]; print "##STATE##" s }' "$BOOK" 2>/dev/null)

if [ -n "$state" ]; then
  printf 'n=%s\nlast=%s\n' "$count" "$(printf '%s\n' "$out" | sed -n 's/^##STATE##//p')" > "$state" 2>/dev/null
fi
hits=$(printf '%s\n' "$out" | sed '/^##STATE##/d')
if [ -n "$(printf '%s' "$hits" | tr -d '[:space:]')" ]; then
  printf '[Renaissance company rules that apply to this request]\n\n%s\n' "$hits"
fi
exit 0
