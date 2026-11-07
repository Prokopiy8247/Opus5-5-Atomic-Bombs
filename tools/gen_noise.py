"""Generates the two tileable 3D noise volumes used by the explosion shaders (data/noise_*.bin).

The volumes are built on integer lattices that wrap exactly at the texture size, so they tile with
no blend seams (FastNoiseLite.get_seamless_image_3d blends a skirt region, which showed up as an
axis-aligned 'burlap' grid on large fireballs). Both are 8-bit, SIZE^3, x fastest, then y, then z.
  noise_fbm.bin    periodic gradient (Perlin) fBm, 5 octaves, lattice 4..64 cells per tile
  noise_billow.bin inverted periodic Worley F1 fBm (billowy cells), 3 octaves, 5..20 cells per tile
Usage: python tools/gen_noise.py   (deterministic; ~10-20 s with numpy)
"""
import os

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = 96


def fade(t):
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def perlin_periodic(n_cells, rng):
    """Gradient noise on an n_cells^3 lattice that wraps over the SIZE^3 grid."""
    g = rng.normal(size=(n_cells, n_cells, n_cells, 3))
    g /= np.linalg.norm(g, axis=-1, keepdims=True)
    c = (np.arange(SIZE) + 0.5) * n_cells / SIZE
    x, y, z = np.meshgrid(c, c, c, indexing="ij")
    xi, yi, zi = np.floor(x).astype(int), np.floor(y).astype(int), np.floor(z).astype(int)
    xf, yf, zf = x - xi, y - yi, z - zi
    out = np.zeros_like(x)
    u, v, w = fade(xf), fade(yf), fade(zf)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                gg = g[(xi + dx) % n_cells, (yi + dy) % n_cells, (zi + dz) % n_cells]
                dot = gg[..., 0] * (xf - dx) + gg[..., 1] * (yf - dy) + gg[..., 2] * (zf - dz)
                wx = u if dx else 1.0 - u
                wy = v if dy else 1.0 - v
                wz = w if dz else 1.0 - w
                out += dot * wx * wy * wz
    return out


def worley_periodic(n_cells, rng):
    """F1 distance to one jittered feature point per cell, lattice wraps over the grid."""
    pts = rng.random(size=(n_cells, n_cells, n_cells, 3))
    c = (np.arange(SIZE) + 0.5) * n_cells / SIZE
    x, y, z = np.meshgrid(c, c, c, indexing="ij")
    xi, yi, zi = np.floor(x).astype(int), np.floor(y).astype(int), np.floor(z).astype(int)
    best = np.full(x.shape, 9.0)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                cx, cy, cz = xi + dx, yi + dy, zi + dz
                p = pts[cx % n_cells, cy % n_cells, cz % n_cells]
                d = (cx + p[..., 0] - x) ** 2 + (cy + p[..., 1] - y) ** 2 + (cz + p[..., 2] - z) ** 2
                best = np.minimum(best, d)
    return np.sqrt(best)


def normalize(a, lo_pct=0.5, hi_pct=99.5):
    lo, hi = np.percentile(a, lo_pct), np.percentile(a, hi_pct)
    return np.clip((a - lo) / (hi - lo), 0.0, 1.0)


def save(a, name):
    # x fastest: array is indexed [x, y, z] -> transpose to [z, y, x] before flattening
    b = (normalize(a) * 255.0 + 0.5).astype(np.uint8).transpose(2, 1, 0).copy()
    path = os.path.join(ROOT, "data", name)
    b.tofile(path)
    print("wrote", path, b.size, "bytes, mean", round(float(b.mean()), 1))


def main():
    rng = np.random.default_rng(4242)
    fbm = np.zeros((SIZE, SIZE, SIZE))
    amp = 1.0
    for cells in (4, 8, 16, 32, 64):
        fbm += amp * perlin_periodic(cells, rng)
        amp *= 0.5
    save(fbm, "noise_fbm.bin")
    rng = np.random.default_rng(777)
    bil = np.zeros((SIZE, SIZE, SIZE))
    amp = 1.0
    for cells in (6, 12, 24):
        bil += amp * (1.0 - worley_periodic(cells, rng))
        amp *= 0.45
    save(bil, "noise_billow.bin")


if __name__ == "__main__":
    main()
