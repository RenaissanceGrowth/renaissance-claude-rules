#!/bin/sh
# Unit tests for the plugin's three scripts: what each must catch, and what each must never block.
# The "must never block" cases include every false alarm found by replaying 30 days of real work
# (tests/replay.py), so a later change that brings one back fails here first.
# Needs only sh, grep, sed, tr, awk and curl. Uses a throwaway home folder, so it never touches yours.
# The commands below are only TEXT fed to the checks; none of them is ever run.
#
#     sh tests/run-tests.sh
#
# CREATED BY CLAUDE for david-Claude Code, 2026-09-24.
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

# Commands are passed exactly as they appear inside the JSON Claude Code sends: \n and \" stay escaped.
bash_in()   { printf '{"session_id":"t","cwd":"/tmp/slack-domains/.env-dir","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"x"}}' "$1"; }
tool_in()   { printf '{"session_id":"t","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"text":"hello"}}' "$1"; }
read_in()   { printf '{"tool_name":"Read","tool_input":{"file_path":"%s"}}' "$1"; }
prompt_in() { printf '{"session_id":"%s","cwd":"/Users/x/slack-exports","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "${2:-}" "$1"; }
chk() { sh "$S/check.sh"; }
rem() { sh "$S/remind.sh"; }
KC="security find-generic-password"
furl() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) printf 'file:///%s' "$(cygpath -m "$1")" ;; *) printf 'file://%s' "$1" ;; esac; }

echo "check.sh: must catch"
has  "keychain print with -w"              "$(bash_in "$KC -s svc -w" | chk)" '"deny"'
has  "keychain print with -g"              "$(bash_in "$KC -g -s svc" | chk)" '"deny"'
has  "keychain print in a command chain"   "$(bash_in "echo keys; $KC -s svc -w" | chk)" '"deny"'
has  "cat .env"                            "$(bash_in 'cat .env' | chk)" '"deny"'
has  "cat .env with errors hidden"         "$(bash_in 'cat .env 2>/dev/null' | chk)" '"deny"'
has  "tail of .env.local"                  "$(bash_in 'tail -n 5 config/.env.local' | chk)" '"deny"'
has  "cat of a quoted path to .env"        "$(bash_in 'cat \"$HOME/project/.env\"' | chk)" '"deny"'
has  "cat of a named env file"             "$(bash_in 'cat ~/.claude/proton-bridge.env' | chk)" '"deny"'
has  "cat .env piped onward"               "$(bash_in 'cat .env | grep KEY' | chk)" '"deny"'
has  "reading .env with the file tool"     "$(read_in /Users/x/project/.env | chk)" '"deny"'
has  "reading .env.production"             "$(read_in /Users/x/project/.env.production | chk)" '"deny"'
has  "reading a named env file"            "$(read_in /Users/x/prod.env | chk)" '"deny"'
has  "Slack connector send asks"           "$(tool_in mcp__slack__slack_send_message | chk)" '"ask"'
has  "claude.ai Slack connector asks"      "$(tool_in mcp__claude_ai_Slack__slack_send_message | chk)" '"ask"'
has  "Slack scheduled message asks"        "$(tool_in mcp__slack__slack_schedule_message | chk)" '"ask"'

echo "check.sh: must never block (includes every false alarm from the 30-day replay)"
none "keychain attributes only"            "$(bash_in "$KC -s svc" | chk)"
none "keychain value captured, not shown"  "$(bash_in "pw=\$($KC -s svc -w)" | chk)"
none "keychain value thrown away"          "$(bash_in "$KC -s svc -w >/dev/null 2>&1" | chk)"
none "keychain call inside a script body"  "$(bash_in "python3 - <<PY\\nsubprocess.run('$KC -s x -w', capture_output=True)\\nPY" | chk)"
none "script text mentioning .env"         "$(bash_in 'cat > asana_api.py <<PY\nfor ln in open(.env): pass\nPY' | chk)"
none ".env read inside a script body"      "$(bash_in 'python3 - <<PY\nprint(open(\".env\").read())\nPY' | chk)"
none ".env output thrown away"             "$(bash_in 'head -3 .env >/dev/null 2>&1' | chk)"
none "appending to a remote .env"          "$(bash_in 'ssh root@host \"cat >> /root/app/.env\"' | chk)"
none "listing .env files"                  "$(bash_in 'ls -la /root/app/.env*' | chk)"
none "cat .env.example"                    "$(bash_in 'cat .env.example && ls -la .env' | chk)"
none "cat README.md"                       "$(bash_in 'cat README.md' | chk)"
none "cat .envrc"                          "$(bash_in 'cat .envrc' | chk)"
none ".env in the folder path only"        "$(bash_in 'ls -la' | chk)"
none "grep for .env in code"               "$(bash_in 'grep -rn load_dotenv src' | chk)"
none "searching code for the Slack API"    "$(bash_in 'grep -rl slack.com/api/chat.postMessage /root' | chk)"
none "reading .env.example"                "$(read_in /Users/x/project/.env.example | chk)"
none "reading .envrc"                      "$(read_in /Users/x/project/.envrc | chk)"
none "reading a normal file"               "$(read_in /Users/x/project/README.md | chk)"
none "Slack draft"                         "$(tool_in mcp__slack__slack_send_message_draft | chk)"
none "Slack read"                          "$(tool_in mcp__slack__slack_read_channel | chk)"
none "Write tool with .env in its text"    "$(printf '{"tool_name":"Write","tool_input":{"file_path":"n.md","content":"cat .env"}}' | chk)"
none "garbage input, no crash"             "$(printf 'not json at all' | chk)"
none "empty input, no crash"               "$(printf '' | chk)"

