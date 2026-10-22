"""Unit test for tools/ledger.py on a small sample ledger, plus a format check of the real one.

    python tools/test_ledger.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ledger  # noqa: E402

SAMPLE = """# Sample
**Scope:** Stewart picked inventory 1 to 2, so the L-AAA and L-BBB rows are in scope.

### L-<SYS>-<nn>: <one-line claim>
- Kind: number | shape | rule | feel

### L-AAA-01: first
- Kind: rule
- Behavior: b
- Target: t
- Evidence: E-AAA-01 (documented), wiki
- Test: x
- Wrong value: w
- Core: yes
- Status: passing

### L-AAA-02: second
- Kind: shape
- Behavior: b
- Target: t
- Evidence: E-AAA-02 (documented), wiki
- Test: x
- Wrong value: w
- Core: no
- Status: open

### L-AAA-F1: feel
- Kind: feel
- Behavior: b
- Target: t
- Evidence: E-AAA-F1 (assumed), observation
- Test: x
- Wrong value: w
- Core: no
- Status: open

### L-BBB-01: waived one
- Kind: rule
- Behavior: b
- Target: t
- Evidence: E-BBB-01 (documented), wiki
- Test: x
- Wrong value: w
- Core: yes
- Status: waived (D099)

### L-BBB-02: failing core
- Kind: number
- Behavior: b
- Target: t
- Evidence: E-BBB-02 (documented), wiki
- Test: x
- Wrong value: w
- Core: yes
- Status: failing

### L-CCC-01: out of scope
- Kind: rule
- Behavior: b
- Target: t
- Evidence: E-CCC-01 (documented), wiki
- Test: x
- Wrong value: w
- Core: no
- Status: passing
"""

failures = []


def check(cond: bool, what: str) -> None:
    if not cond:
        failures.append(what)


rows = ledger.parse(SAMPLE)
check(len(rows) == 6, "six rows parsed (the format template is skipped)")
check(ledger.scope(SAMPLE) == ["AAA", "BBB"], "scope read from the scope sentence")
cov = {c["system"]: c for c in ledger.coverage(rows, ["AAA", "BBB"])}
check(cov["AAA"]["in_scope"] == 2 and cov["AAA"]["passing"] == 1, "feel rows are not in scope")
check(abs(cov["AAA"]["coverage"] - 0.5) < 1e-9 and not cov["AAA"]["parity"], "50% is not parity")
check(cov["BBB"]["in_scope"] == 1 and cov["BBB"]["waived"] == 1, "waived rows leave the scope")
check(cov["BBB"]["failing_core"] == ["L-BBB-02"] and not cov["BBB"]["parity"], "failing core row blocks parity")
all_pass = ledger.coverage(ledger.parse(SAMPLE.replace("Status: open", "Status: passing")), ["AAA"])[0]
check(all_pass["parity"], "all passing is parity")

# Wrong values: each malformed ledger must be refused.
for label, bad in [
    ("a missing field", SAMPLE.replace("- Wrong value: w\n- Core: yes\n- Status: passing", "- Core: yes\n- Status: passing", 1)),
    ("an unknown kind", SAMPLE.replace("- Kind: rule", "- Kind: vibe", 1)),
    ("a waived row without a decision", SAMPLE.replace("waived (D099)", "waived")),
    ("a duplicate id", SAMPLE.replace("L-AAA-02: second", "L-AAA-01: second")),
    ("an unknown status", SAMPLE.replace("Status: failing", "Status: maybe")),
]:
    try:
        ledger.parse(bad)
        failures.append("%s was accepted" % label)
    except ledger.LedgerError:
        pass

# The real ledger must parse.
try:
    real = open(ledger.LEDGER, encoding="utf-8").read()
    real_rows = ledger.parse(real)
    check(len(real_rows) > 0 and len(ledger.scope(real)) == 6, "the real ledger parses with six systems in scope")
except ledger.LedgerError as e:
    failures.append("real ledger: %s" % e)

if failures:
    print("test_ledger: FAIL\n  " + "\n  ".join(failures))
    sys.exit(1)
print("test_ledger: ok")
