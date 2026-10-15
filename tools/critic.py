"""Blind player-critic runner: drives a headless Claude Code process, saves the review.

    python tools/critic.py [--model sonnet|opus] [--timeout 900] [--dry-run] [--selftest]

Runs (cwd = repo root):
    claude -p "<prompt>" --model sonnet --output-format stream-json --verbose --allowedTools Agent
The prompt makes the parent invoke the `player-critic` subagent with exactly
"A new build is in review/inbox. Play it." and echo its review. The review is taken from the
subagent's SubagentHandback tool_use input ("message"), falling back to the final result event.
Every tool call the critic made is recorded; if any call outside review/inbox SUCCEEDED the run
fails loudly (exit 1) and nothing is saved as a valid review. Blocked calls are fine.

Saves review/critiques/NNN_claude.md and appends a row to review/scores.csv.
The helpers below (next_number, build_info, parse_scores, append_scores_row) are shared with
tools/critic_gemini.py.
"""
import argparse
import csv
import datetime as dt
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
INBOX = os.path.join(ROOT, "review", "inbox")
CRIT_DIR = os.path.join(ROOT, "review", "critiques")
SCORES = os.path.join(ROOT, "review", "scores.csv")

CRITIC_INPUT = "A new build is in review/inbox. Play it."
PROMPT = (
    "Invoke the player-critic subagent exactly once, using the Agent tool with subagent_type "
    "player-critic and with the prompt parameter set to exactly this text (without the quote marks): "
    "'" + CRITIC_INPUT + "' "
    "Add nothing else to that prompt. When the subagent returns its review, output that review "
    "verbatim and nothing else: no preface, no commentary, no summary."
)

CSV_COLS = ["build_id", "date", "seed", "critic", "first_impression", "readability", "lighting",
            "art", "hazards", "crew", "world", "ui", "sound", "performance", "keep_playing"]
SCORE_COLS = CSV_COLS[4:]


# ---------------------------------------------------------------- shared helpers

def next_number():
    top = 0
    for p in glob.glob(os.path.join(CRIT_DIR, "*")):
        m = re.match(r"(\d{3})_", os.path.basename(p))
        if m:
            top = max(top, int(m.group(1)))
    return f"{top + 1:03d}"


def git_short():
    try:
        out = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True,
                             text=True, timeout=20)
        return out.stdout.strip() or "nogit"
    except Exception:
        return "nogit"


def build_info():
    """(build_id, seed). Reads review/inbox/meta.json or build.json if present, else git hash."""
    for name in ("meta.json", "build.json", "build_id.json"):
        p = os.path.join(INBOX, name)
        if os.path.exists(p):
            try:
                d = json.load(open(p, encoding="utf-8"))
                if d.get("build_id"):
                    return str(d["build_id"]), str(d.get("seed", ""))
            except Exception:
                pass
    p = os.path.join(INBOX, "build_id.txt")
    if os.path.exists(p):
        t = open(p, encoding="utf-8").read().strip()
        if t:
            return t, ""
    return git_short(), ""


def _cat_column(label):
    s = label.lower()
    rules = [
        ("first_impression", r"first impression|screenshot"),
        ("readability", r"readab"),
        ("lighting", r"light|atmosph"),
        ("hazards", r"hazard|fire|water|heat"),
        ("crew", r"\bcrew\b"),
        ("world", r"world|outside"),
        ("sound", r"sound|audio"),
        ("performance", r"perform"),
        ("keep_playing", r"keep playing|would i"),
        ("ui", r"\bui\b|hud"),
        ("art", r"\bart\b|material"),
    ]
    for col, pat in rules:
        if re.search(pat, s):
            return col
    return None


def parse_scores(text):
    """Map the '## Scores' table to {column: value or ''}. N/A and blanks become ''."""
    out = {c: "" for c in SCORE_COLS}
    m = re.search(r"^#{1,3}\s*Scores\b.*$", text, re.M | re.I)
    if not m:
        return out
    for line in text[m.end():].splitlines():
        s = line.strip()
        if s.startswith("#"):
            break
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if len(cells) < 2 or set(cells[0]) <= set("-: "):
            continue
        col = _cat_column(cells[0])
        if col is None or out[col] != "":
            continue
        v = re.match(r"\**\s*(\d+(?:\.\d+)?)", cells[1])
        out[col] = v.group(1) if v else ""
    return out