echo "remind.sh"
has   "Asana request gets R1"              "$(prompt_in 'please create an Asana task for the renewal' | rem)" '[R1]'
lacks "Asana request does not get R3"      "$(prompt_in 'please create an Asana task for the renewal' | rem)" '[R3]'
has   "campaign request gets R2"           "$(prompt_in 'launch the new MCA campaign' | rem)" '[R2]'
has   "campaign request gets R6"           "$(prompt_in 'launch the new MCA campaign' | rem)" '[R6]'
has   "Slack send request gets R3"         "$(prompt_in 'post in Slack that the launch is done' | rem)" '[R3]'
none  "a pasted Slack link alone: quiet"   "$(prompt_in 'look at https://x.slack.com/archives/C1/p2' | rem)"
none  "unrelated request gets nothing"     "$(prompt_in 'what is 2 plus 2' | rem)"
none  "folder name alone never triggers"   "$(prompt_in 'hello there' | rem)"
none  "garbage input, no crash"            "$(printf 'garbage' | rem)"
echo "remind.sh: the same rule at most once every 20 requests in a chat"
has   "1st Asana request in a chat: R1"    "$(prompt_in 'asana one' chatA | rem)" '[R1]'
none  "2nd Asana request, same chat: quiet" "$(prompt_in 'asana two' chatA | rem)"
i=3; while [ $i -le 20 ]; do prompt_in "unrelated $i" chatA | rem >/dev/null; i=$((i+1)); done
has   "21st request in that chat: R1 again" "$(prompt_in 'asana again' chatA | rem)" '[R1]'
has   "a new chat gets R1 right away"      "$(prompt_in 'asana' chatB | rem)" '[R1]'

echo "load-rulebook.sh"
LIVE="$TMP/live.md"; printf 'RENAISSANCE RULEBOOK\nVersion: LIVE-TEST\n' > "$LIVE"
out=$(RR_RULEBOOK_URL="$(furl "$LIVE")" sh "$S/load-rulebook.sh" </dev/null)
has   "reachable: uses the live copy"      "$out" 'Version: LIVE-TEST'
has   "reachable: says it is live"         "$out" 'read live from GitHub'
has   "self-test reports checks on"        "$out" 'Hard checks: on.'
# The live test copy holds no [R] rules, so reminders drawn from it must be empty: proves they read the latest copy.
none  "reminders read the latest fetched copy" "$(prompt_in 'asana please' chatC | rem)"
out=$(RR_RULEBOOK_URL="$(furl "$TMP/missing.md")" sh "$S/load-rulebook.sh" </dev/null)
has   "unreachable: uses last fetched"     "$out" 'Version: LIVE-TEST'
has   "unreachable: says so"               "$out" 'last copy fetched on this machine'
rm -f "$HOME/.claude/renaissance-rules/RULEBOOK.md"
out=$(RR_RULEBOOK_URL="$(furl "$TMP/missing.md")" sh "$S/load-rulebook.sh" </dev/null)
has   "no cache: uses shipped copy"        "$out" 'copy that shipped with the plugin'
has   "no cache: shipped copy content"     "$out" '[R1]'
printf '<html>404 Not Found</html>\n' > "$TMP/bad.md"
out=$(RR_RULEBOOK_URL="$(furl "$TMP/bad.md")" sh "$S/load-rulebook.sh" </dev/null)
lacks "a page without the marker is never loaded" "$out" '404 Not Found'
has   "and the shipped copy is used instead"      "$out" '[R1]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
