"""Gemini blind critic: the milestone-gate critic that sees real motion and hears the sound.

    python tools/critic_gemini.py [--model MODEL] [--fps 2] [--dry-run]

Sends the video in review/inbox/video/ (first .mp4 found), a few stills, review/inbox/store_page.md
and perf.json to Gemini, using the persona and output format from the body of
.claude/agents/player-critic.md (read verbatim, never paraphrased). Saves the review to
review/critiques/NNN_gemini.md, appends a row (critic = gemini) to review/scores.csv, and logs the
paid call in docs/SPEND.md.

The API key comes from the environment (GEMINI_API_KEY, then GOOGLE_API_KEY), else it is parsed
from C:\\Users\\stewa\\ClaudeProjects\\Noclip\\.env inside this script. It is never printed.
Requires: pip install google-genai
"""
import argparse
import datetime as dt
import glob
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import critic  # noqa: E402  (shared helpers: numbering, scores, csv)

ROOT = critic.ROOT
INBOX = critic.INBOX
PERSONA_FILE = os.path.join(ROOT, ".claude", "agents", "player-critic.md")
SPEND = os.path.join(ROOT, "docs", "SPEND.md")
ENV_FILE = r"C:\Users\stewa\ClaudeProjects\Noclip\.env"

# Newest video-capable Pro model as of 2026-10 (the bare gemini-3-pro-preview now aliases it).
# Cheaper alternative for a smoke test: gemini-3.8-flash. Both are flags; nothing is auto-picked.
DEFAULT_MODEL = "gemini-3.1-pro-preview"
FALLBACK_MODEL = "gemini-2.5-pro"
# USD per 1M tokens (input, output); deliberately conservative, used only for the SPEND estimate.
PRICES = {"pro": (2.0, 12.0), "flash": (0.75, 3.75)}


def persona():
    text = open(PERSONA_FILE, encoding="utf-8").read()
    parts = text.split("---", 2)
    return parts[2].strip() if len(parts) == 3 else text


def load_key():
    """Environment first, then the Noclip .env. Returns the key or '' (never printed)."""
    for name in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
        v = os.environ.get(name, "").strip()
        if v:
            return v
    try:
        found = {}
        for line in open(ENV_FILE, encoding="utf-8-sig"):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            found[k.strip().removeprefix("export ").strip()] = v.strip().strip("'\"")
        for name in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
            if found.get(name):
                return found[name]
    except OSError:
        pass
    return ""


def find_inputs():
    vids = sorted(glob.glob(os.path.join(INBOX, "video", "*.mp4")))
    frames = sorted(glob.glob(os.path.join(INBOX, "frames", "*.png")))
    store = os.path.join(INBOX, "store_page.md")
    perf = os.path.join(INBOX, "perf.json")
    return (vids[0] if vids else None), frames, store, (perf if os.path.exists(perf) else None)


def video_seconds(path):
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import paths
        out = subprocess.run([paths.ffmpeg("ffprobe"), "-v", "error", "-show_entries", "format=duration",
                              "-of", "default=nw=1:nk=1", path], capture_output=True, text=True, timeout=30)
        return float(out.stdout.strip())
    except Exception:
        return None


def estimate_cost(model, seconds, fps, n_images):
    """Rough upper estimate: ~300 tokens per sampled frame plus audio, stills, text, 8k output."""
    secs = seconds or 60.0
    tin = int(secs * max(fps, 1.0) * 300 + secs * 32 + n_images * 1200 + 5000)
    tout = 8000
    pin, pout = PRICES["flash" if "flash" in model else "pro"]
    return tin, tout, tin / 1e6 * pin + tout / 1e6 * pout


INTRO = (
    "You are receiving the files directly instead of a folder, so ignore the part about reading "
    "review/inbox. Here is everything you get:\n"
    "1. store_page.md (below).\n2. perf.json (below).\n"
    "3. A gameplay video of someone playing the build. Judge motion (crew moving, fire, water, "
    "effects) from the video. If the video carries sound you can hear it and should judge Sound "
    "from it; if it is silent, write N/A for Sound.\n"
    "4. A few still frames from the same session (images after the video).\n"
    "There is no previous build to compare against, so write 'n/a, first review' under "
    "'Compared to last build'. Use exactly the output format from your instructions.\n\n"
)


