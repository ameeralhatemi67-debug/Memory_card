"""Seamless texture maps for Memory Card (app/assets/textures/*.png).

Every map is made from periodic noise (white noise shaped in the frequency domain, so it tiles with no
seam) and saved as RGBA: white where the surface is lighter than its base colour, black where it is
darker, the difference in alpha. Painted with normal blending at some opacity, one map lightens and
darkens any colour, in light and dark mode, without the cost of an overlay blend.

    python tools/make_textures.py            # writes the maps and tools/textures_preview.png
"""

from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / 'app' / 'assets' / 'textures'
RNG = np.random.default_rng(7)


# ------------------------------------------------------------------ periodic building blocks

def freq(n):
    f = np.fft.fftfreq(n) * n
    return np.meshgrid(f, f, indexing='xy')


def shaped(n, amp):
    """White noise filtered by amp(fx, fy): periodic by construction."""
    fx, fy = freq(n)
    spec = np.fft.fft2(RNG.standard_normal((n, n))) * amp(fx, fy)
    spec[0, 0] = 0
    v = np.real(np.fft.ifft2(spec))
    return v / (np.abs(v).max() + 1e-9)


def fbm(n, beta=2.0, lo=1.0, hi=None):
    def amp(fx, fy):
        r = np.hypot(fx, fy)
        a = np.where(r > 0, 1 / np.maximum(r, lo) ** (beta / 2), 0)
        if hi is not None:
            a = a * np.exp(-(r / hi) ** 2)
        return a
    return shaped(n, amp)


def aniso(n, beta, sx, sy, angle=0.0, hi=None):
    """Noise stretched along a direction: brush strokes, slate layers."""
    def amp(fx, fy):
        c, s = np.cos(angle), np.sin(angle)
        u, v = fx * c + fy * s, -fx * s + fy * c
        r = np.hypot(u * sx, v * sy)
        a = np.where(r > 0, 1 / np.maximum(r, 1.0) ** (beta / 2), 0)
        if hi is not None:
            a = a * np.exp(-(np.hypot(fx, fy) / hi) ** 2)
        return a
    return shaped(n, amp)


def band(n, f0, width):
    return shaped(n, lambda fx, fy: np.exp(-((np.hypot(fx, fy) - f0) / width) ** 2))


def white(n):
    v = RNG.standard_normal((n, n))
    return v / np.abs(v).max()


def emboss(h, angle=np.deg2rad(-50), k=1.0):
    """Light raking across a height map (periodic gradient)."""
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / 2
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) / 2
    s = gx * np.cos(angle) + gy * np.sin(angle)
    return s / (np.abs(s).max() + 1e-9) * k


def blur(v, r):
    """Periodic gaussian blur."""
    fx, fy = freq(v.shape[0])
    return np.real(np.fft.ifft2(np.fft.fft2(v) * np.exp(-(np.hypot(fx, fy) * r / v.shape[0] * np.pi) ** 2 * 2)))


def norm(v):
    v = v - np.median(v)
    return v / (np.percentile(np.abs(v), 99.5) + 1e-9)


def worley(n, cells, seed=0):
    """Periodic cellular noise: distance to the nearest feature point (pits, pebbles)."""
    rng = np.random.default_rng(seed)
    pts = rng.random((cells, 2)) * n
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.full((n, n), 1e9)
    for px, py in pts:
        dx = np.abs(xx - px)
        dy = np.abs(yy - py)
        dx = np.minimum(dx, n - dx)
        dy = np.minimum(dy, n - dy)
        d = np.minimum(d, np.hypot(dx, dy))
    return d / d.max()


def fibers(n, count, length, seed=1, width=1):
    """Short random strokes: paper and kraft fibres."""
    rng = np.random.default_rng(seed)
    img = np.zeros((n, n))
    for _ in range(count):
        x, y = rng.random(2) * n
        a = rng.random() * np.pi
        L = length * (0.4 + rng.random())
        w = rng.choice([-1, 1]) * (0.5 + rng.random() * 0.5)
        for t in np.linspace(-L / 2, L / 2, int(L * 2)):
            xi = int(x + t * np.cos(a)) % n
            yi = int(y + t * np.sin(a)) % n
            img[yi, xi] += w
            if width > 1:
                img[(yi + 1) % n, xi] += w * 0.5
    return blur(img, 0.6)


# ------------------------------------------------------------------ the textures

def plaster(n=512):
    mottle = fbm(n, 2.6, lo=2, hi=60)
    trowel = emboss(aniso(n, 2.2, 1.0, 3.5, angle=0.35, hi=90), k=1)
    sweep = emboss(aniso(n, 2.0, 1.0, 5.0, angle=-0.6, hi=70), k=0.6)
    grain = white(n)
    return 0.22 * norm(mottle) + 0.55 * norm(trowel + sweep) + 0.1 * grain


def limewash(n=512):
    clouds = blur(fbm(n, 2.2, lo=2, hi=60), 2.0)
    strokes = aniso(n, 2.0, 1.0, 5.0, angle=0.25, hi=160) + 0.6 * aniso(n, 2.0, 1.0, 5.0, angle=-0.9, hi=160)
    ridges = emboss(blur(strokes, 1.0), k=1)
    return 0.6 * norm(clouds) + 0.3 * norm(strokes) + 0.25 * norm(ridges) + 0.05 * white(n)


def stucco(n=512):
    bumps = blur(fbm(n, 1.4, lo=8, hi=110), 1.2)
    lit = emboss(bumps, k=1)
    return 0.8 * norm(lit) + 0.25 * norm(fbm(n, 2.4, lo=2, hi=40)) + 0.06 * white(n)