def append_scores_row(build_id, seed, critic, scores, path=None):
    path = path or SCORES
    row = {"build_id": build_id, "date": dt.date.today().isoformat(), "seed": seed, "critic": critic}
    row.update(scores)
    new = not os.path.exists(path)
    needs_nl = False
    if not new:
        with open(path, "rb") as f:
            data = f.read()
        needs_nl = len(data) > 0 and not data.endswith(b"\n")
        header = data.decode("utf-8").splitlines()[0].split(",") if data else CSV_COLS
    else:
        header = CSV_COLS
    with open(path, "a", encoding="utf-8", newline="") as f:
        if needs_nl:
            f.write("\n")
        w = csv.writer(f, lineterminator="\n")
        if new:
            w.writerow(header)
        w.writerow([row.get(c, "") for c in header])
    return row


def score_summary(scores):
    got = [float(v) for v in scores.values() if v != ""]
    parts = " ".join(f"{k}={v}" for k, v in scores.items() if v != "")
    avg = f"avg {sum(got) / len(got):.1f} over {len(got)}" if got else "no scores parsed"
    return f"{avg} | {parts}"


def save_review(who, header_model, text):
    scores = parse_scores(text)
    if not any(v != "" for v in scores.values()):
        raise ValueError("no scores could be parsed from the review's '## Scores' table")
    os.makedirs(CRIT_DIR, exist_ok=True)
    num = next_number()
    build_id, seed = build_info()
    path = os.path.join(CRIT_DIR, f"{num}_{who}.md")
    head = f"Build: {build_id} | Date: {dt.date.today().isoformat()} | Critic: {who} | Model: {header_model}"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(head + "\n\n" + text.strip() + "\n")
    append_scores_row(build_id, seed, who, scores)
    return path, scores


def clean_review(text):
    t = text.strip()
    i = t.find("# Player Review")
    if i > 0:
        t = t[i:]
    t = t.strip()
    if t.endswith("```"):
        t = t[:-3].rstrip()
    # A review echoed as a block quote: drop the leading "> " so the table still parses.
    lines = t.splitlines()
    if lines and sum(1 for l in lines if l.startswith(">")) > len(lines) // 2:
        t = "\n".join(re.sub(r"^>\s?", "", l) for l in lines)
    # House rule: no em dashes anywhere (models emit them anyway). U+2014 becomes a spaced hyphen.
    t = re.sub(r"\s*" + chr(0x2014) + r"\s*", " - ", t)
    return t.strip()


# ---------------------------------------------------------------- stream parsing

def _iter_events(lines):
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except Exception:
            continue


def _tool_result_text(block):
    c = block.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return "\n".join(x.get("text", "") for x in c if isinstance(x, dict))
    return ""


def parse_stream(lines):
    """Return dict: calls (list), handback (str), result (str), assistant_text (str)."""
    uses = {}      # id -> {name, input, parent}
    order = []
    results = {}   # id -> {is_error, text}
    handback = ""
    result = ""
    last_parent_text = ""
    for e in _iter_events(lines):
        t = e.get("type")
        parent = e.get("parent_tool_use_id")
        if t == "assistant":
            for b in e.get("message", {}).get("content", []):
                if b.get("type") == "tool_use":
                    uses[b["id"]] = {"name": b.get("name", ""), "input": b.get("input", {}) or {},
                                     "parent": parent}
                    order.append(b["id"])
                    if parent and b.get("name") == "SubagentHandback":
                        m = (b.get("input") or {}).get("message")
                        if isinstance(m, str) and len(m) > len(handback):
                            handback = m
                elif b.get("type") == "text" and not parent:
                    last_parent_text = b.get("text", "")
        elif t == "user":
            content = e.get("message", {}).get("content", [])
            if isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "tool_result":
                        results[b.get("tool_use_id")] = {
                            "is_error": bool(b.get("is_error")), "text": _tool_result_text(b)}
        elif t == "result":
            result = e.get("result", "") or ""
    calls = []
    for i in order:
        u = uses[i]
        r = results.get(i)
        blocked = bool(r and r["is_error"])
        calls.append({"id": i, "name": u["name"], "input": u["input"], "parent": u["parent"],
                      "has_result": r is not None, "blocked": blocked,
                      "result_head": (r["text"][:160] if r else "")})
    return {"calls": calls, "handback": handback, "result": result, "assistant_text": last_parent_text}


def _target_path(name, inp):
    """Best-effort filesystem target of a call, as an absolute normalized path (or None)."""
    if name == "Read":
        raw = inp.get("file_path") or ""
    elif name == "Glob":
        base = inp.get("path") or ""
        pat = inp.get("pattern") or ""
        cut = re.split(r"[*?\[{]", pat)[0]
        raw = os.path.join(base, cut) if base and not os.path.isabs(cut) else (cut or base)
        if ".." in pat.replace("\\", "/").split("/"):
            return "<parent-escape>"
        if not raw:
            return ROOT
    elif name == "Grep":
        raw = inp.get("path") or ""
        if not raw:
            return ROOT
    else:
        return None
    if not raw:
        return None
    p = raw if os.path.isabs(raw) else os.path.join(ROOT, raw)
    return os.path.normcase(os.path.abspath(p))


