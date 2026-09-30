#!/usr/bin/env python3
"""Replay the plugin's REAL reminder script against someone's past Claude Code history.

Before a rule goes live, run it against weeks of real work: how often would its reminder have
appeared? This runs the actual remind.sh (not a copy of its logic), so what it reports is what the
plugin would do.

    python3 tests/replay.py                       # the last 30 days of this machine's history
    python3 tests/replay.py --days 14 --projects-dir ~/.claude/projects

Histories can contain secrets, so it prints counts only. It reads the history and never changes it.

CREATED BY CLAUDE for david-Claude Code, 2026-09-24; trimmed 2026-09-30 when the hard checks were removed.
"""
import argparse, collections, datetime, glob, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REMIND = os.path.join(HERE, "..", "plugins", "renaissance-rules", "scripts", "remind.sh")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--projects-dir", default=os.path.expanduser("~/.claude/projects"))
    a = ap.parse_args()
    since = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=a.days)).isoformat()
    env = dict(os.environ, RR_CACHE_DIR=tempfile.mkdtemp(prefix="rr-replay-"))   # use the shipped rulebook

    files = glob.glob(os.path.join(a.projects_dir, "**", "*.jsonl"), recursive=True)
    seen, prompts = set(), []
    for f in files:
        try:
            fh = open(f, encoding="utf-8", errors="replace")
        except OSError:
            continue
        with fh:
            for line in fh:
                if '"timestamp"' not in line or '"user"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if (d.get("timestamp") or "") < since or d.get("type") != "user" or d.get("isMeta"):
                    continue
                msg = d.get("message") or {}
                if msg.get("role") != "user":
                    continue
                content = msg.get("content")
                text = content if isinstance(content, str) else " ".join(
                    b.get("text", "") for b in (content or []) if isinstance(b, dict) and b.get("type") == "text")
                key = (d.get("uuid") or "") + text[:50]
                if text.strip() and not text.lstrip().startswith("<") and key not in seen:
                    seen.add(key)
                    prompts.append((d.get("timestamp") or "", d.get("sessionId") or "", text))

    # Every request goes through remind.sh in time order, per chat, so the "once every 20 requests"
    # memory behaves exactly as it would have on the day.
    fired, any_fired = collections.Counter(), 0
    for ts, sid, p in sorted(prompts):
        out = subprocess.run(["sh", REMIND], input=json.dumps({"session_id": sid, "hook_event_name": "UserPromptSubmit", "prompt": p}),
                             capture_output=True, text=True, env=env, timeout=20).stdout
        ids = re.findall(r"^\[(R\d+)\]", out, re.M)
        if ids:
            any_fired += 1
            for i in ids:
                fired[i] += 1

    print("Replay of the last %d days: %d history files, %d requests typed by a person" % (a.days, len(files), len(prompts)))
    print("Requests that would have carried at least one reminder: %d of %d (%.1f%%)"
          % (any_fired, len(prompts), 100.0 * any_fired / max(1, len(prompts))))
    for k, v in sorted(fired.items(), key=lambda kv: int(kv[0][1:])):
        print("  %-5s %5d" % (k, v))


if __name__ == "__main__":
    sys.exit(main())
