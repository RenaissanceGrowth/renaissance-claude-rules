# For any Claude working in this repo

This repo holds Renaissance Growth's company rulebook for Claude Code and the small plugin that delivers it.
The owner is Darcy. Only the owner merges changes; everyone else proposes them as a pull request.

The one file almost every change touches: `plugins/renaissance-rules/RULEBOOK.md`

## How to add or change a rule

- A rule is exactly three lines, in this order, with no blank line between them:
  - `[R<n>] The rule in one sentence. If information is missing, tell Claude to ask.`
  - `Why: the real incident it comes from, with a link.`
  - `Remind when a request mentions: word one, word two`
- Number rules in order ([R1], [R2], ...). Never renumber or reuse an existing number.
- Trigger words are lowercase, comma-separated, and name the action (not a whole topic): they decide when the rule is repeated in a chat, so keep them narrow.
- A rule with no real incident behind it is a suggestion, not a rule: put it as a plain bullet under SUGGESTIONS instead. Suggestions have no trigger words and are never repeated.
- Bump the Version line to today's date whenever the file changes.
- Keep it short: about ten rules at most. Removing a rule is as normal as adding one.

## How a change reaches people

- Every new chat everywhere reads this file live from GitHub, so a merged change is live at once. There is nothing else to deploy.
- If you are not the owner: commit to a branch and open a pull request. Darcy merges.

## Do not

- Do not put rules anywhere but RULEBOOK.md. The scripts under `plugins/renaissance-rules/scripts/` and `hooks/hooks.json` only deliver the file.
- Do not add any blocking check. The plugin deliberately has none: it can remind, never stop.
- Before changing anything other than RULEBOOK.md, run `sh tests/run-tests.sh` and keep it passing.