def inside_inbox(p):
    if p is None or p == "<parent-escape>":
        return False
    inbox = os.path.normcase(os.path.abspath(INBOX))
    try:
        return os.path.commonpath([p, inbox]) == inbox
    except ValueError:
        return False


def violations(calls):
    """Subagent calls that succeeded but touched something outside review/inbox."""
    bad = []
    for c in calls:
        if not c["parent"]:
            continue  # parent-level calls (Agent) are not the critic's
        if c["blocked"]:
            continue
        if c["name"] == "SubagentHandback":
            continue
        if c["name"] in ("Read", "Glob", "Grep"):
            if inside_inbox(_target_path(c["name"], c["input"])):
                continue
        bad.append(c)
    return bad


def describe(c):
    i = c["input"]
    tgt = i.get("file_path") or i.get("pattern") or i.get("path") or i.get("command") or ""
    if c["name"] == "Glob" and i.get("path"):
        tgt = f"{i['path']} :: {i.get('pattern', '')}"
    if c["name"] == "SubagentHandback":
        tgt = f"<report {len(i.get('message', ''))} chars>"
    return f"{c['name']}({str(tgt)[:120]})" + (" [blocked]" if c["blocked"] else "")


# ---------------------------------------------------------------- run

def find_claude():
    p = shutil.which("claude")
    if not p:
        sys.exit("critic: claude CLI not found on PATH")
    return p


def build_cmd(model):
    return [find_claude(), "-p", PROMPT, "--model", model, "--output-format", "stream-json",
            "--verbose", "--allowedTools", "Agent"]


def run_claude(cmd, timeout, stream_path):
    flags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
    with open(stream_path, "w", encoding="utf-8", newline="\n") as out:
        p = subprocess.Popen(cmd, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=out,
                             stderr=subprocess.PIPE, text=True, encoding="utf-8", creationflags=flags)
        try:
            _, err = p.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            # Kill only our own process tree, by PID.
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
            p.communicate()
            return None, "timeout"
    return p.returncode, (err or "")[-2000:]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", default="sonnet", help="sonnet (default) or opus for milestone gates")
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--from-file", metavar="PATH.md",
                    help="skip running Claude: save and score an already written review")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if a.from_file:
        try:
            raw = open(a.from_file, encoding="utf-8").read()
            path, scores = save_review("claude", f"{a.model} (in-session)", clean_review(raw))
        except (OSError, ValueError) as e:
            print(f"critic: FAILED, {e}")
            return 1
        print(f"critic: saved {path}")
        print("critic: scores " + score_summary(scores))
        return 0
    cmd = build_cmd(a.model)
    if a.dry_run:
        print("cwd:", ROOT)
        print("cmd:", " ".join(f'"{c}"' if " " in c else c for c in cmd))
        print("would save to:", os.path.join(CRIT_DIR, f"{next_number()}_claude.md"))
        return 0
    if not os.path.isdir(INBOX):
        print("critic: review/inbox is missing; run tools/capture.py first")
        return 1
    stream = os.path.join(tempfile.gettempdir(), f"inner_sun_critic_{os.getpid()}.jsonl")
    print(f"critic: running {a.model} (timeout {a.timeout}s), stream -> {stream}")
    code, err = run_claude(cmd, a.timeout, stream)
    if code is None:
        print(f"critic: FAILED, timed out after {a.timeout}s (stream kept at {stream})")
        return 1
    parsed = parse_stream(open(stream, encoding="utf-8", errors="replace"))
    calls = parsed["calls"]
    print(f"critic: {len(calls)} tool calls recorded")
    for c in calls:
        print("  " + ("[critic] " if c["parent"] else "[parent] ") + describe(c))
    bad = violations(calls)
    if bad:
        print("critic: FAILED, the critic got outside review/inbox. Review NOT saved. Offending calls:")
        for c in bad:
            print("  " + describe(c))
        print(f"  stream kept at {stream}")
        return 1
    text = ""
    for cand in (parsed["handback"], parsed["result"], parsed["assistant_text"]):
        if cand and "## Scores" in cand:
            text = cand
            break
    if not text:
        print(f"critic: FAILED, no review with a '## Scores' table found (exit {code}). stderr tail: {err[-300:]}")
        print(f"  stream kept at {stream}")
        return 1
    try:
        path, scores = save_review("claude", a.model, clean_review(text))
    except ValueError as e:
        print(f"critic: FAILED, {e}. Stream kept at {stream}")
        return 1
    print(f"critic: saved {path}")
    print("critic: scores " + score_summary(scores))
    try:
        os.remove(stream)
    except OSError:
        pass
    return 0


