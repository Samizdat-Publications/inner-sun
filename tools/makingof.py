"""Making-of clips: short labeled videos of milestones for the "making of" page (Stewart's request).

    python tools/makingof.py clip --label drill-greybox --note "first drilling segment" [--src <mp4>]
                                  [--start 0] [--dur 20]

Cuts --dur seconds from --src (default: the clip in review/inbox/video/clip.mp4, the latest capture),
encodes 1280x720 H.264 (CRF 28, no audio unless the source has it), saves
docs/making-of/clips/NNN_<label>.mp4 and appends a line to docs/making-of/clips/INDEX.md.
Add the matching timeline row to docs/making-of/README.md by hand (the story is written, not generated).
"""
import argparse
import datetime as dt
import glob
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402

CLIPS = os.path.join(paths.ROOT, "docs", "making-of", "clips")
INDEX = os.path.join(CLIPS, "INDEX.md")


def _next_number():
    nums = [int(m.group(1)) for f in glob.glob(os.path.join(CLIPS, "*.mp4"))
            if (m := re.match(r"(\d+)_", os.path.basename(f)))]
    return max(nums, default=0) + 1


def _slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:60] or "clip"


def _git_hash():
    try:
        return subprocess.check_output(["git", "-C", paths.ROOT, "rev-parse", "--short", "HEAD"], text=True,
                                       stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "nogit"


def clip(src, label, note, start, dur):
    if not os.path.exists(src):
        print(f"makingof: source not found: {src}")
        return 1
    os.makedirs(CLIPS, exist_ok=True)
    name = f"{_next_number():03d}_{_slug(label)}.mp4"
    out = os.path.join(CLIPS, name)
    cmd = [paths.ffmpeg(), "-v", "error", "-y", "-ss", str(start), "-t", str(dur), "-i", src,
           "-vf", "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2",
           "-c:v", "libx264", "-preset", "slow", "-crf", "28", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
           "-c:a", "aac", "-b:a", "96k", out]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        print("makingof: ffmpeg failed:", r.stderr.strip()[-400:])
        return 1
    mb = os.path.getsize(out) / 1e6
    if not os.path.exists(INDEX):
        with open(INDEX, "w", encoding="utf-8", newline="\n") as f:
            f.write("# Making-of clips\n\nShort labeled clips, oldest first.\n\n| # | When | Clip | What it shows | Commit |\n|---|---|---|---|---|\n")
    with open(INDEX, "a", encoding="utf-8", newline="\n") as f:
        f.write(f"| {name[:3]} | {dt.datetime.now():%Y-%m-%d %H:%M} | [{name}]({name}) | {note} | {_git_hash()} |\n")
    print(f"makingof: {name} ({mb:.1f} MB)")
    if mb > 4.5:
        print("makingof: WARNING over the 4 MB guideline; use a shorter --dur")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("clip")
    c.add_argument("--src", default=os.path.join(paths.REVIEW, "inbox", "video", "clip.mp4"))
    c.add_argument("--label", required=True)
    c.add_argument("--note", required=True)
    c.add_argument("--start", type=float, default=0.0)
    c.add_argument("--dur", type=float, default=20.0)
    a = ap.parse_args(argv)
    return clip(a.src, a.label, a.note, a.start, a.dur)


if __name__ == "__main__":
    sys.exit(main())
