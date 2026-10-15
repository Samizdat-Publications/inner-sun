"""Waveform contact sheet of game/assets/audio -> harness/out/audio_preview.png."""
import glob
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [os.path.join(HERE, "..", "..", "tools")]
import paths  # noqa: E402
import matplotlib  # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

files = sorted(glob.glob(os.path.join(paths.GAME, "assets", "audio", "*.ogg")))
cols = 4; rows = (len(files) + cols - 1) // cols
fig, axs = plt.subplots(rows, cols, figsize=(20, rows * 1.6)); axs = axs.ravel()
for ax, f in zip(axs, files):
    x = np.frombuffer(subprocess.run([paths.ffmpeg(), "-v", "error", "-i", f, "-f", "f32le", "-ac", "1", "-ar", "44100", "-"],
                                     capture_output=True).stdout, dtype=np.float32)
    n = os.path.basename(f)[:-4]; k = max(1, len(x) // 1500)
    m = x[: len(x) // k * k].reshape(-1, k)
    ax.fill_between(np.arange(len(m)), m.min(1), m.max(1), color="k", lw=0)
    e = int(.01 * 44100); mean = np.abs(x).mean() + 1e-9
    st = "ends %.2f/%.2f" % (np.abs(x[:e]).mean() / mean, np.abs(x[-e:]).mean() / mean) if n.endswith("_loop") else ""
    ax.set_title("%s %.1fs pk%.2f %s" % (n, len(x) / 44100, np.abs(x).max(), st), fontsize=8)
    ax.set_ylim(-1.05, 1.05); ax.set_xticks([]); ax.set_yticks([])
for ax in axs[len(files):]:
    ax.axis("off")
plt.tight_layout()
out = os.path.join(paths.OUT, "audio_preview.png")
plt.savefig(out, dpi=70)
print(out)
