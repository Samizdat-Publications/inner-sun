"""Normal maps (OpenGL, green = +Y up) from a flat albedo + alpha, for the pixel and painted bake-off styles.

The height field is built from three parts so the result reads as form under a moving light instead of a
noisy luminance emboss:
  1. silhouette bevel: rounded edge profile from the distance to transparency (props and characters),
  2. "cyl" inflation: optional horizontal cylinder profile for round machines (centre and radius given),
  3. detail: band-passed luminance (dark seams and ink lines go down, highlights go up), with a gain,
     weighted down inside flat areas by a local-contrast mask so gradients and noise stay quiet.
Normals are renormalised, transparent texels get the flat normal (128,128,255) with the colour of the nearest
opaque neighbour (no halo under linear filtering). `quant` snaps nx, ny to 1/quant steps for pixel art.
"""
import numpy as np
from scipy import ndimage as ndi


def luminance(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def bevel_height(alpha, radius, height, pad_edges=True):
    a = alpha > 0.5
    if pad_edges:  # an opaque rectangle (a wall) is not bevelled at the image border
        a = np.pad(a, 1, mode="edge")
    dt = ndi.distance_transform_edt(a)
    if pad_edges:
        dt = dt[1:-1, 1:-1]
    t = np.clip(dt / max(radius, 1e-3), 0, 1)
    prof = np.sqrt(1 - (1 - t) ** 2)
    return prof * height * (alpha > 0.5)


def cyl_height(alpha, cx, radius, height):
    xs = np.arange(alpha.shape[1], dtype=np.float32)[None, :]
    u = np.clip((xs - cx) / radius, -1, 1)
    h = np.sqrt(1 - u ** 2) * height
    return np.broadcast_to(h, alpha.shape) * (alpha > 0.5)


def detail_height(rgb, alpha, lo_sigma, hi_sigma, gain, contrast_floor=0.015):
    lum = luminance(rgb)
    band = ndi.gaussian_filter(lum, hi_sigma) - ndi.gaussian_filter(lum, lo_sigma)
    # keep texture but ignore tiny noise: soft threshold on local contrast
    cont = ndi.gaussian_filter(np.abs(band), 1.5)
    w = np.clip(cont / (contrast_floor * 4), 0, 1)
    return band * gain * w * (alpha > 0.5)


def bleed(rgb, a, iters=8):
    rgb = rgb.copy()
    known = a > 0.5
    for _ in range(iters):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(a.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            s = np.roll(np.roll(rgb, dy, 0), dx, 1)
            k = np.roll(np.roll(known, dy, 0), dx, 1)
            acc += s * k[..., None]
            cnt += k
        new = (~known) & (cnt > 0)
        rgb[new] = acc[new] / cnt[new][..., None]
        known = known | new
    return rgb


def normal_map(rgba, bevel_radius=4.0, bevel_height_px=2.0, cyl=None, detail_gain=3.0, detail_sigmas=(0.6, 3.0),
               slope=1.0, quant=0, smooth=0.0):
    """rgba: float array (h, w, 4) in 0..1. Returns uint8 (h, w, 4) normal map with the same alpha."""
    rgb = rgba[..., :3]
    a = rgba[..., 3]
    h = bevel_height(a, bevel_radius, bevel_height_px)
    if cyl is not None:
        h = h + cyl_height(a, cyl["cx"], cyl["radius"], cyl["height"])
    h = h + detail_height(rgb, a, detail_sigmas[1], detail_sigmas[0], detail_gain)
    if smooth > 0:
        h = ndi.gaussian_filter(h, smooth)
    dx = ndi.sobel(h, axis=1) / 8.0
    dy = ndi.sobel(h, axis=0) / 8.0
    nx = -dx * slope
    ny = dy * slope            # image y points down, +Y up in the normal map
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / ln, ny / ln, nz / ln
    if quant:
        nx = np.round(nx * quant) / quant
        ny = np.round(ny * quant) / quant
        nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0.05, 1))
        ln = np.sqrt(nx * nx + ny * ny + nz * nz)
        nx, ny, nz = nx / ln, ny / ln, nz / ln
    n = np.dstack([nx, ny, nz]) * 0.5 + 0.5
    n = bleed(n.astype(np.float32), a)
    n[a < 0.02] = (0.5, 0.5, 1.0)
    return (np.dstack([np.clip(n, 0, 1), a]) * 255 + 0.5).astype(np.uint8)
