"""Make 24: every set of four numbers from 1 to 11 that can make 24, with every way to do it.

    python tools/make24.py --stats     # count the sets and the ways (nothing written)
    python tools/make24.py             # write the decks to content/decks/originals/make24-*.json

Rules: use all four numbers once each, with + − × ÷ and brackets. Subtraction never goes below zero and
division may leave fractions (8 ÷ (3 − 8 ÷ 3) is fine). Two ways that differ only in order or grouping are
one way: (7 − 6 + 5) × 4 and 4 × (5 + 7 − 6) are the same, and so are ×1 and ÷1. Sets go from easy to hard
(many ways and whole numbers first, single tricky fractions last) and fill 12 decks of 63 cards.
"""
import itertools
import json
import pathlib
import re
import sys
from fractions import Fraction

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "content" / "decks" / "originals"
LOW, HIGH, TARGET, PER_DECK = 1, 11, 24, 63
MINUS, TIMES, OVER = "−", "×", "÷"


# ---------------------------------------------------------------- solving

def solve(nums):
    """Every expression tree over all of nums that makes TARGET. Trees: ('n', v) or (op, left, right)."""
    found = []

    def go(items):
        if len(items) == 1:
            v, e = items[0]
            if v == TARGET:
                found.append(e)
            return
        for i, j in itertools.combinations(range(len(items)), 2):
            (a, ea), (b, eb) = items[i], items[j]
            rest = [items[k] for k in range(len(items)) if k not in (i, j)]
            options = [(a + b, ("+", ea, eb)), (a * b, ("*", ea, eb))]
            if a >= b:
                options.append((a - b, ("-", ea, eb)))
            if b >= a:
                options.append((b - a, ("-", eb, ea)))
            if b != 0:
                options.append((a / b, ("/", ea, eb)))
            if a != 0:
                options.append((b / a, ("/", eb, ea)))
            for v, e in options:
                go(rest + [(v, e)])

    go([(Fraction(n), ("n", n)) for n in nums])
    return found


def value(e):
    if e[0] == "n":
        return Fraction(e[1])
    a, b = value(e[1]), value(e[2])
    return {"+": a + b, "-": a - b, "*": a * b, "/": a / b if b else None}[e[0]]


# ---------------------------------------------------------------- one way, however it is written

def norm(e):
    """A canonical form: sums and products flattened, their parts sorted. Returns (key, node)."""
    if e[0] == "n":
        return ("N", e[1])
    if e[0] in "+-":
        terms = []

        def flat(x, s):
            if x[0] == "+":
                flat(x[1], s), flat(x[2], s)
            elif x[0] == "-":
                flat(x[1], s), flat(x[2], -s)
            else:
                n = norm(x)
                terms.append((n, 1 if value(x) == 0 else s))

        flat(e, 1)
        return ("S", tuple(sorted(terms, key=repr)))
    factors = []

    def flat(x, p):
        if x[0] == "*":
            flat(x[1], p), flat(x[2], p)
        elif x[0] == "/":
            flat(x[1], p), flat(x[2], -p)
        else:
            n = norm(x)
            factors.append((n, 1 if value(x) == 1 else p))

    flat(e, 1)
    return ("P", tuple(sorted(factors, key=repr)))


def nval(n):
    if n[0] == "N":
        return Fraction(n[1])
    if n[0] == "S":
        return sum((nval(t) * s for t, s in n[1]), Fraction(0))
    v = Fraction(1)
    for f, p in n[1]:
        v = v * nval(f) if p > 0 else v / nval(f)
    return v


def make(kind, parts):
    """A sum or product node from its parts, flattening parts of the same kind and dropping a lone wrapper."""
    flat = []
    for p, s in parts:
        if p[0] == kind:
            flat += [(q, t * s) for q, t in p[1]]
        else:
            flat.append((p, s))
    if len(flat) == 1 and flat[0][1] == 1:
        return flat[0][0]
    return (kind, tuple(sorted(flat, key=repr)))


