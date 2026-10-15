"""Fast project check: import, then the headless test runner, then a headless --selftest.

    python tools/check.py [--only <substr>] [--no-import]

Prints engine/script errors, every TEST FAIL line and the TESTS line, then `check: ok` or
`check: FAIL (<reasons>)`. The full combined log goes to harness/out/check/last.log. Exit 0 or 1.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import proc  # noqa: E402


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None, help="run only tests whose id contains this substring")
    ap.add_argument("--no-import", action="store_true")
    a = ap.parse_args(argv)
    try:
        proc.require_game()
    except proc.ToolError as e:
        print("check: FAIL (" + str(e) + ")")
        return 1
    reasons, full = [], []
    if not a.no_import:
        r = proc.import_project(900)
        full.append("=== import (exit %d, %.0fs)\n%s" % (r.returncode, r.seconds, r.out))
        if r.timed_out:
            reasons.append("import timed out")
        elif r.returncode != 0:
            reasons.append(f"import exit {r.returncode}")
    targs = ["--headless", "--path", paths.GAME, "--script", "res://tests/runner.gd"]
    if a.only:
        targs += ["--", f"--only={a.only}"]
    r2 = proc.run_godot(targs, 900, log_name="check_tests")
    full.append("=== tests (exit %d, %.0fs)\n%s" % (r2.returncode, r2.seconds, r2.out))
    if r2.timed_out:
        reasons.append("test runner timed out")
    tests_line = next((l.strip() for l in r2.out.splitlines() if l.startswith("TESTS ")), None)
    fails = [l.strip() for l in r2.out.splitlines() if l.startswith("TEST FAIL")]
    m = re.search(r"failed=(\d+)", tests_line or "")
    if tests_line is None:
        reasons.append("no TESTS line (runner missing or crashed)")
    elif m and int(m.group(1)) > 0:
        reasons.append(f"{m.group(1)} test(s) failed")
    elif r2.returncode != 0:
        reasons.append(f"test runner exit {r2.returncode}")
    r3 = proc.run_godot(["--headless", "--path", paths.GAME, "--quit-after", "600", "--", "--selftest"], 900,
                        log_name="check_selftest")
    full.append("=== selftest (exit %d, %.0fs)\n%s" % (r3.returncode, r3.seconds, r3.out))
    st = [l.strip() for l in r3.out.splitlines() if l.startswith("SELFTEST")]
    if r3.timed_out:
        reasons.append("selftest timed out")
    elif "SELFTEST ok" not in st:
        reasons.append("selftest: " + (st[0] if st else "no SELFTEST line"))
    elif r3.returncode != 0:
        reasons.append(f"selftest exit {r3.returncode}")
    bad = proc.bad_lines("\n".join(full))
    if bad:
        reasons.append(f"{len(bad)} error line(s)")
    d = os.path.join(paths.OUT, "check")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "last.log"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(full))
    for l in bad:
        print(l)
    for l in fails:
        print(l)
    if tests_line:
        print(tests_line)
    for l in st:
        print(l)
    print("check: ok" if not reasons else "check: FAIL (" + "; ".join(reasons) + ")")
    return 0 if not reasons else 1


if __name__ == "__main__":
    sys.exit(main())
