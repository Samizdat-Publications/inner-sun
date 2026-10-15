"""One-command review capture.

    python tools/capture.py [--seed N] [--scenario fire_drill] [--duration 40] [--stills 12] [--sheets 3]
                            [--skip-perf] [--perf-seconds 10] [--perf-runs 3]

 1. import; 2. Movie Maker run (off-screen window, 1920x1080, 30 fps) that saves stills and 9-frame
 bursts; 3. perf via perf.py; 4. H.264 encode, then the AVI is deleted at once (disk is tight);
 5. review/inbox is wiped and refilled with neutral names only (frames, sheets, video, perf.json,
 store_page.md, previous/); 6. archive under review/archive/builds/<id>/, a progress contact sheet,
 and only the last 2 raw folders are kept.
"""
import argparse
import datetime as dt
import glob
import json
import os
import random
import shutil
import subprocess
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402
import perf  # noqa: E402
import proc  # noqa: E402
import progress  # noqa: E402

REVIEW = paths.REVIEW
INBOX = os.path.join(REVIEW, "inbox")
ARCH = os.path.join(REVIEW, "archive", "builds")
RAW = os.path.join(REVIEW, "archive", "raw")


def log(*a):
    print("[capture]", *a, flush=True)


def git_hash():
    try:
        return subprocess.check_output(["git", "-C", paths.ROOT, "rev-parse", "--short", "HEAD"], text=True,
                                       stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "nogit"


def count_frames(path):
    try:
        out = subprocess.run([paths.ffmpeg("ffprobe"), "-v", "error", "-count_frames", "-select_streams", "v:0",
                              "-show_entries", "stream=nb_read_frames", "-of", "csv=p=0", path],
                             capture_output=True, text=True, timeout=600).stdout.strip()
        return int(out.split(",")[0])
    except Exception:
        return None


def mean_luma(path):
    import numpy as np
    return float(np.asarray(Image.open(path).convert("L"), dtype=float).mean())


def sheet_from(files, out, w=1920, h=1080):
    cw, ch = w // 3, h // 3
    img = Image.new("RGB", (w, h), (0, 0, 0))
    for i, f in enumerate(files[:9]):
        img.paste(Image.open(f).convert("RGB").resize((cw, ch), Image.LANCZOS), ((i % 3) * cw, (i // 3) * ch))
    img.save(out)


def contact(files, cols=4, w=480, h=270):
    rows = (len(files) + cols - 1) // cols
    img = Image.new("RGB", (cols * w, rows * h))
    for i, f in enumerate(files):
        img.paste(Image.open(f).convert("RGB").resize((w, h), Image.LANCZOS), ((i % cols) * w, (i // cols) * h))
    return img


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--scenario", default="fire_drill")
    ap.add_argument("--duration", type=float, default=40.0)
    ap.add_argument("--stills", type=int, default=12)
    ap.add_argument("--sheets", type=int, default=3)
    ap.add_argument("--skip-perf", action="store_true")
    ap.add_argument("--perf-seconds", type=float, default=10.0)
    ap.add_argument("--perf-runs", type=int, default=3)
    ap.add_argument("--label", default="review-build")
    ap.add_argument("--note", default="")
    a = ap.parse_args(argv)
    try:
        proc.require_game()
        store = os.path.join(REVIEW, "store_page.md")
        if not os.path.exists(store):
            raise proc.ToolError(f"missing {store}")
    except proc.ToolError as e:
        print("capture: FAIL (" + str(e) + ")")
        return 1

    seed = a.seed if a.seed is not None else random.SystemRandom().randint(1, 999999)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    build_id = f"{stamp}-{git_hash()}"
    raw = os.path.join(RAW, build_id)
    os.makedirs(raw, exist_ok=True)
    log(f"build {build_id} seed {seed} scenario {a.scenario}")

    # 1. Import.
    r = proc.import_project(900)
    log(f"import: exit {r.returncode} in {r.seconds:.0f}s")

    # 2. Movie Maker run.
    movie = os.path.join(raw, "movie.avi")
    frames_total = int((a.duration + 6) * 30)
    args = ["--path", paths.GAME, "--resolution", "1920x1080", "--position", "-32000,-32000", "--write-movie", movie,
            "--fixed-fps", "30", "--disable-vsync", "--quit-after", str(frames_total), "--",
            f"--scenario={a.scenario}", f"--seed={seed}", f"--duration={a.duration}", f"--capture={raw}",
            f"--stills={a.stills}", f"--sheets={a.sheets}"]
    r = proc.run_godot(args, 3600, log_name="capture_movie")
    with open(os.path.join(raw, "movie_log.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(r.out)
    bad = proc.bad_lines(r.out)
    log(f"movie run: exit {r.returncode} in {r.seconds:.0f}s, timed_out={r.timed_out}, {len(bad)} error lines")
    for l in bad[:15]:
        log("   ", l)
    proc.gpu_warning(proc.adapter_from(r.out))
    stills = sorted(glob.glob(os.path.join(raw, "stills", "s_*.png")))
    if not stills or not os.path.exists(movie):
        print("capture: FAIL (no stills or no movie, see " + os.path.join(raw, "movie_log.txt") + ")")
        return 1

    # 3. Perf.
    perf_path = os.path.join(raw, "perf.json")
    if not a.skip_perf:
        pr = perf.measure(a.scenario, seed, a.perf_seconds, a.perf_runs)
        with open(perf_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(pr, f, indent=2)
        log(perf.summary(pr))

    # 4. Video, then delete the AVI right away. Frame count check first (ffprobe).
    expected = a.duration * 30
    n_avi = count_frames(movie)
    if n_avi is None or abs(n_avi - expected) > 0.02 * expected:
        if n_avi is not None and n_avi > expected:
            log(f"movie has {n_avi} frames, expected about {expected:.0f} (longer than the clip, trimmed to {a.duration}s)")
        else:
            log(f"WARNING: movie frame count {n_avi} is off from the expected {expected:.0f} by more than 2 percent")
    black = [os.path.basename(f) for f in stills if mean_luma(f) < 4]
    if black:
        log("WARNING: black stills (mean luminance under 4/255): " + ", ".join(black))
    clip = os.path.join(raw, "clip.mp4")
    e = subprocess.run([paths.ffmpeg(), "-y", "-loglevel", "error", "-i", movie, "-t", f"{a.duration:.2f}",
                        "-map", "0:v:0", "-map", "0:a?", "-vf", "scale=1920:1080:flags=lanczos", "-c:v", "libx264",
                           "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k",
                           "-movflags", "+faststart", clip], capture_output=True, text=True)
    if e.returncode != 0 or not os.path.exists(clip):
        print("capture: FAIL (ffmpeg: " + e.stderr.strip()[:300] + f"; the AVI was kept at {movie})")
        return 1
    os.remove(movie)
    n_clip = count_frames(clip)
    if n_clip is None or abs(n_clip - expected) > 0.02 * expected:
        log(f"WARNING: clip has {n_clip} frames, expected {expected:.0f} (off by more than 2 percent)")
    log(f"clip {os.path.getsize(clip) / 1e6:.1f} MB, AVI deleted")

    # 5. Previous build frames (before this build is archived), then the inbox.
    prev_builds = sorted(d for d in glob.glob(os.path.join(ARCH, "*")) if os.path.isdir(d))
    if os.path.exists(INBOX):
        shutil.rmtree(INBOX)
    for d in ("frames", "sheets", "video"):
        os.makedirs(os.path.join(INBOX, d))
    for i, f in enumerate(stills):
        shutil.copy(f, os.path.join(INBOX, "frames", f"frame_{i + 1:02d}.png"))
    bursts = sorted({os.path.basename(p)[:3] for p in glob.glob(os.path.join(raw, "sheets", "k*_f*.png"))})
    made = 0
    for k in bursts:
        fs = sorted(glob.glob(os.path.join(raw, "sheets", f"{k}_f*.png")))
        if len(fs) == 9:
            made += 1
            sheet_from(fs, os.path.join(INBOX, "sheets", f"sheet_{made:02d}.png"))
    shutil.copy(clip, os.path.join(INBOX, "video", "clip.mp4"))
    if os.path.exists(perf_path):
        shutil.copy(perf_path, os.path.join(INBOX, "perf.json"))
    shutil.copy(os.path.join(REVIEW, "store_page.md"), os.path.join(INBOX, "store_page.md"))
    if prev_builds:
        pf = sorted(glob.glob(os.path.join(prev_builds[-1], "frames", "*.png")))
        if pf:
            os.makedirs(os.path.join(INBOX, "previous"))
            step = max(1, len(pf) // 6)
            for i, f in enumerate(pf[::step][:6]):
                shutil.copy(f, os.path.join(INBOX, "previous", f"prev_{i + 1:02d}.png"))

    # 6. Archive.
    arch = os.path.join(ARCH, build_id)
    shutil.copytree(os.path.join(INBOX, "frames"), os.path.join(arch, "frames"))
    shutil.copytree(os.path.join(INBOX, "sheets"), os.path.join(arch, "sheets"))
    if os.path.exists(perf_path):
        shutil.copy(perf_path, arch)
    progress.save(contact(sorted(glob.glob(os.path.join(arch, "frames", "*.png")))), f"{a.label}-frames",
                  (a.note + "; " if a.note else "") + f"review frames, build {build_id}, seed {seed}")
    meta = {"build_id": build_id, "seed": seed, "scenario": a.scenario, "git": git_hash(), "date": stamp,
            "duration": a.duration, "stills": len(stills), "sheets": made, "clip_mb": round(os.path.getsize(clip) / 1e6, 1)}
    with open(os.path.join(arch, "meta.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, indent=2)
    # Only the build id and seed go into the inbox (tools/critic.py records them with the scores).
    with open(os.path.join(INBOX, "meta.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"build_id": build_id, "seed": seed}, f, indent=2)
    for d in sorted(d for d in glob.glob(os.path.join(RAW, "*")) if os.path.isdir(d))[:-2]:
        shutil.rmtree(d, ignore_errors=True)
    log(f"inbox ready: {len(stills)} frames, {made} sheets")
    print(json.dumps(meta))
    return 0


if __name__ == "__main__":
    sys.exit(main())
