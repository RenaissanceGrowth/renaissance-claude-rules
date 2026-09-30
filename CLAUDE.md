# For any Claude working in this repo

This repo holds Renaissance Growth's company rulebook for Claude Code and the small plugin that delivers it.
The owner is Darcy. Only the owner merges changes; everyone else proposes them as a pull request.

The one file almost every change touches: `plugins/renaissance-rules/RULEBOOK.md`

## How to add or change a rule

- A rule is exactly three lines, in this order, with no blank line between them:
  - `[R<n>] The rule in one sentence. If information is missing, tell Claude to ask.`
  - `Why: the incident or the decision it comes from, with a link.` A manager's written decision counts; so does something that went wrong.
  - If you cannot open the link yourself, write the reason as the person gave it and end the line with "(as reported, not checked)", so the owner knows to look before merging.
  - `Remind when a request mentions: word one, word two`
- Number rules in order ([R1], [R2], ...). Never renumber or reuse an existing number.
- Trigger words are lowercase and comma-separated. Each trigger is one or two plain words naming the action ("delete inbox", "asana"); it fires when all its words appear in the request in any order and any form (deleting, inboxes), so list one or two triggers, not every phrasing. A single common word ("instantly", "email") fires far too often; name the action instead.
- A rule with neither an incident nor a decision behind it is a suggestion, not a rule: put it as a plain bullet under SUGGESTIONS instead. Suggestions have no trigger words and are never repeated.
- Change the date on the Version line (line 2 of the file) to today whenever the file changes. The line says so itself.
- Keep it short: about ten rules at most. Removing a rule is as normal as adding one.

## How a change reaches people

- Every new chat everywhere reads this file live from GitHub, so a merged change is live at once. There is nothing else to deploy.
- If you are not the owner: commit to a branch and open a pull request. Darcy merges.

## Do not

- Do not put rules anywhere but RULEBOOK.md. The scripts under `plugins/renaissance-rules/scripts/` and `hooks/hooks.json` only deliver the file.
- Do not add any blocking check. The plugin deliberately has none: it can remind, never stop.
- Before changing anything other than RULEBOOK.md, run `sh tests/run-tests.sh` and keep it passing.
