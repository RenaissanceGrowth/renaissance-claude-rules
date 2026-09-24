# Renaissance rules for Claude Code

A Claude Code plugin that gives every employee's Claude the same company rules, kept in one place.

CREATED BY CLAUDE for david-Claude Code, 2026-09-24. What it is for: company rules for Claude Code.
What it opens: nothing (it only adds rules text and local checks to a person's Claude). How to revoke:
uninstall the plugin on each machine, or archive this repo so installed copies stop updating.

## Status (24 Sep 2026)

- Built and tested. Not installed on anyone's machine yet.
- The six rules in `RULEBOOK.md` are a starter draft. The rules owner confirms each one before anyone installs this.
- The repo is private while it is being set up. Before install it must be public: with a private repo, each person's Claude cannot read the rulebook or get updates without a GitHub login, and it fails silently.
- Owner: not named yet.

## What it does: three layers

1. Rulebook. At the start of every chat, and again whenever a long chat is compressed, Claude reads `plugins/renaissance-rules/RULEBOOK.md` straight from GitHub. Change that file here and every new chat everywhere gets it. If GitHub can't be reached, Claude uses the last copy it fetched, then the copy that shipped with the plugin, and says which.
2. Reminders. When a request mentions a topic (Asana, a campaign, sending a message...), the rules for that topic are repeated right then. The same rule repeats at most once every 20 requests in a chat. Nothing is blocked.
3. Hard checks, only for rules that are expensive to break and visible in the action itself:
   - printing a saved password or a `.env` file into the chat is blocked;
   - sending a Slack message through a Slack connector needs the person's approval first.

   These live in `scripts/check.sh` with fixed messages, so editing the rulebook can never change what a block says.

## How to change a rule

Edit `plugins/renaissance-rules/RULEBOOK.md`. Each rule is three lines:

    [R7] The rule, in one sentence. If information is missing, say "ask".
    Why: the real incident it comes from, with a link.
    Remind when a request mentions: word one, word two

Keep it to about ten rules. A rule nobody can point to an incident for doesn't go in. New hard checks are code changes to `scripts/check.sh` and must pass both tests below first.

## Tests (run both before any change goes live)

    sh tests/run-tests.sh                 # 61 cases: what must be caught, and what must never be blocked
    python3 tests/replay.py --days 30     # replays the real scripts against the last 30 days of Claude work

The 30-day replay on 24 Sep (4,055 requests, 67,421 actions): the checks would have blocked 5 actions (4 real secret leaks, 1 arguable) and asked approval for 4 Slack sends; 16% of requests would have carried a reminder.

## Install (to be finalized)

Each person sends one message to their own Claude Code, once:

    Install our company rules plugin for Claude Code from https://github.com/RenaissanceGrowth/renaissance-claude-rules and make sure auto-update is turned on for it.

To check anyone's setup, ask their Claude: "which rulebook version do you have?"

## Known limits

- It only governs what Claude Code does: not what a person does by hand, and not the claude.ai app.
- Anyone can switch it off on their own machine. It assumes good faith.
- Slack messages sent by scripts can't be seen reliably, so that case is left to the rulebook (R3).
- Windows: the scripts are plain `sh` and run through Git Bash, which Claude Code uses on Windows by default. Not yet tested on a Windows machine.
