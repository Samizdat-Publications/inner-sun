"""Progress pictures: a permanent visual record of development.

    python tools/progress.py <image> --label name --note "what it shows"

save() writes docs/progress/NNN_<label>.jpg (JPEG q85, max width 1920, NNN = next number) and
appends a line to docs/progress/INDEX.md.
"""
import argparse
import datetime as dt
import glob
import os
import re
import subprocess

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PROG = os.path.join(ROOT, "docs", "progress")
INDEX = os.path.join(PROG, "INDEX.md")


def _next_number():
    nums = [int(m.group(1)) for f in glob.glob(os.path.join(PROG, "*.jpg"))
            if (m := re.match(r"(\d+)_", os.path.basename(f)))]
    return max(nums, default=0) + 1


def _slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:60] or "image"


def _git():
    try:
        return subprocess.check_output(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"], text=True,
                                       stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "-"


def save(img, label, note=""):
    """img: PIL image or a path. Returns the saved file path."""
    if isinstance(img, (str, os.PathLike)):
        img = Image.open(img)
    os.makedirs(PROG, exist_ok=True)
    img = img.convert("RGB")
    if img.width > 1920:
        img = img.resize((1920, round(img.height * 1920 / img.width)), Image.LANCZOS)
    n = _next_number()
    name = f"{n:03d}_{_slug(label)}.jpg"
    path = os.path.join(PROG, name)
    img.save(path, quality=85)
    if not os.path.exists(INDEX):
        with open(INDEX, "w", encoding="utf-8", newline="\n") as f:
            f.write("# Progress pictures\n\nA visual record of Inner Sun, oldest first.\n\n"
                    "| # | When | Image | What it shows | Commit |\n|---|---|---|---|---|\n")
    with open(INDEX, "a", encoding="utf-8", newline="\n") as f:
        f.write(f"| {n:03d} | {dt.datetime.now():%Y-%m-%d %H:%M} | [{name}]({name}) | {note or label} | {_git()} |\n")
    print("progress:", name)
    return path


def grid(paths, cols=3, cell=(640, 360)):
    rows = (len(paths) + cols - 1) // cols
    g = Image.new("RGB", (cell[0] * cols, cell[1] * rows))
    for i, p in enumerate(paths):
        im = p if isinstance(p, Image.Image) else Image.open(p)
        g.paste(im.convert("RGB").resize(cell, Image.LANCZOS), ((i % cols) * cell[0], (i // cols) * cell[1]))
    return g


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--label", default=None)
    ap.add_argument("--note", default="")
    a = ap.parse_args()
    save(a.image, a.label or os.path.splitext(os.path.basename(a.image))[0], a.note)


if __name__ == "__main__":
    main()
