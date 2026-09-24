#!/usr/bin/env python3
"""Replay the plugin's REAL scripts against someone's past Claude Code history.

Before a check or a reminder goes live, run it against weeks of real work and look at every hit:
how often would it have interrupted, and was each interruption right? This runs the actual
check.sh and remind.sh (not a copy of their logic), so what it reports is what the plugin would do.

    python3 tests/replay.py                       # the last 30 days of this machine's history
    python3 tests/replay.py --days 14 --projects-dir ~/.claude/projects

Histories can contain secrets, so it prints only counts and short examples with long strings
masked. It reads the history and never changes it.

CREATED BY CLAUDE for david-Claude Code, 2026-09-24.
"""
import argparse, collections, datetime, glob, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.join(HERE, "..", "plugins", "renaissance-rules")
CHECK = os.path.join(PLUGIN, "scripts", "check.sh")
REMIND = os.path.join(PLUGIN, "scripts", "remind.sh")
BOOK = os.path.join(PLUGIN, "RULEBOOK.md")

# A call can only trigger check.sh if it contains one of these; everything else provably passes.
CHECK_HINTS = ("security", ".env")


def mask(s, n=90):
    s = re.sub(r"(?i)(bearer\s+)\S+", r"\1***", s)
    s = re.sub(r"[A-Za-z0-9_\-]{16,}", "***", s)
    s = s.replace("\\n", " ").replace("\n", " ")
    return s[:n]


def reminder_words():
    words = set()
    for line in open(BOOK, encoding="utf-8"):
        if line.lower().startswith("remind when a request mentions:"):
            for w in line.split(":", 1)[1].split(","):
                if w.strip():
                    words.add(w.strip().lower())
    return words


def run(script, payload, env):
    r = subprocess.run(["sh", script], input=json.dumps(payload), capture_output=True, text=True, env=env, timeout=20)
    return r.stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--projects-dir", default=os.path.expanduser("~/.claude/projects"))
    a = ap.parse_args()
    since = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=a.days)).isoformat()
    env = dict(os.environ, RR_CACHE_DIR=tempfile.mkdtemp(prefix="rr-replay-"))   # use the shipped rulebook

    files = glob.glob(os.path.join(a.projects_dir, "**", "*.jsonl"), recursive=True)
    seen, calls, prompts = set(), [], []
    for f in files:
        try:
            fh = open(f, encoding="utf-8", errors="replace")
        except OSError:
            continue
        with fh:
            for line in fh:
                if '"timestamp"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if (d.get("timestamp") or "") < since:
                    continue
                msg = d.get("message") or {}
                content = msg.get("content")
                if d.get("type") == "assistant" and isinstance(content, list):
                    for b in content:
                        if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("id") not in seen:
                            seen.add(b.get("id"))
                            calls.append((b.get("name") or "", b.get("input") or {}))
                elif d.get("type") == "user" and msg.get("role") == "user" and not d.get("isMeta"):
                    text = content if isinstance(content, str) else " ".join(
                        b.get("text", "") for b in (content or []) if isinstance(b, dict) and b.get("type") == "text")
                    key = (d.get("uuid") or "") + text[:50]
                    if text.strip() and not text.lstrip().startswith("<") and key not in seen:
                        seen.add(key)
                        prompts.append((d.get("timestamp") or "", d.get("sessionId") or "", text))

    decisions, examples = collections.Counter(), collections.defaultdict(list)
    scanned = collections.Counter()
    for name, inp in calls:
        if name == "Bash":
            scanned["Bash"] += 1
            blob = str(inp.get("command", ""))
        elif name == "Read":
            scanned["Read"] += 1
            blob = str(inp.get("file_path", ""))
        elif name.startswith("mcp__") and "slack" in name.lower():
            scanned["Slack connector"] += 1
            blob = name
        else:
            continue
        if name != "Bash" or any(h in blob for h in CHECK_HINTS):
            if name == "Read" and ".env" not in blob:
                continue
            out = run(CHECK, {"tool_name": name, "tool_input": inp}, env)
            m = re.search(r'"permissionDecision":"(\w+)","permissionDecisionReason":"(Renaissance rule R\d+)', out)
            if m:
                k = "%s  %s" % (m.group(2), m.group(1))
                decisions[k] += 1
                if len(examples[k]) < 8:
                    examples[k].append("%s: %s" % (name, mask(blob)))

    # Every request goes through remind.sh in time order, per chat, so the "once every 20 requests"
    # memory behaves exactly as it would have on the day.
    fired = collections.Counter()
    any_fired = 0
    for ts, sid, p in sorted(prompts):
        out = run(REMIND, {"session_id": sid, "hook_event_name": "UserPromptSubmit", "prompt": p}, env)
        ids = re.findall(r"^\[(R\d+)\]", out, re.M)
        if ids:
            any_fired += 1
            for i in ids:
                fired[i] += 1

    print("Replay of the last %d days: %d history files, %d tool calls, %d requests typed by a person"
          % (a.days, len(files), len(calls), len(prompts)))
    print("\nHARD CHECKS - calls scanned: %s" % dict(scanned))
    if not decisions:
        print("  would never have fired")
    for k, v in decisions.most_common():
        print("  %-28s %5d" % (k, v))
        for e in examples[k]:
            print("      e.g. %s" % e)
    print("\nREMINDERS - requests that would have carried at least one reminder: %d of %d (%.1f%%)"
          % (any_fired, len(prompts), 100.0 * any_fired / max(1, len(prompts))))
    for k, v in sorted(fired.items(), key=lambda kv: int(kv[0][1:])):
        print("  %-5s %5d" % (k, v))


if __name__ == "__main__":
    sys.exit(main())
