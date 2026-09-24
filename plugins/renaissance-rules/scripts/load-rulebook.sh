#!/bin/sh
# Renaissance rules plugin, layer 1 of 3: load the company rulebook into Claude.
#
# Runs at the start of every chat, and again after /clear, on resume, and whenever a long chat is
# compressed, so the rules never drop out of Claude's view.
#
# Reads the LATEST rulebook from GitHub (gives up after 3 seconds). If GitHub can't be reached, it
# uses the last copy fetched on this machine, and if there is none, the copy that shipped with the
# plugin. It always tells Claude which copy it is using, and whether the hard checks work here.
#
# Plain POSIX sh plus curl: runs on macOS, Linux, and Windows through Git Bash. It never blocks
# anything and always exits 0.
#
# CREATED BY CLAUDE for david-Claude Code, 2026-09-24.

URL="${RR_RULEBOOK_URL:-https://raw.githubusercontent.com/RenaissanceGrowth/renaissance-claude-rules/main/plugins/renaissance-rules/RULEBOOK.md}"
ROOT=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)
BUNDLED="$ROOT/RULEBOOK.md"
CACHE_DIR="${RR_CACHE_DIR:-${HOME:-.}/.claude/renaissance-rules}"
CACHE="$CACHE_DIR/RULEBOOK.md"
MARK="RENAISSANCE RULEBOOK"

cat >/dev/null 2>&1   # the hook input is not needed here

fresh=""
if command -v curl >/dev/null 2>&1; then
  fresh=$(curl -fsSL --max-time 3 "$URL" 2>/dev/null)
fi

case "$fresh" in
  *"$MARK"*)
    # Keep this copy as the last-known-good version for when GitHub can't be reached.
    mkdir -p "$CACHE_DIR" 2>/dev/null \
      && printf '%s\n' "$fresh" > "$CACHE.tmp" 2>/dev/null \
      && mv -f "$CACHE.tmp" "$CACHE" 2>/dev/null
    src="read live from GitHub at the start of this chat"
    body=$fresh ;;
  *)
    if [ -s "$CACHE" ] && grep -q "$MARK" "$CACHE" 2>/dev/null; then
      src="GitHub could not be reached, so this is the last copy fetched on this machine"
      body=$(cat "$CACHE")
    elif [ -s "$BUNDLED" ]; then
      src="GitHub could not be reached, so this is the copy that shipped with the plugin"
      body=$(cat "$BUNDLED")
    else
      echo "[Renaissance rules plugin: the company rulebook could not be loaded on this machine. Tell the user this once, in plain words.]"
      exit 0
    fi ;;
esac

# Self-test: feed the hard-check script an action it must block. If it doesn't, say so.
selftest=$(printf '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}' | sh "$ROOT/scripts/check.sh" 2>/dev/null)
case "$selftest" in
  *'"deny"'*) checks="Hard checks: on." ;;
  *) checks="Hard checks: NOT WORKING on this machine. Tell the user this once, in plain words." ;;
esac

printf '[Renaissance company rulebook: %s. %s]\n\n%s\n' "$src" "$checks" "$body"
exit 0
