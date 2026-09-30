#!/bin/sh
# Unit tests for the plugin's two scripts: the rulebook loader and the reminders.
# Needs only sh, grep, sed, tr, awk and curl. Uses a throwaway home folder, so it never touches yours.
#
#     sh tests/run-tests.sh
#
# CREATED BY CLAUDE for david-Claude Code, 2026-09-24; trimmed 2026-09-30 when the hard checks were removed.
HERE=$(cd "$(dirname "$0")" && pwd)
S="$HERE/../plugins/renaissance-rules/scripts"
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t rrtest)
HOME="$TMP/home"; export HOME; mkdir -p "$HOME"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL  %s\n        got: %s\n' "$1" "$(printf '%s' "$2" | head -c 240)"; }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "$2" ;; esac; }
lacks() { case "$2" in *"$3"*) bad "$1" "$2" ;; *) ok "$1" ;; esac; }
none()  { if [ -z "$2" ]; then ok "$1"; else bad "$1" "$2"; fi; }
prompt_in() { printf '{"session_id":"%s","cwd":"/Users/x/asana-exports","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "${2:-}" "$1"; }
rem() { sh "$S/remind.sh"; }
# a file:// URL that curl accepts on macOS, Linux AND Windows (Git Bash paths must become C:/... for native curl)
furl() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) printf 'file:///%s' "$(cygpath -m "$1")" ;; *) printf 'file://%s' "$1" ;; esac; }

echo "the plugin has no blocking check any more"
none  "no PreToolUse hook is declared"      "$(grep -c PreToolUse "$HERE/../plugins/renaissance-rules/hooks/hooks.json" | grep -v '^0$')"
none  "no check script ships"               "$(ls "$S" | grep -i check)"

echo "remind.sh"
has   "Asana request gets R1"               "$(prompt_in 'please create an Asana task for the renewal' | rem)" '[R1]'
none  "campaign request gets nothing"       "$(prompt_in 'launch the new MCA campaign' | rem)"
none  "Slack request gets nothing"          "$(prompt_in 'post in Slack that the launch is done' | rem)"
none  "bulk-change wording gets nothing (a suggestion, not a rule)" "$(prompt_in 'change the daily limit on all inboxes' | rem)"
none  "unrelated request gets nothing"      "$(prompt_in 'what is 2 plus 2' | rem)"
none  "folder name alone never triggers"    "$(prompt_in 'hello there' | rem)"
none  "garbage input, no crash"             "$(printf 'garbage' | rem)"
echo "remind.sh: forgiving matching (a test rulebook with a two-word trigger)"
mkdir -p "$HOME/.claude/renaissance-rules"
printf 'RENAISSANCE RULEBOOK\nVersion: TEST\n\n[R1] Asana test rule.\nWhy: test.\nRemind when a request mentions: asana\n\n[R2] Never delete inboxes without an OK.\nWhy: test.\nRemind when a request mentions: delete inbox, remove mailbox\n' > "$HOME/.claude/renaissance-rules/RULEBOOK.md"
has   "plural and a number in between"       "$(prompt_in 'please delete 300 inboxes in that workspace' m1 | rem)" '[R2]'
has   "-ing form, words apart"               "$(prompt_in 'we are deleting all the old inboxes today' m2 | rem)" '[R2]'
has   "past tense, other order"              "$(prompt_in 'which inboxes got deleted yesterday' m3 | rem)" '[R2]'
has   "second trigger, plural"               "$(prompt_in 'remove these mailboxes' m4 | rem)" '[R2]'
none  "one word of two is not enough"        "$(prompt_in 'check my inbox folder' m5 | rem)"
none  "unrelated request still quiet"        "$(prompt_in 'what is 2 plus 2' m6 | rem)"
has   "single-word trigger unchanged"        "$(prompt_in 'open Asana' m7 | rem)" '[R1]'
rm -f "$HOME/.claude/renaissance-rules/RULEBOOK.md"
echo "remind.sh: the same rule at most once every 20 requests in a chat"
has   "1st Asana request in a chat: R1"     "$(prompt_in 'asana one' chatA | rem)" '[R1]'
none  "2nd Asana request, same chat: quiet" "$(prompt_in 'asana two' chatA | rem)"
i=3; while [ $i -le 20 ]; do prompt_in "unrelated $i" chatA | rem >/dev/null; i=$((i+1)); done
has   "21st request in that chat: R1 again" "$(prompt_in 'asana again' chatA | rem)" '[R1]'
has   "a new chat gets R1 right away"       "$(prompt_in 'asana' chatB | rem)" '[R1]'

echo "load-rulebook.sh"
LIVE="$TMP/live.md"; printf 'RENAISSANCE RULEBOOK\nVersion: LIVE-TEST\n' > "$LIVE"
out=$(RR_RULEBOOK_URL="$(furl "$LIVE")" sh "$S/load-rulebook.sh" </dev/null)
has   "reachable: uses the live copy"       "$out" 'Version: LIVE-TEST'
has   "reachable: says it is live"          "$out" 'read live from GitHub'
lacks "no mention of hard checks any more"  "$out" 'Hard checks'
# The live test copy holds no [R] rules, so reminders drawn from it must be empty: proves they read the latest copy.
none  "reminders read the latest fetched copy" "$(prompt_in 'asana please' chatC | rem)"
out=$(RR_RULEBOOK_URL="$(furl "$TMP/missing.md")" sh "$S/load-rulebook.sh" </dev/null)
has   "unreachable: uses last fetched"      "$out" 'Version: LIVE-TEST'
has   "unreachable: says so"                "$out" 'last copy fetched on this machine'
rm -f "$HOME/.claude/renaissance-rules/RULEBOOK.md"
out=$(RR_RULEBOOK_URL="$(furl "$TMP/missing.md")" sh "$S/load-rulebook.sh" </dev/null)
has   "no cache: uses shipped copy"         "$out" 'copy that shipped with the plugin'
has   "no cache: shipped copy has R1"       "$out" '[R1]'
has   "no cache: shipped copy has the suggestions" "$out" 'SUGGESTIONS'
printf '<html>404 Not Found</html>\n' > "$TMP/bad.md"
out=$(RR_RULEBOOK_URL="$(furl "$TMP/bad.md")" sh "$S/load-rulebook.sh" </dev/null)
lacks "a page without the marker is never loaded" "$out" '404 Not Found'
has   "and the shipped copy is used instead"      "$out" '[R1]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