def log_spend(model, out_name, tin, tout, cost):
    line = (f"| {dt.date.today().isoformat()} | Gemini ({model}) | video critic -> {out_name} | "
            f"{cost:.2f} (est, {tin} in / {tout} out tokens) |\n")
    with open(SPEND, "rb") as f:
        data = f.read()
    with open(SPEND, "a", encoding="utf-8", newline="\n") as f:
        if data and not data.endswith(b"\n"):
            f.write("\n")
        f.write(line)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", default=DEFAULT_MODEL, help=f"default {DEFAULT_MODEL}")
    ap.add_argument("--fps", type=float, default=2.0, help="video sampling rate sent to Gemini")
    ap.add_argument("--frames", type=int, default=4, help="how many stills to attach")
    ap.add_argument("--dry-run", action="store_true", help="print the plan and cost estimate, call nothing")
    a = ap.parse_args()

    clip, frames, store, perf = find_inputs()
    if not clip or not os.path.exists(store):
        print("critic_gemini: review/inbox needs video/*.mp4 and store_page.md; run tools/capture.py first")
        return 1
    n = max(0, min(a.frames, len(frames)))
    pick = [frames[int(i * (len(frames) - 1) / max(n - 1, 1))] for i in range(n)] if n > 1 else frames[:n]
    secs = video_seconds(clip)
    tin, tout, cost = estimate_cost(a.model, secs, a.fps, len(pick))
    print(f"critic_gemini: model {a.model}, video {os.path.basename(clip)} "
          f"({os.path.getsize(clip) / 1e6:.1f} MB, {secs and round(secs)}s), {len(pick)} stills, fps {a.fps}")
    print(f"critic_gemini: estimated {tin} in / {tout} out tokens, about ${cost:.2f}")
    print(f"critic_gemini: would save to {os.path.join(critic.CRIT_DIR, critic.next_number() + '_gemini.md')}")
    if a.dry_run:
        print("critic_gemini: dry run, nothing sent, nothing logged")
        return 0

    key = load_key()
    if not key:
        print("critic_gemini: no GEMINI_API_KEY / GOOGLE_API_KEY in the environment or the Noclip .env")
        return 1
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        print("critic_gemini: missing package, run: pip install google-genai")
        return 1
    client = genai.Client(api_key=key)

    f = client.files.upload(file=clip)
    t0 = time.time()
    while not f.state or f.state.name != "ACTIVE":
        if f.state and f.state.name == "FAILED":
            print("critic_gemini: video processing failed on Google's side")
            return 1
        if time.time() - t0 > 600:
            print("critic_gemini: video processing timed out")
            return 1
        time.sleep(5)
        f = client.files.get(name=f.name)

    store_txt = open(store, encoding="utf-8").read()
    perf_txt = open(perf, encoding="utf-8").read() if perf else "{}"
    contents = [types.Part(file_data=types.FileData(file_uri=f.uri, mime_type=f.mime_type),
                           video_metadata=types.VideoMetadata(fps=a.fps))]
    for p in pick:
        contents.append(types.Part.from_bytes(data=open(p, "rb").read(), mime_type="image/png"))
    contents.append(INTRO + f"--- store_page.md ---\n{store_txt}\n--- perf.json ---\n{perf_txt}\n")
    cfg = types.GenerateContentConfig(system_instruction=persona(), max_output_tokens=16384, temperature=0.7)

    model = a.model
    resp = None
    for attempt in range(2):
        try:
            resp = client.models.generate_content(model=model, contents=contents, config=cfg)
            if resp.text:
                break
        except Exception as e:
            print(f"critic_gemini: attempt {attempt + 1} on {model} failed ({type(e).__name__}: {str(e)[:200]})")
            if attempt == 0:
                time.sleep(10)
                if model == DEFAULT_MODEL and a.model == DEFAULT_MODEL:
                    model = FALLBACK_MODEL
                    print("critic_gemini: falling back to", model)
    try:
        client.files.delete(name=f.name)
    except Exception:
        pass
    if resp is None or not resp.text:
        print("critic_gemini: FAILED, no response from Gemini")
        return 1

    um = resp.usage_metadata
    rin = getattr(um, "prompt_token_count", 0) or 0
    rout = (getattr(um, "candidates_token_count", 0) or 0) + (getattr(um, "thoughts_token_count", 0) or 0)
    pin, pout = PRICES["flash" if "flash" in model else "pro"]
    real_cost = rin / 1e6 * pin + rout / 1e6 * pout

    text = critic.clean_review(resp.text)
    try:
        path, scores = critic.save_review("gemini", model, text)
    except ValueError as e:
        # Money was spent; keep the raw reply so it is not lost, and log the spend anyway.
        raw = os.path.join(critic.CRIT_DIR, f"{critic.next_number()}_gemini_UNPARSED.md")
        os.makedirs(critic.CRIT_DIR, exist_ok=True)
        open(raw, "w", encoding="utf-8", newline="\n").write(resp.text.strip() + "\n")
        log_spend(model, os.path.basename(raw), rin, rout, real_cost)
        print(f"critic_gemini: FAILED, {e}. Raw reply kept at {raw}")
        return 1
    log_spend(model, os.path.basename(path), rin, rout, real_cost)
    print(f"critic_gemini: saved {path} (about ${real_cost:.2f}, {rin} in / {rout} out tokens)")
    print("critic_gemini: scores " + critic.score_summary(scores))
    return 0


if __name__ == "__main__":
    sys.exit(main())
