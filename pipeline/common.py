"""Shared helpers for the asset pipeline: key loading (never printed), manifests, spend log."""
import datetime
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ENV_FILE = r"C:\Users\stewa\ClaudeProjects\Noclip\.env"


def get_key(*names):
    """Return the first key found: environment first, then the shared .env file. Never prints it."""
    for n in names:
        v = os.environ.get(n)
        if v:
            return v.strip()
    if os.path.exists(ENV_FILE):
        with open(ENV_FILE, encoding="utf-8") as f:
            for line in f:
                m = re.match(r"\s*(?:export\s+)?([A-Za-z0-9_]+)\s*=\s*(.*)$", line)
                if m and m.group(1) in names:
                    return m.group(2).strip().strip('"').strip("'")
    return None


def save_manifest(name, data):
    d = os.path.join(ROOT, "pipeline", "manifests")
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, name + ".json")
    old = []
    if os.path.exists(p):
        try:
            old = json.load(open(p, encoding="utf-8")).get("runs", [])
        except Exception:
            old = []
    data = dict(data)
    data["date"] = datetime.date.today().isoformat()
    old.append(data)
    with open(p, "w", encoding="utf-8") as f:
        json.dump({"asset": name, "runs": old}, f, indent=2)


def log_spend(service, purpose, usd):
    p = os.path.join(ROOT, "docs", "SPEND.md")
    with open(p, "a", encoding="utf-8") as f:
        f.write(f"| {datetime.date.today().isoformat()} | {service} | {purpose} | {usd:.2f} |\n")