# ---------------------------------------------------------------- selftest

SAMPLE = """# Player Review

## Gut reaction
Meh but promising.

## Scores (1 to 10, or N/A)
| Category | Score | Why (one line) |
|---|---|---|
| First impression / screenshot-worthiness | 5 | flat |
| Readability: can I tell what is going on in the ship | 4 | boxes |
| Lighting and atmosphere | 6 | ok |
| Art and materials | 5 | meh |
| Hazards: fire, water and heat read clearly | N/A | none seen |
| Crew: do they look alive and purposeful | 3 | statues |
| The world outside the hull | 6.5 | nice |
| UI and HUD | 4 | tiny |
| Sound | N/A | cannot hear |
| Performance | 9 | fast |
| Would I keep playing | 5 | maybe |

## Top problems (ranked, max 7)
1. [hurts] x
"""

GUARD_SAMPLE = os.path.join(
    os.environ.get("LOCALAPPDATA", ""), "Temp", "claude", "C--Users-stewa--claude-spares-spare-wFGqVV",
    "4048d71a-870e-4cd0-9163-fb40678ad645", "scratchpad", "guard_live2.jsonl")


def selftest():
    fails = []

    def check(name, cond):
        print(("ok   " if cond else "FAIL ") + name)
        if not cond:
            fails.append(name)

    s = parse_scores(SAMPLE)
    check("score first_impression=5", s["first_impression"] == "5")
    check("score hazards empty (N/A)", s["hazards"] == "")
    check("score world=6.5", s["world"] == "6.5")
    check("score art=5 not ui", s["art"] == "5" and s["ui"] == "4")
    check("score keep_playing=5", s["keep_playing"] == "5")
    check("score sound empty", s["sound"] == "")
    check("score crew=3 readability=4", s["crew"] == "3" and s["readability"] == "4")
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "scores.csv")
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(",".join(CSV_COLS) + "\n")
        append_scores_row("abc123", "7", "claude", s, p)
        rows = list(csv.reader(open(p, encoding="utf-8")))
        check("csv has header + 1 row", len(rows) == 2 and len(rows[1]) == len(CSV_COLS))
        r = dict(zip(rows[0], rows[1]))
        check("csv row values", r["build_id"] == "abc123" and r["critic"] == "claude" and r["seed"] == "7"
              and r["first_impression"] == "5" and r["hazards"] == "" and r["performance"] == "9"
              and r["keep_playing"] == "5")
    if os.path.exists(GUARD_SAMPLE):
        pr = parse_stream(open(GUARD_SAMPLE, encoding="utf-8"))
        names = [(c["name"], c["blocked"]) for c in pr["calls"] if c["parent"]]
        check("sample: 3 blocked calls", sum(1 for n, b in names if b) == 3)
        check("sample: inbox read allowed", ("Read", False) in names)
        check("sample: handback captured", len(pr["handback"]) > 200)
        check("sample: no violations", violations(pr["calls"]) == [])
        bad = [dict(c, blocked=False) for c in pr["calls"] if c["parent"] and c["blocked"]]
        check("sample: unblocked outside reads are violations", len(violations(bad)) == 3)
    else:
        print("skip guard_live2.jsonl sample (not found)")
    glob_ok = {"name": "Glob", "input": {"pattern": "review/inbox/**/*"}, "parent": "x", "blocked": False}
    glob_bad = {"name": "Glob", "input": {"pattern": "**/*.md"}, "parent": "x", "blocked": False}
    glob_esc = {"name": "Glob", "input": {"pattern": "review/inbox/../../*"}, "parent": "x", "blocked": False}
    bash = {"name": "Bash", "input": {"command": "ls"}, "parent": "x", "blocked": False}
    check("glob inbox ok", violations([glob_ok]) == [])
    check("glob everything flagged", len(violations([glob_bad])) == 1)
    check("glob parent escape flagged", len(violations([glob_esc])) == 1)
    check("bash flagged", len(violations([bash])) == 1)
    check("fence/quote cleanup", clean_review("> # Player Review\n> x\n> y").startswith("# Player Review"))
    check("em dash replaced", chr(0x2014) not in clean_review("# Player Review\na" + chr(0x2014) + "b"))
    print("selftest:", "ok" if not fails else f"{len(fails)} FAILED")
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
