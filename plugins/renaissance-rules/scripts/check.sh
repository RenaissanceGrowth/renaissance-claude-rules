#!/bin/sh
# Renaissance rules plugin, layer 3 of 3: the few hard checks.
#
# Only rules that are expensive to break AND visible in the action itself belong here; everything else
# lives in RULEBOOK.md. The messages are fixed in this file on purpose: they are never taken from the
# rulebook, so editing the rulebook can never put words into a block message.
#
#   R4  printing a saved password or a .env file into the chat   -> blocked (shell commands and file reads)
#   R3  sending a Slack message through a Slack connector         -> the person must approve it first
#
# Tuned against 30 days of real work (tests/replay.py). It judges only what a command itself prints:
#   - only the command's first line, never script text written below it (heredoc bodies);
#   - never a command whose output goes into a file or is thrown away (> file, >/dev/null);
#   - never example files (.env.example, .env.sample, .env.template).
# Slack sends made by scripts can't be seen reliably from the command text, so they are left to the
# rulebook (R3) rather than guessed at here.
#
# Plain POSIX sh plus grep, sed, tr and awk. If the input is unexpected it lets the action through, and
# the session-start self-test in load-rulebook.sh reports when these checks are not working. Exits 0.
#
# CREATED BY CLAUDE for david-Claude Code, 2026-09-24.

input=$(cat 2>/dev/null)
tool=$(printf '%s' "$input" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/.*:[[:space:]]*"\([^"]*\)"$/\1/')
field() { printf '%s' "$input" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" | head -n 1; }

decide() {  # $1 = deny | ask, $2 = fixed message (never contains double quotes or backslashes)
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$2"
  exit 0
}
ENV_MSG="Renaissance rule R4: this would show a .env file, which holds keys and passwords, in the chat. Read the value you need inside a script without printing it."
KEY_MSG="Renaissance rule R4: this command would print a saved password or key into the chat. Point to the 1Password item by its name instead, or read the value inside a script without printing it."
SLACK_MSG="Renaissance rule R3: this sends a Slack message. A person approves the exact text of every message before it goes out."

case "$tool" in
  Bash)
    # First line of the command only; turn JSON-escaped quotes back into quotes.
    first=$(field command | sed -e 's/^"command"[[:space:]]*:[[:space:]]*"//' -e 's/"$//' -e 's/\\n.*$//' -e 's/\\"/"/g')
    verdict=$(printf '%s\n' "$first" | tr ';&|' '\n\n\n' | awk '
      { seg = $0; sub(/^[ \t(]+/, "", seg); if (seg == "") next
        n = split(seg, t, /[ \t]+/)
        for (i = 2; i <= n; i++) if (t[i] ~ /^(1?>|>>|&>)/) next      # output goes to a file: not printed
        if (t[1] ~ /^(cat|head|tail|less|more|bat)$/) {
          for (i = 2; i <= n; i++) {
            tok = t[i]; gsub(/["\047\\]/, "", tok)
            if (tok ~ /\.env\.(example|sample|template)$/) continue
            if (tok ~ /(^|\/)\.env(\.[A-Za-z0-9_.-]+)?$/ || tok ~ /[^\/]\.env$/) { print "ENV"; exit }
          }
        }
        if (t[1] == "security" && t[2] ~ /^find-(generic|internet)-password$/)
          for (i = 3; i <= n; i++) { f = t[i]; gsub(/["\047]/, "", f); if (f ~ /^-[A-Za-z]*[wg][A-Za-z]*$/) { print "KEY"; exit } }
      }')
    case "$verdict" in
      ENV) decide deny "$ENV_MSG" ;;
      KEY) decide deny "$KEY_MSG" ;;
    esac
    ;;
  Read)
    fp=$(field file_path)
    if printf '%s' "$fp" | grep -Eq '((/|")\.env(\.[A-Za-z0-9_.-]+)?|[^/"]\.env)"$' \
       && ! printf '%s' "$fp" | grep -Eq '\.env\.(example|sample|template)"$'; then
      decide deny "$ENV_MSG"
    fi
    ;;
  mcp__*[Ss]lack*)
    case "$tool" in
      *[Dd]raft*) ;;
      *[Ss]end*|*[Pp]ost*|*[Ss]chedule*|*[Rr]eply*) decide ask "$SLACK_MSG" ;;
    esac
    ;;
esac
exit 0