def simplify(n, pulled):
    """Takes out what changes nothing (× a 1, + a 0, + x − x, × x ÷ x) wherever it sits; it goes back on at
    the top, so "11 × 1 + 7 + 6" and "6 × 1 + 11 + 7" are both "(11 + 7 + 6) × 1"."""
    if n[0] == "N":
        return n
    parts = [(simplify(p, pulled), s) for p, s in n[1]]
    neutral = Fraction(1) if n[0] == "P" else Fraction(0)
    keep, out = [], []
    for p, s in parts:
        (out if nval(p) == neutral else keep).append((p, 1 if nval(p) == neutral else s))
    # Pairs that cancel: + x − x in a sum, × x ÷ x in a product.
    rest = []
    for p, s in keep:
        twin = next((i for i, (q, t) in enumerate(rest) if t == -s and repr(q) == repr(p)), None)
        if twin is None:
            rest.append((p, s))
        else:
            q, t = rest.pop(twin)
            out += [(q, t), (p, s)]
    if not rest or all(s < 0 for _, s in rest):
        # Everything here cancels (7 ÷ 7), or what is left would have nothing to start from (the 1 in 1 ÷ 5):
        # the part stays as it is.
        return make(n[0], parts)
    pulled[n[0]] += out
    return make(n[0], rest)


def canonical(e):
    pulled = {"S": [], "P": []}
    r = simplify(norm(e), pulled)
    if pulled["S"]:
        r = make("S", [(r, 1)] + pulled["S"])
    if pulled["P"]:
        r = make("P", [(r, 1)] + pulled["P"])
    return r


def is_compound(n):
    return n[0] != "N"


def ordered(n):
    """Parts in reading order: bracketed parts first, then bigger numbers; what is taken away or divided last."""
    def rank(part):
        node, sign = part
        return (sign < 0, not is_compound(node), -nval(node), repr(node))
    return sorted(n[1], key=rank)


def show(n):
    if n[0] == "N":
        return str(n[1])
    out = ""
    if n[0] == "S":
        for i, (t, s) in enumerate(ordered(n)):
            text = show(t)
            out += (text if i == 0 else f" + {text}") if s > 0 else (f"{MINUS} {text}" if i == 0 else f" {MINUS} {text}")
        return out
    for i, (f, p) in enumerate(ordered(n)):
        text = f"({show(f)})" if f[0] == "S" else show(f)
        out += text if i == 0 else (f" {TIMES} {text}" if p > 0 else f" {OVER} {text}")
    return out


def fractional(n):
    """True when working it out in reading order passes through a fraction."""
    if n[0] == "N":
        return False
    if any(fractional(part) for part, _ in n[1]):
        return True
    v = Fraction(0) if n[0] == "S" else Fraction(1)
    for part, s in ordered(n):
        x = nval(part)
        if n[0] == "S":
            v += x * s
        else:
            v = v * x if s > 0 else v / x
        if v.denominator != 1:
            return True
    return False


def reads(text):
    """What a printed way comes to, read the usual way (brackets, then × ÷, then + −)."""
    expr = text.replace(MINUS, "-").replace(TIMES, "*").replace(OVER, "/")
    return eval(re.sub(r"\d+", lambda m: f"Fraction({m.group()})", expr), {"Fraction": Fraction})


def ways(nums):
    """The different ways for one set, simplest first: whole numbers, then fewer divisions and brackets."""
    seen = {}
    for e in solve(nums):
        n = canonical(e)
        seen.setdefault(repr(n), n)
    out, shown = [], set()
    for n in seen.values():
        text = show(n)
        assert nval(n) == TARGET and reads(text) == TARGET, (nums, text)
        assert sorted(int(x) for x in re.findall(r"\d+", text)) == sorted(nums), (nums, text)
        if text in shown:
            continue
        shown.add(text)
        out.append(((fractional(n), text.count(OVER), text.count("("), len(text), text), text, fractional(n)))
    out.sort()
    return [(text, frac) for _, text, frac in out]


def difficulty(ws):
    """Lower is easier: many ways, and at least one without fractions."""
    plain = [w for w, f in ws if not f]
    hard = 0 if plain else 100
    return hard + 40 / len(ws) + (0 if plain and OVER not in plain[0] else 5)


# ---------------------------------------------------------------- the cover

IMG = ROOT / "app" / "assets" / "content" / "img"
FONT = ROOT / "app" / "assets" / "fonts" / "BernardMTCondensed.ttf"
TOPS = [(0x80, 0xAE, 0xFF), (0x8B, 0xD3, 0xA0), (0xFF, 0xC6, 0x80), (0xD3, 0x5F, 0x5F)]
CW, CH = 1200, 1000