def brick(n=512):
    rows, per_row, mortar = 8, 4, 9
    ch, bw = n // rows, n // per_row
    yy, xx = np.mgrid[0:n, 0:n]
    row = yy // ch
    x = (xx + (row % 2) * (bw // 2)) % bw
    y = yy % ch
    # Depth into the brick from its nearest edge: 0 in the recessed mortar joint.
    d = np.minimum.reduce([x - mortar / 2, bw - mortar / 2 - x, y - mortar / 2, ch - mortar / 2 - y])
    face = np.clip(d / 2.5, 0, 1)
    lit = emboss(blur(face, 1.2), k=1)
    joint = -(1 - face)
    paint = 0.3 * norm(fbm(n, 2.4, lo=2, hi=60)) * face
    return 0.45 * lit + 0.75 * joint + paint + 0.06 * white(n)


def concrete(n=512):
    mottle = fbm(n, 2.3, lo=2, hi=80)
    pits = worley(n, 900, seed=3)
    pores = -np.clip(0.035 - pits, 0, None) / 0.035
    return 0.55 * norm(mottle) + 0.6 * pores + 0.18 * white(n) + 0.15 * norm(emboss(fbm(n, 1.8, lo=6, hi=120)))


def slate(n=512):
    layers = aniso(n, 2.2, 9.0, 1.0, angle=0.06, hi=160)
    cleft = emboss(aniso(n, 2.0, 7.0, 1.0, angle=0.04, hi=140), angle=np.deg2rad(-80))
    return 0.5 * norm(layers) + 0.5 * norm(cleft) + 0.07 * white(n)


def felt(n=512):
    fib = sum(aniso(n, 1.2, 1.0, 4.0, angle=a, hi=200) for a in np.linspace(0, np.pi, 6, endpoint=False))
    return 0.75 * norm(fib) + 0.3 * norm(fbm(n, 2.6, lo=2, hi=40))


def cardstock(n=256):
    return 0.4 * norm(blur(fibers(n, 1400, 14, seed=4), 0.8)) + 0.4 * white(n) + 0.3 * norm(fbm(n, 2.4, lo=2, hi=30))


def linen(n=256):
    yy, xx = np.mgrid[0:n, 0:n]
    k = 2 * np.pi / n * 64  # 64 threads across the tile
    jitter = 0.6 * fbm(n, 2.0, lo=3, hi=50)
    warp = np.sin(xx * k + jitter * 3) * (0.6 + 0.4 * norm(aniso(n, 1.6, 6.0, 1.0, hi=90)))
    weft = np.sin(yy * k + jitter * 3) * (0.6 + 0.4 * norm(aniso(n, 1.6, 1.0, 6.0, hi=90)))
    return 0.45 * warp + 0.45 * weft + 0.15 * white(n)


def laid(n=256):
    yy, xx = np.mgrid[0:n, 0:n]
    lines = np.sin(yy * 2 * np.pi / n * 96)
    chain = np.exp(-((xx % 64) - 32) ** 2 / 3.0)
    return 0.4 * lines + 0.5 * chain + 0.25 * norm(fbm(n, 2.4, lo=2, hi=40)) + 0.12 * white(n)


def pressed(n=256):
    pebbles = worley(n, 420, seed=9)
    return 0.85 * norm(emboss(blur(pebbles, 0.8))) + 0.12 * white(n)


def kraft(n=256):
    fib = norm(fibers(n, 2200, 18, seed=5, width=2))
    specks = -np.clip(white(n) - 0.82, 0, None) * 5
    return 0.6 * fib + 0.3 * norm(fbm(n, 2.6, lo=2, hi=30)) + 0.35 * specks


def wax(n=256):
    mottle = fbm(n, 2.8, lo=1.5, hi=40)
    bubbles = -np.clip(0.04 - worley(n, 160, seed=11), 0, None) / 0.04
    return 0.75 * norm(mottle) + 0.4 * bubbles + 0.05 * white(n)


def grain_fine(n=256):
    return white(n)


def grain_coarse(n=256):
    return norm(blur(white(n), 1.6)) * 0.8 + 0.3 * white(n)


TEXTURES = {
    'plaster': plaster, 'limewash': limewash, 'stucco': stucco, 'brick': brick, 'concrete': concrete,
    'slate': slate, 'felt': felt,
    'cardstock': cardstock, 'linen': linen, 'laid': laid, 'pressed': pressed,
    'kraft': kraft, 'wax': wax, 'grain_fine': grain_fine, 'grain_coarse': grain_coarse,
}


def to_rgba(v):
    v = np.clip(v, -1, 1)
    rgba = np.zeros(v.shape + (4,), np.uint8)
    rgba[..., :3] = np.where(v[..., None] > 0, 255, 0)
    rgba[..., 3] = np.round(np.abs(v) * 255).astype(np.uint8)
    return Image.fromarray(rgba)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = []
    for name, fn in TEXTURES.items():
        v = norm(fn())
        to_rgba(v).save(OUT / f'{name}.png', optimize=True)
        tiles.append((name, v))
        print(f'{name:13s} {(OUT / f"{name}.png").stat().st_size // 1024:4d} KB')
    # Contact sheet: each map over light (#F1F1F1) and dark (#151515) at a typical strength.
    cell = 256
    sheet = Image.new('RGB', (cell * len(tiles), cell * 2), 'white')
    for i, (name, v) in enumerate(tiles):
        crop = np.clip(v[:cell, :cell], -1, 1)
        for j, base in enumerate([0xF1, 0x15]):
            strength = 0.35
            out = base + crop * strength * np.where(crop > 0, 255 - base, base)
            sheet.paste(Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).convert('RGB'), (i * cell, j * cell))
    sheet.save(Path(__file__).resolve().parent / 'textures_preview.png')


if __name__ == '__main__':
    main()
