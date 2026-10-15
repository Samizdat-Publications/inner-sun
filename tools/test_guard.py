"""Unit test for the player-critic guard hook: pipes fake tool calls into it and checks the verdicts.

    python tools/test_guard.py            (tests the installed .claude/hooks/critic_guard.mjs)
    python tools/test_guard.py --staged   (tests docs/setup/critic/critic_guard.mjs in a mirror of
                                           the repo layout, before it is installed)

The live test (asking player-critic to read CLAUDE.md and seeing it blocked) needs a session whose
working folder is this repo; it is step 0 of the first build session (see HANDOFF.md).
"""
import json
import os
import subprocess
import sys

import shutil

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ROOT = REPO
GUARD = os.path.join(REPO, ".claude", "hooks", "critic_guard.mjs")
if "--staged" in sys.argv:
    # Mirror the installed layout (<root>/.claude/hooks/critic_guard.mjs) in a scratch folder, since
    # the guard finds the repo root from its own location.
    ROOT = os.path.join(REPO, "harness", "out", "guardtest", "repo")
    shutil.rmtree(os.path.dirname(ROOT), ignore_errors=True)
    os.makedirs(os.path.join(ROOT, ".claude", "hooks"))
    os.makedirs(os.path.join(ROOT, "review", "inbox", "frames"))
    GUARD = os.path.join(ROOT, ".claude", "hooks", "critic_guard.mjs")
    shutil.copy(os.path.join(REPO, "docs", "setup", "critic", "critic_guard.mjs"), GUARD)
if not os.path.exists(GUARD):
    print(f"guard: FAIL (not installed: {GUARD}; with the hook missing, node exits 1 and Claude Code "
          "treats that as NON-blocking, so the critic would be unguarded)")
    sys.exit(1)

CASES = [
    ("read a frame in the inbox", {"tool_name": "Read", "tool_input": {"file_path": "review/inbox/frames/frame_01.png"}}, 0),
    ("read the inbox by absolute path", {"tool_name": "Read", "tool_input": {"file_path": os.path.join(ROOT, "review", "inbox", "perf.json")}}, 0),
    ("glob inside the inbox", {"tool_name": "Glob", "tool_input": {"pattern": "review/inbox/**/*"}}, 0),
    ("read CLAUDE.md", {"tool_name": "Read", "tool_input": {"file_path": "CLAUDE.md"}}, 2),
    ("read the plan by absolute path", {"tool_name": "Read", "tool_input": {"file_path": os.path.join(ROOT, "PLAN.md")}}, 2),
    ("escape the inbox with ..", {"tool_name": "Read", "tool_input": {"file_path": "review/inbox/../../CLAUDE.md"}}, 2),
    ("glob the whole repo", {"tool_name": "Glob", "tool_input": {"pattern": "**/*.md"}}, 2),
    ("glob with .. in the pattern", {"tool_name": "Glob", "tool_input": {"pattern": "review/inbox/../**"}}, 2),
    ("use Bash", {"tool_name": "Bash", "tool_input": {"command": "type CLAUDE.md"}}, 2),
    ("use Grep", {"tool_name": "Grep", "tool_input": {"pattern": "x"}}, 2),
    ("glob in the inbox folder with a relative pattern", {"tool_name": "Glob", "tool_input": {"path": "review/inbox", "pattern": "**/*.png"}}, 0),
    ("glob in the inbox folder with an absolute pattern outside", {"tool_name": "Glob", "tool_input": {"path": "review/inbox", "pattern": os.path.join(ROOT, "*.md")}}, 2),
    ("glob in the inbox folder with a drive pattern", {"tool_name": "Glob", "tool_input": {"path": "review/inbox", "pattern": "C:/Users/**"}}, 2),
    ("glob in the inbox folder with a rooted pattern", {"tool_name": "Glob", "tool_input": {"path": "review/inbox", "pattern": "/c/Users/stewa/**"}}, 2),
]


def run(payload, cwd):
    data = payload if isinstance(payload, str) else json.dumps(payload)
    r = subprocess.run(["node", GUARD], input=data, capture_output=True, text=True, cwd=cwd, timeout=30)
    return r.returncode


def main():
    failures = 0
    # Run from the repo AND from an unrelated folder: the verdict must not depend on the cwd.
    for cwd in (ROOT, os.path.dirname(ROOT)):
        for label, payload, want in CASES:
            got = run(payload, cwd)
            ok = got == want
            failures += 0 if ok else 1
            print(f"{'PASS' if ok else 'FAIL'} [{os.path.basename(cwd)}] {label}: exit {got}, want {want}")
    got = run("this is not json", ROOT)
    ok = got == 2
    failures += 0 if ok else 1
    print(f"{'PASS' if ok else 'FAIL'} malformed input blocks (fail closed): exit {got}, want 2")
    print("guard:", "ok" if failures == 0 else f"FAIL ({failures})")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
