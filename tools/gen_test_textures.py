"""Placeholder art (ours, CC0) for game/assets/test/: tileable rock and wall, a reactor vessel sprite.

    python tools/gen_test_textures.py

Normal maps are OpenGL style (green = +Y up) derived from a height map with a Sobel filter.
Previews (3x3 tiled) go to harness/out/textures/.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402

DEST = os.path.join(paths.GAME, "assets", "test")
PREV = os.path.join(paths.OUT, "textures")
RNG = np.random.default_rng(20261015)


def noise(h, w, beta=1.6, lo=1, hi=None, rng=RNG):
    """Periodic 1/f^beta noise (tiles seamlessly), normalized to 0..1."""
    f = rng.standard_normal((h, w))
    F = np.fft.rfft2(f)
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.rfftfreq(w)[None, :] * w
    r = np.sqrt(fx ** 2 + fy ** 2)
    filt = np.where(r < lo, 0.0, 1.0 / np.maximum(r, 1e-6) ** beta)
    if hi:
        filt = filt * (r <= hi)
    n = np.fft.irfft2(F * filt, s=(h, w))
    n -= n.min()
    return n / max(n.max(), 1e-9)


def smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def sobel_wrap(h):
    """Wrap-around Sobel gradients (dx along columns, dy along rows)."""
    r = np.roll
    dx = (r(h, -1, 1) - r(h, 1, 1)) * 2 + (r(r(h, -1, 1), -1, 0) - r(r(h, 1, 1), -1, 0)) + (r(r(h, -1, 1), 1, 0) - r(r(h, 1, 1), 1, 0))
    dy = (r(h, -1, 0) - r(h, 1, 0)) * 2 + (r(r(h, -1, 0), -1, 1) - r(r(h, 1, 0), -1, 1)) + (r(r(h, -1, 0), 1, 1) - r(r(h, 1, 0), 1, 1))
    return dx / 8.0, dy / 8.0


def sobel_edge(h):
    p = np.pad(h, 1, mode="edge")
    dx = ((p[1:-1, 2:] - p[1:-1, :-2]) * 2 + (p[:-2, 2:] - p[:-2, :-2]) + (p[2:, 2:] - p[2:, :-2])) / 8.0
    dy = ((p[2:, 1:-1] - p[:-2, 1:-1]) * 2 + (p[2:, :-2] - p[:-2, :-2]) + (p[2:, 2:] - p[:-2, 2:])) / 8.0
    return dx, dy


def normal_from(dx, dy, strength):
    """Image rows go down, so 'up' is -row: n = (-dh/dx, +dh/drow, 1) gives green = +Y up."""
    nx, ny, nz = -dx * strength, dy * strength, np.ones_like(dx)
    ln = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    return np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5


def save_rgb(a, name, mode="RGB"):
    os.makedirs(DEST, exist_ok=True)
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), mode).save(os.path.join(DEST, name))


def periodic_voronoi_edges(n, pts, rng):
    p = rng.random((pts, 2)) * n
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d1 = np.full((n, n), 1e9, np.float32)
    d2 = d1.copy()
    for py, px in p:
        dy = np.abs(yy - py)
        dx = np.abs(xx - px)
        d = np.sqrt(np.minimum(dy, n - dy) ** 2 + np.minimum(dx, n - dx) ** 2)
        d2 = np.minimum(d2, np.maximum(d1, d))
        d1 = np.minimum(d1, d)
    return d2 - d1


def make_rock(n=512):
    rng = np.random.default_rng(11)
    big = noise(n, n, 1.8, rng=rng)
    mid = noise(n, n, 1.2, lo=4, rng=rng)
    fine = noise(n, n, 0.7, lo=16, rng=rng)
    yy = np.arange(n)[:, None] / n
    warp = noise(n, n, 2.2, hi=6, rng=rng)
    strata = 0.5 + 0.5 * np.sin(2 * np.pi * (9 * yy + 0.55 * warp + 0.05 * mid))
    band = 0.5 + 0.5 * np.sin(2 * np.pi * (4 * yy + 3.0 * warp))
    cmask = smooth(noise(n, n, 1.6, lo=1, hi=5, rng=rng), 0.45, 0.62)
    cracks = (1.0 - smooth(periodic_voronoi_edges(n, 14, rng) + 8.0 * (noise(n, n, 1.0, lo=3, rng=rng) - 0.5), 0.0, 2.2)) * cmask
    h = 0.50 * big + 0.28 * mid + 0.12 * fine + 0.06 * strata - 0.30 * cracks
    h = (h - h.min()) / (h.max() - h.min())
    base = np.array([0.24, 0.20, 0.17])
    grey = np.array([0.30, 0.29, 0.28])
    mix = smooth(0.7 * mid + 0.3 * fine, 0.25, 0.8)[..., None]
    col = base * (1 - mix) + grey * mix
    col = col * (0.55 + 0.7 * h[..., None])
    col = col * (1.0 - 0.07 * strata[..., None])           # faint strata
    col = col * (1.0 - 0.7 * cracks[..., None])            # dark cracks
    col = col + 0.025 * (fine[..., None] - 0.5)
    dx, dy = sobel_wrap(h)
    save_rgb(col, "rock_albedo.png")
    save_rgb(normal_from(dx, dy, 5.0), "rock_normal.png")
    return col, normal_from(dx, dy, 5.0)


def make_wall(n=256):
    rng = np.random.default_rng(23)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    panel = n // 2  # 2x2 panels, seams on the tile edge and in the middle (tileable)
    px, py = xx % panel, yy % panel
    dseam = np.minimum(np.minimum(px, panel - 1 - px), np.minimum(py, panel - 1 - py))  # distance to nearest seam
    groove = 1.0 - smooth(dseam, 0.0, 3.0)
    inset = 1.0 - smooth(dseam, 3.0, 9.0)
    # rivets every 32 px, 9 px in from the seams
    rivet = np.zeros((n, n), np.float32)
    # simple explicit rivet placement: along the four seam-inset lines, every 24 px
    for k in range(n // 24 + 1):
        t = 12 + 24 * k
        for line in (9, panel - 10, panel + 9, n - 10):
            for (cxp, cyp) in ((line, t), (t, line)):
                d = np.sqrt((((xx - cxp + n / 2) % n) - n / 2) ** 2 + (((yy - cyp + n / 2) % n) - n / 2) ** 2)
                rivet = np.maximum(rivet, np.clip(1 - d / 3.2, 0, 1) ** 0.6)
    wear = noise(n, n, 1.4, lo=2, rng=rng)
    fine = noise(n, n, 0.6, lo=12, rng=rng)
    rustn = noise(n, n, 1.5, lo=2, rng=rng)
    rust = smooth(rustn + 0.22 * (groove + inset * 0.3 + rivet * 0.6) - 0.66, 0.0, 0.22)
    scratch = np.clip(noise(n, n, 0.2, lo=20, rng=rng) - 0.82, 0, 1) * 5
    h = -1.0 * groove - 0.25 * inset + 0.7 * rivet + 0.06 * fine + 0.08 * rust * wear
    olive = np.array([0.36, 0.38, 0.30])
    col = olive * (0.82 + 0.3 * wear[..., None]) * (0.9 + 0.2 * fine[..., None])
    col = col * (1 - 0.45 * groove[..., None]) * (1 - 0.12 * inset[..., None]) + 0.07 * rivet[..., None]
    rustc = np.array([0.46, 0.22, 0.10]) * (0.7 + 0.5 * fine[..., None])
    col = col * (1 - rust[..., None]) + rustc * rust[..., None]
    col = col + 0.12 * np.clip(scratch, 0, 1)[..., None] * (1 - rust[..., None])
    dx, dy = sobel_wrap(h)
    nrm = normal_from(dx, dy, 1.6)
    save_rgb(col, "wall_albedo.png")
    save_rgb(nrm, "wall_normal.png")
    return col, nrm


def sd_box(x, y, cx, cy, hw, hh, r=0.0):
    qx, qy = np.abs(x - cx) - (hw - r), np.abs(y - cy) - (hh - r)
    return np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2) + np.minimum(np.maximum(qx, qy), 0) - r


def sd_ellipse(x, y, cx, cy, rx, ry):
    k = np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
    return (k - 1.0) * min(rx, ry)


def sd_seg(x, y, ax, ay, bx, by, r):
    pax, pay, bax, bay = x - ax, y - ay, bx - ax, by - ay
    t = np.clip((pax * bax + pay * bay) / (bax ** 2 + bay ** 2), 0, 1)
    return np.sqrt((pax - bax * t) ** 2 + (pay - bay * t) ** 2) - r


def make_reactor(w=256, h=320):
    rng = np.random.default_rng(31)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    col = np.zeros((h, w, 3), np.float32)
    ht = np.zeros((h, w), np.float32)
    alpha = np.zeros((h, w), np.float32)
    grain = noise(h, w, 0.8, lo=8, rng=rng)

    def paint(sd, color, depth, round_r=None, shade=True):
        cov = np.clip(0.5 - sd, 0, 1)  # 1 px antialias on the silhouette
        t = np.clip(-sd / (round_r or 6.0), 0, 1)
        prof = np.sqrt(1 - (1 - t) ** 2)
        c = np.array(color, np.float32)[None, None, :] * (0.85 + 0.3 * grain[..., None])
        if shade:
            c = c * (0.55 + 0.6 * prof[..., None])
        a = cov[..., None]
        col[:] = col * (1 - a) + c * a
        ht[:] = np.where(cov > 0.5, depth * prof, ht)
        alpha[:] = np.maximum(alpha, cov)

    # pipes behind the vessel
    paint(sd_seg(xx, yy, 14, 232, 70, 232, 8), (0.30, 0.31, 0.27), 5, 8)
    paint(sd_seg(xx, yy, 14, 232, 14, 150, 8), (0.30, 0.31, 0.27), 5, 8)
    paint(sd_seg(xx, yy, 14, 150, 44, 150, 6), (0.33, 0.30, 0.22), 4, 6)
    paint(sd_seg(xx, yy, 176, 100, 176, 22, 7), (0.31, 0.32, 0.28), 5, 7)
    paint(sd_seg(xx, yy, 176, 22, 236, 22, 7), (0.31, 0.32, 0.28), 5, 7)
    paint(sd_box(xx, yy, 236, 40, 8, 26, 3), (0.22, 0.23, 0.2), 4, 4)
    # plinth, body, caps
    paint(sd_box(xx, yy, 128, 290, 98, 18, 4), (0.20, 0.21, 0.19), 7, 8)
    body = sd_box(xx, yy, 128, 190, 74, 100, 3)
    paint(np.minimum(body, sd_ellipse(xx, yy, 128, 92, 74, 20)), (0.38, 0.40, 0.33), 14, 74)
    paint(sd_ellipse(xx, yy, 128, 276, 74, 14), (0.30, 0.32, 0.27), 12, 14)
    # top dome / lid
    paint(sd_ellipse(xx, yy, 128, 92, 54, 12), (0.45, 0.47, 0.40), 10, 12)
    paint(sd_box(xx, yy, 128, 70, 18, 14, 4), (0.28, 0.30, 0.26), 8, 8)
    # bands with bolts
    for by_ in (130, 190, 246):
        paint(sd_box(xx, yy, 128, by_, 77, 7, 2), (0.24, 0.25, 0.22), 18, 7)
        for k in range(-5, 6):
            u = k / 5.5
            bx = 128 + 70 * np.sin(u * 1.25) / np.sin(1.25)
            paint(np.sqrt((xx - bx) ** 2 + (yy - by_) ** 2) - 2.6, (0.55, 0.52, 0.42), 22, 2.6)
    # rust streaks and olive/grey wear on the body
    streak = np.clip(noise(h, w, 1.3, lo=2, rng=rng) - 0.55, 0, 1) * 2.2
    inside = alpha > 0.5
    rust = (streak * inside)[..., None]
    col[:] = col * (1 - 0.7 * rust) + np.array([0.42, 0.2, 0.09]) * 0.7 * rust
    # window (porthole): bright rim, glowing teal-amber glass
    d = np.sqrt((xx - 128) ** 2 + (yy - 165) ** 2)
    paint(d - 23, (0.58, 0.55, 0.45), 26, 4)
    glass = d < 16
    g = np.clip(1 - d / 16, 0, 1)[..., None]
    gc = np.array([0.15, 0.55, 0.50]) * (1 - g) + np.array([1.0, 0.72, 0.30]) * g
    col[:] = np.where(glass[..., None], gc, col)
    ht[:] = np.where(glass, 18 - 4 * np.clip(1 - d / 16, 0, 1), ht)
    # lighting baked lightly (top-left key)
    lx = 1.0 - 0.18 * (xx / w)
    col[:] = col * lx[..., None]
    col[:] = np.where(glass[..., None], gc * 1.1, col)
    # alpha-aware bevel: blur the coverage so normals roll off at the silhouette
    bevel = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3.0)), np.float32) / 255
    hfin = ht * 0.5 + bevel * 14.0
    p = np.pad(hfin, 1, mode="edge")
    hfin = (p[:-2, 1:-1] + 2 * p[1:-1, 1:-1] + p[2:, 1:-1]) / 4
    p = np.pad(hfin, 1, mode="edge")
    hfin = (p[1:-1, :-2] + 2 * p[1:-1, 1:-1] + p[1:-1, 2:]) / 4
    dx, dy = sobel_edge(hfin)
    nrm = normal_from(dx, dy, 0.9)
    flat = np.array([0.5, 0.5, 1.0])
    nrm = nrm * (alpha[..., None] > 0.01) + flat * (alpha[..., None] <= 0.01)
    os.makedirs(DEST, exist_ok=True)
    a8 = (np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8)
    for name, rgb in (("reactor_albedo.png", col), ("reactor_normal.png", nrm)):
        im = np.dstack([(np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), a8])
        Image.fromarray(im, "RGBA").save(os.path.join(DEST, name))
    return col, nrm, alpha


def tile3(a):
    return np.tile(a, (3, 3, 1))


def main():
    os.makedirs(PREV, exist_ok=True)
    rc, rn = make_rock()
    wc, wn = make_wall()
    col, nrm, alpha = make_reactor()
    for name, arr in (("preview_rock_albedo.png", rc), ("preview_rock_normal.png", rn),
                      ("preview_wall_albedo.png", wc), ("preview_wall_normal.png", wn)):
        Image.fromarray((np.clip(tile3(arr), 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(PREV, name))
    # Reactor previews composited on a mid-grey background, albedo and normal side by side.
    bg = np.full(col.shape, 0.18)
    a = alpha[..., None]
    both = np.concatenate([col * a + bg * (1 - a), nrm * a + bg * (1 - a)], axis=1)
    Image.fromarray((np.clip(both, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(PREV, "preview_reactor.png"))
    for f in sorted(os.listdir(DEST)):
        if f.endswith(".png"):
            im = Image.open(os.path.join(DEST, f))
            print(f, im.size, im.mode)
    print("previews in", PREV)


if __name__ == "__main__":
    main()
