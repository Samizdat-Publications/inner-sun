"""Long-context numeric audit by Gemini over the committed repo (D057).

    python tools/gemini_audit.py --count                      token count of the pack, no call
    python tools/gemini_audit.py --question <file.md>          ask a specific audit question
    python tools/gemini_audit.py --question q.md --extra docs/plans/specs/m2p_store.md

Sends committed files only (git show HEAD:<path>): the core docs, plans, research docs, the newest
balance reports and critique, all of game/sim, game/bots, game/data and game/meta, plus any --extra
paths. Never research_private/ (git-ignored FTL material) and never keys. The reply goes to
harness/out/gemini_audit/<stamp>/reply.md and the spend to docs/SPEND.md.

Gemini's findings are leads, not facts: the first consult (review/consults/2026-10-22_gemini-4-argon.md)
had 8 of 11 findings hold up and one confident false one. The lead verifies each before acting.
The API key comes from the environment, else the Noclip .env (critic_gemini.load_key); never printed.
"""
import argparse
import datetime as dt
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import critic_gemini  # noqa: E402
import paths  # noqa: E402

MODEL = "gemini-4-argon"
PRICE_IN, PRICE_OUT = critic_gemini.PRICES["pro"]  # USD per million tokens; Argon's own price unconfirmed

CORE = [
    "CLAUDE.md", "PLAN.md", "PROGRESS.md", "HANDOFF.md", "docs/DECISIONS.md", "docs/STEWART_FEEDBACK.md",
    "docs/ARCHITECTURE.md", "docs/BACKLOG.md", "docs/STYLE_GUIDE.md", "docs/SPEND.md", "review/LEDGER.md",
    "docs/research/ftl-reference.md", "docs/research/behavior-ledger.md", "docs/research/ftl-difftest-plan.md",
]
TREES = ["game/sim", "game/bots", "game/data", "game/meta"]

PREAMBLE = """You are auditing Inner Sun, an FTL-style roguelite in Godot 4.7.2 (strictly typed GDScript): a
drill tower boring down through a hollow Earth. Rules live in a deterministic, node-free simulation
(game/sim) on a fixed 60 Hz tick with exact integer conservation, seeded random streams, replays and
headless balance bots (game/bots); content is JSON (game/data). Claude (Anthropic) is the lead engineer
and will verify every finding before acting, so only report what you can show from the material: the
file and the exact quoted text or JSON key, what is wrong, the calculation, and your confidence (high,
medium, low). Say "not verifiable from the material" rather than guess. Do not use em dashes.

The committed files follow, each starting with a "=== FILE: path ===" line.

THE QUESTION
"""


def git(*args) -> str:
    return subprocess.run(["git", "-C", paths.ROOT, *args], capture_output=True, text=True,
                          encoding="utf-8", check=True).stdout


def pack_files(extra: list) -> list:
    files = list(CORE)
    reports = sorted(p for p in git("ls-files", "docs/research/m1-evidence").splitlines() if "balance" in p)
    files += reports[-3:]
    crit = sorted(git("ls-files", "review/critiques").splitlines())
    files += crit[-1:]
    for t in TREES:
        files += [p for p in git("ls-files", t).splitlines() if p.endswith((".gd", ".json", ".md"))]
    files += extra
    return [f for f in files if not f.startswith("research_private")]


def log_spend(label: str, tin: int, tout: int) -> float:
    cost = tin / 1e6 * PRICE_IN + tout / 1e6 * PRICE_OUT
    line = (f"| {dt.date.today().isoformat()} | Gemini ({MODEL}) | audit -> {label} | "
            f"{cost:.2f} (est at Pro rates, {tin} in / {tout} out tokens) |\n")
    with open(os.path.join(paths.ROOT, "docs", "SPEND.md"), "a", encoding="utf-8") as f:
        f.write(line)
    return cost


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--question", default="", help="markdown file with the audit question")
    ap.add_argument("--extra", nargs="*", default=[], help="more committed paths to include")
    ap.add_argument("--model", default=MODEL)
    ap.add_argument("--count", action="store_true", help="count tokens only, no generation")
    a = ap.parse_args(argv)
    from google import genai
    from google.genai import types
    key = critic_gemini.load_key()
    if not key:
        print("gemini_audit: no GEMINI_API_KEY / GOOGLE_API_KEY in the environment or the Noclip .env")
        return 1
    question = open(a.question, encoding="utf-8").read() if a.question else \
        "Where could you add value to this project that the current setup does not cover? Then prove it with a spot audit of the numbers."
    head = git("rev-parse", "--short", "HEAD").strip()
    chunks = []
    for p in pack_files(a.extra):
        try:
            chunks.append("=== FILE: %s ===\n%s" % (p, git("show", "HEAD:" + p)))
        except subprocess.CalledProcessError:
            print("gemini_audit: skip (not committed):", p)
    text = PREAMBLE + question + "\n\nRepository at commit " + head + ".\n\n" + "\n\n".join(chunks)
    contents = [types.Content(role="user", parts=[types.Part.from_text(text=text)])]
    client = genai.Client(api_key=key)
    tokens = client.models.count_tokens(model=a.model, contents=contents).total_tokens
    print(f"gemini_audit: {len(chunks)} files, {tokens} input tokens, about "
          f"{tokens / 1e6 * PRICE_IN:.2f} USD in at Pro rates")
    if a.count:
        return 0
    resp = client.models.generate_content(model=a.model, contents=contents,
                                          config=types.GenerateContentConfig(max_output_tokens=32000))
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    out = os.path.join(paths.OUT, "gemini_audit", stamp)
    os.makedirs(out, exist_ok=True)
    reply = (resp.text or "").replace(chr(0x2014), " - ")
    with open(os.path.join(out, "reply.md"), "w", encoding="utf-8") as f:
        f.write(reply)
    u = resp.usage_metadata
    tin = int(getattr(u, "prompt_token_count", 0) or 0)
    tout = int(getattr(u, "candidates_token_count", 0) or 0) + int(getattr(u, "thoughts_token_count", 0) or 0)
    cost = log_spend(stamp, tin, tout)
    with open(os.path.join(out, "meta.json"), "w", encoding="utf-8") as f:
        json.dump({"model": a.model, "commit": head, "in": tin, "out": tout, "usd_est": round(cost, 2)}, f, indent=2)
    print(f"gemini_audit: reply in {out} ({len(reply)} chars), about {cost:.2f} USD")
    return 0


if __name__ == "__main__":
    sys.exit(main())
