"""Generate (ElevenLabs, falling back to synth), process and encode all sounds.
Usage: build.py [--synth-only] [--synth=name1,name2] [names...]
Raw ElevenLabs mp3s are cached in harness/out/audio_raw so reruns cost nothing."""
import hashlib
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.join(HERE, ".."), os.path.join(HERE, "..", "..", "tools")]
import common  # noqa: E402
import paths  # noqa: E402
import synth  # noqa: E402
from specs import S  # noqa: E402

ROOT = common.ROOT
OUT = os.path.join(ROOT, "game", "assets", "audio")
RAW = os.path.join(ROOT, "harness", "out", "audio_raw")
SR = 44100
URL = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"
USD_PER_SEC = 0.012  # rough estimate per requested second (plan-dependent)


def eleven(name, spec, key):
    import requests
    p = os.path.join(RAW, name + ".mp3")
    if os.path.exists(p):
        return p, spec["dur"] * USD_PER_SEC  # cached: cost of the original generation
    body = {"text": spec["prompt"], "duration_seconds": spec["dur"], "prompt_influence": 0.5,
            "model_id": "eleven_text_to_sound_v2"}
    if spec["loop"]:
        body["loop"] = True
    for attempt in range(3):
        r = requests.post(URL, headers={"xi-api-key": key, "Content-Type": "application/json"}, json=body, timeout=120)
        if r.status_code == 200:
            os.makedirs(RAW, exist_ok=True)
            with open(p, "wb") as f:
                f.write(r.content)
            return p, spec["dur"] * USD_PER_SEC
        print(f"  {name}: HTTP {r.status_code} {r.text[:120]!r} (attempt {attempt + 1})")
        if r.status_code in (401, 402, 403, 422):
            break
    return None, 0.0


def decode(path):
    cmd = [paths.ffmpeg(), "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, dtype=np.float32).astype(np.float64)


def process(x, spec):
    x = x - np.mean(x)
    if spec["loop"]:
        n = int(0.35 * SR) if len(x) > 3 * SR else int(0.2 * SR)
        L = len(x) - n
        fin = np.sin(np.linspace(0, np.pi / 2, n)); fout = np.cos(np.linspace(0, np.pi / 2, n))
        y = x[:L].copy()
        y[:n] = x[:n] * fin + x[L:] * fout
        x = y
    else:
        a = np.abs(x); idx = np.nonzero(a > a.max() * 0.01)[0]
        if len(idx):
            x = x[max(0, idx[0] - int(.005 * SR)): idx[-1] + int(.05 * SR)]
        f = min(int(.04 * SR), len(x) // 4)
        x[-f:] *= np.linspace(1, 0, f)
        x[:32] *= np.linspace(0, 1, 32)
    return x * (10 ** (-2 / 20) / np.abs(x).max())


def encode(x, name):
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, name + ".ogg")
    pcm = np.clip(x, -1, 1).astype("<f4").tobytes()
    subprocess.run([paths.ffmpeg(), "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", out], input=pcm, check=True)
    return out


def stats(x):
    rms = np.sqrt(np.mean(x ** 2))
    return dict(duration_s=round(len(x) / SR, 3), peak_dbfs=round(float(20 * np.log10(np.abs(x).max())), 2),
                rms_dbfs=round(float(20 * np.log10(rms + 1e-9)), 2))


def main():
    args = sys.argv[1:]
    synth_only = "--synth-only" in args
    fs = [a[8:].split(",") for a in args if a.startswith("--synth=")]
    force_synth = set(fs[0]) if fs else set()
    names = [a for a in args if not a.startswith("--")] or list(S)
    key = None if synth_only else common.get_key("ELEVENLABS_API_KEY", "ELEVEN_API_KEY", "XI_API_KEY")
    spent = 0.0; mani = {}
    for nm in names:
        spec = S[nm]; src = None
        if key and nm not in force_synth:
            p, c = eleven(nm, spec, key)
            if p:
                x = decode(p)
                src = dict(source="ElevenLabs", model="eleven_text_to_sound_v2", prompt=spec["prompt"],
                           duration_seconds_requested=spec["dur"], prompt_influence=0.5, loop_flag=spec["loop"],
                           output_format="mp3_44100_128")
                spent += c
        if src is None:
            synth.rng = np.random.default_rng(int(hashlib.md5(nm.encode()).hexdigest()[:8], 16))
            x = synth.synth(spec["kind"], spec["dur"] + (0.35 if spec["loop"] else 0.0))
            src = dict(source="synth.py", kind=spec["kind"], seed="md5(name)[:8]", sr=SR)
        y = process(x, spec)
        encode(y, nm)
        mani[nm] = dict(src, loop=spec["loop"], **stats(y))
        print(nm, mani[nm]["source"], mani[nm]["duration_s"], "s", mani[nm]["rms_dbfs"], "dB rms", flush=True)
    common.save_manifest("audio", dict(files=mani, estimated_spend_usd=round(spent, 2), encoder="libvorbis q5"))
    n11 = len([m for m in mani.values() if m["source"] == "ElevenLabs"])
    if False:  # spend is logged by hand in docs/SPEND.md (cache makes reruns free)
        common.log_spend("ElevenLabs sound-generation", f"{n11} placeholder SFX, pipeline/audio/build.py (step 6)", spent)
    print("spent est", round(spent, 2))


main()
