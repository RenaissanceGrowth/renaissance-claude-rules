# Renaissance rules for Claude Code

A Claude Code plugin that gives every colleague's Claude the same short company rulebook, kept in one place.

CREATED BY CLAUDE for david-Claude Code, 2026-09-24; trimmed 2026-09-30. What it is for: company rules for
Claude Code. What it opens: nothing (it only adds rules text to a person's Claude). How to revoke: uninstall the
plugin on each machine, or archive this repo so installed copies stop updating.

## Status (30 Sep 2026)

- Built and tested. Not installed on anyone's machine yet.
- One rule (R1, Asana due date and assignee) for Darcy to confirm or drop, plus a suggestions section that changes nothing.
- No hard blocks. Nothing this plugin does can stop an action.
- Home: this repo moves to Darcy's own GitHub account (github.com/darcyhi/renaissance-claude-rules) before anyone installs, and goes public then. The plugin already points at that address.
- Owner: Darcy.

## What it does: two layers

1. Rulebook. At the start of every chat, and again whenever a long chat is compressed, Claude reads `plugins/renaissance-rules/RULEBOOK.md` straight from GitHub. Change that file and every new chat everywhere gets it. If GitHub can't be reached, Claude uses the last copy it fetched, then the copy that shipped with the plugin, and says which.
2. Reminders. When a request mentions a rule's topic (for R1: "asana"), that rule is repeated right then. The same rule repeats at most once every 20 requests in a chat.

## How Darcy changes a rule

Edit `plugins/renaissance-rules/RULEBOOK.md` on GitHub. Each rule is three lines:

    [R2] The rule, in one sentence. If information is missing, say "ask".
    Why: the real incident it comes from, with a link.
    Remind when a request mentions: word one, word two

A rule nobody can point to an incident for doesn't go in. Suggestions (practices worth knowing, never enforced or
repeated) go under SUGGESTIONS as plain bullets. Anyone can propose a change; only the repo owner can accept it.

## Tests

    sh tests/run-tests.sh                 # 24 cases
    python3 tests/replay.py --days 30     # how often the reminders would have appeared on this machine's last 30 days

## Install (once the repo is public)

Each person sends one message to their own Claude Code, once:

    Install our company rules plugin for Claude Code from https://github.com/darcyhi/renaissance-claude-rules and make sure auto-update is turned on for it.

To check anyone's setup, ask their Claude: "which rulebook version do you have?"

## Known limits

- It only governs what Claude Code does: not what a person does by hand, and not the claude.ai app.
- Anyone can switch it off on their own machine. It assumes good faith.
- Windows: the scripts are plain `sh` and run through Git Bash, which Claude Code uses on Windows by default. Not yet tested on a Windows machine.