def cover(path, nums, level):
    """A chalkboard with faint + − × ÷ chalk marks, a fan of four playing cards showing one of the deck's own
    sets (their tops in the nav bar hand's colours) and "= 24" in chalk. The shop's card shows it whole, the fan
    behind the deck's monogram; the library bar shows a strip below the fan (the skin's y = 0.63): chalk marks
    behind the deck's name and the "= 24" just before the bar's own fan of progress cards."""
    import random

    from PIL import Image, ImageDraw, ImageFilter, ImageFont

    k = 2  # drawn at twice the size, then scaled down for smooth edges
    W, H = CW * k, CH * k
    rnd = random.Random(1000 + level)
    im = Image.new("RGB", (W, H))
    px = ImageDraw.Draw(im)
    for y in range(H):  # slate, a touch lighter at the top
        g = int(34 - 14 * y / H)
        px.line([(0, y), (W, y)], fill=(g, g, g + 1))
    noise = Image.effect_noise((W // 4, H // 4), 22).resize((W, H)).convert("L")
    im = Image.composite(Image.new("RGB", (W, H), (46, 46, 46)), im, noise.point(lambda v: 18 if v > 150 else 0))

    # Chalk marks on a loose grid.
    chalk = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(chalk)
    step = 150 * k
    for gy in range(-1, H // step + 2):
        for gx in range(-1, W // step + 2):
            x = gx * step + (step // 2 if gy % 2 else 0) + rnd.randint(-30, 30) * k
            y = gy * step + rnd.randint(-30, 30) * k
            r = rnd.randint(18, 30) * k
            a = rnd.randint(26, 46)
            w = 5 * k
            col = (241, 241, 241, a)
            kind = rnd.randrange(4)
            if kind in (0, 1):
                cd.line([(x - r, y), (x + r, y)], fill=col, width=w)
            if kind == 0:
                cd.line([(x, y - r), (x, y + r)], fill=col, width=w)
            if kind == 2:
                d = int(r * 0.75)
                cd.line([(x - d, y - d), (x + d, y + d)], fill=col, width=w)
                cd.line([(x - d, y + d), (x + d, y - d)], fill=col, width=w)
            if kind == 3:
                cd.line([(x - r, y), (x + r, y)], fill=col, width=w)
                for dy in (-r * 0.6, r * 0.6):
                    cd.ellipse([x - w, y + dy - w, x + w, y + dy + w], fill=col)
    chalk = chalk.filter(ImageFilter.GaussianBlur(1.2 * k))
    im = Image.alpha_composite(im.convert("RGBA"), chalk)

    # "= 24", in chalk, where the library bar shows it.
    eq = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(eq).text((768 * k, 600 * k), "= 24", font=ImageFont.truetype(str(FONT), 84 * k), fill=(255, 214, 160, 120), anchor="mm")
    im = Image.alpha_composite(im, eq.filter(ImageFilter.GaussianBlur(1.0 * k)))

    # The fan, above the strip the bar shows.
    big = ImageFont.truetype(str(FONT), 158 * k)
    small = ImageFont.truetype(str(FONT), 42 * k)
    cw, ch, rad = 190 * k, 266 * k, 19 * k
    pivot = (600 * k, 860 * k)
    reach = 600 * k
    angles = [-24, -8, 8, 24]
    for i, (n, ang) in enumerate(zip(nums, angles)):
        pad = 40 * k
        card = Image.new("RGBA", (cw + 2 * pad, ch + 2 * pad), (0, 0, 0, 0))
        shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle([pad, pad + 16 * k, pad + cw, pad + ch + 16 * k], rad, fill=(0, 0, 0, 150))
        shadow = shadow.filter(ImageFilter.GaussianBlur(16 * k))
        face = Image.new("RGBA", card.size, (0, 0, 0, 0))
        fd = ImageDraw.Draw(face)
        fd.rounded_rectangle([pad, pad, pad + cw, pad + ch], rad, fill=(241, 241, 241, 255))
        strip = Image.new("RGBA", card.size, (0, 0, 0, 0))
        ImageDraw.Draw(strip).rectangle([pad, pad, pad + cw, pad + 20 * k], fill=TOPS[i % 4] + (255,))
        mask = Image.new("L", card.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([pad, pad, pad + cw, pad + ch], rad, fill=255)
        face = Image.alpha_composite(face, Image.composite(strip, Image.new("RGBA", card.size, (0, 0, 0, 0)), mask))
        fd = ImageDraw.Draw(face)
        ink = (30, 30, 30, 255)
        fd.text((pad + cw / 2, pad + ch / 2 + 8 * k), str(n), font=big, fill=ink, anchor="mm")
        fd.text((pad + 18 * k, pad + 30 * k), str(n), font=small, fill=ink, anchor="la")
        corner = Image.new("RGBA", card.size, (0, 0, 0, 0))
        ImageDraw.Draw(corner).text((pad + 18 * k, pad + 30 * k), str(n), font=small, fill=ink, anchor="la")
        face = Image.alpha_composite(face, corner.rotate(180))
        card = Image.alpha_composite(shadow, face).rotate(-ang, resample=Image.BICUBIC, expand=True)
        import math as _m
        cx = pivot[0] + reach * _m.sin(_m.radians(ang))
        cy = pivot[1] - reach * _m.cos(_m.radians(ang))
        im.alpha_composite(card, (int(cx - card.width / 2), int(cy - card.height / 2)))

    im.convert("RGB").resize((CW, CH), Image.LANCZOS).save(path, quality=88, optimize=True)


# ---------------------------------------------------------------- decks

def sets():
    rows = []
    for combo in itertools.combinations_with_replacement(range(LOW, HIGH + 1), 4):
        ws = ways(combo)
        if ws:
            rows.append((difficulty(ws), combo, ws))
    rows.sort(key=lambda r: (r[0], r[1]))
    return rows


def deck_json(index, total, rows):
    first = index == 0
    cards = []
    for _, combo, ws in rows:
        cards.append({
            "label": "make 24",
            "front": " ".join(str(n) for n in combo),
            "back": ws[0][0],
            "ways": [w for w, _ in ws],
        })
    level = index + 1
    tone = "warm-up" if level <= total // 3 else ("steady" if level <= 2 * total // 3 else "tricky")
    return {
        "id": f"make24-{level:02d}",
        "name": f"Make 24 · Level {level}",
        "mono": "24",
        "category": "math",
        "level": tone,
        "kind": "make24",
        "folder": "Make 24",
        "description": (
            "Four numbers from 1 to 11: make 24 with + − × ÷, using each number once. Build it on the card, "
            "two numbers at a time. Most sets have more than one way: when a card comes back, only a way you "
            "have not found before counts. Stuck? shows a way one step at a time."
            + (" The easiest sets come first." if first else "")
        ),
        "skin": {"img": "skin.jpg", "x": 0.5, "y": 0.69, "zoom": 1, "shade": 0.3, "text": "light"},
        "cards": cards,
    }


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    rows = sets()
    total_sets = len(list(itertools.combinations_with_replacement(range(LOW, HIGH + 1), 4)))
    counts = [len(ws) for _, _, ws in rows]
    decks = (len(rows) + PER_DECK - 1) // PER_DECK
    print(f"{len(rows)} of {total_sets} sets make 24 -> {decks} decks of up to {PER_DECK}")
    print(f"ways per set: min {min(counts)}, max {max(counts)}, one way only: {counts.count(1)}, "
          f"needs a fraction: {sum(1 for _, _, ws in rows if all(f for _, f in ws))}")
    if "--stats" in sys.argv:
        for _, combo, ws in rows[:3] + rows[-3:]:
            print(combo, len(ws), ws[:4])
        for probe in [(4, 5, 6, 7), (4, 6, 6, 7), (3, 4, 6, 8), (3, 3, 8, 8), (1, 5, 5, 5)]:
            print(probe, [w for w, _ in ways(probe)])
        return
    for i in range(decks):
        part = rows[i * PER_DECK:(i + 1) * PER_DECK]
        d = deck_json(i, decks, part)
        (OUT / f"{d['id']}.json").write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        # The cover shows the deck's first (easiest) set.
        folder = IMG / d["id"]
        folder.mkdir(parents=True, exist_ok=True)
        cover(folder / "skin.jpg", part[0][1], i + 1)
    print(f"wrote {decks} decks and their covers to {OUT.relative_to(ROOT).as_posix()}")
    return rows


if __name__ == "__main__":
    main()
