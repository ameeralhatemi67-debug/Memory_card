"""Country silhouettes for the "Countries · Silhouettes" picture deck.

    python tools/silhouettes.py                 build every country in COUNTRIES (skips finished ones)
    python tools/silhouettes.py --only it,cl    build just these (ISO A2 codes), redoing them
    python tools/silhouettes.py --force         redo everything
    python tools/silhouettes.py --sheets        also write contact sheets (shapes and flags) for eyeballing
    python tools/silhouettes.py --list          show what Natural Earth calls each country in COUNTRIES

For each country it writes two pictures into app/assets/content/img/country-silhouettes/:

    <code>-shape.png   the country's shape in solid #333333 on transparency       (card front)
    <code>-flag.png    the same shape filled with the country's flag, 3 px #333333 outline (card back)

Both are 700 px on the long side with a 6 % margin all round; the short side follows the shape (at least 200 px).

Data: Natural Earth 50m admin-0 countries (public domain), downloaded once into
content/_imgwork/country-silhouettes/ and cached. Flags: flagcdn.com (w1280 PNG), cached in .../flags/.
Provenance goes to content/sources/country-silhouettes.json.

How a shape is made
  * the feature is found by ISO A2 (ISO_A2, falling back to ISO_A2_EH, then ADM0_A3: France and Norway
    carry "-99" in ISO_A2);
  * its polygons are ranked by area; the biggest is the mainland. Other polygons are kept when they lie close to
    what is already kept (their bounding box is within `near` degrees), so Sicily, Sardinia, Tasmania, Hokkaido,
    Northern Ireland stay and far overseas territories (French Guiana, the Canaries, Svalbard, Hawaii...) go.
    Options per country: `near` (degrees), `all` (keep every polygon above `min_area`), `box` (keep only polygons
    whose centre lies in [lon0, lat0, lon1, lat1]: the contiguous USA), `shift` (add 360 to negative longitudes:
    Russia crosses the antimeridian), `merge` (add the polygons of other features: Somaliland belongs to Somalia);
  * projection: x = lon * cos(latitude of the shape's centre), y = -lat (plate carree, true proportions near the
    centre). Very wide countries may ask for `proj="albers"` (equal-area conic) so that the 49th parallel curves;
  * rendering is 4x supersampled with ImageDraw polygons: exteriors filled, holes (Lesotho in South Africa) cut out;
  * the flag is scaled to cover the shape's bounding box and masked by the shape. Where cover would crop away most
    of the flag (a tall Italy would show only the white stripe), the flag is first squeezed sideways by at most
    `squeeze` (default 1.4x beyond the cover scale) and then cropped around the focus point (`fx`, `fy`).

Everything fetched is untrusted data: it is only ever parsed as JSON / opened with Pillow.
"""
from __future__ import annotations

import argparse
import io
import json
import math
import pathlib
import sys
import time

import requests
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
DECK = "country-silhouettes"
WORK = ROOT / "content" / "_imgwork" / DECK
FLAGS = WORK / "flags"
OUT = ROOT / "app" / "assets" / "content" / "img" / DECK
SOURCES = ROOT / "content" / "sources" / f"{DECK}.json"
GEOJSON = WORK / "ne_50m_admin_0_countries.geojson"
GEOJSON_URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson"
NE_PAGE = "https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-0-countries-2/"
UA = {"User-Agent": "MemoryCardApp/1.0 (personal flashcard app; contact polkgvd2@gmail.com)"}
DELAY = 0.4

SIZE = 700          # long side in px, margin included
MARGIN = 0.06       # of the long side, on every side
MIN_SHORT = 200     # px: the short side is never smaller (Chile); the shape is centred
SS = 4              # supersampling factor
INK = (51, 51, 51)  # #333333
OUTLINE = 3         # px, on the flag version

# Deck order: the easiest / most famous shapes first. code = ISO A2 (also the flagcdn code).
COUNTRIES: list[dict] = [
    dict(code="it", name="Italy"),
    dict(code="jp", name="Japan"),
    dict(code="au", name="Australia", near=2.5),
    dict(code="gb", name="United Kingdom", near=3.0),
    dict(code="br", name="Brazil"),
    dict(code="us", name="United States", box=[-125.5, 24.0, -66.0, 49.8], proj="albers"),
    dict(code="in", name="India"),
    dict(code="eg", name="Egypt"),
    dict(code="mx", name="Mexico"),
    dict(code="cl", name="Chile", squeeze=3.0, fx=0.0),
    dict(code="cu", name="Cuba"),
    dict(code="gr", name="Greece", near=2.5),
    dict(code="es", name="Spain"),
    dict(code="fr", name="France", a3="FRA"),
    dict(code="de", name="Germany"),
    dict(code="tr", name="Turkey"),
    dict(code="no", name="Norway", a3="NOR", fx=0.0),
    dict(code="nz", name="New Zealand", near=2.0, fx=1.0),
    dict(code="ca", name="Canada", all=True, proj="albers"),
    dict(code="ru", name="Russia", shift=True, near=3.5, box=[26.0, 40.0, 200.0, 90.0], proj="albers"),
    dict(code="cn", name="China", proj="albers"),
    dict(code="id", name="Indonesia", all=True, min_area=0.004),
    dict(code="ph", name="Philippines", all=True, min_area=0.004),
    dict(code="mg", name="Madagascar"),
    dict(code="is", name="Iceland"),
    dict(code="pt", name="Portugal"),
    dict(code="th", name="Thailand"),
    dict(code="vn", name="Vietnam"),
    dict(code="ar", name="Argentina"),
    dict(code="pe", name="Peru"),
    dict(code="za", name="South Africa"),
    dict(code="so", name="Somalia", merge=["SOL"]),
    dict(code="ie", name="Ireland"),
    dict(code="lk", name="Sri Lanka"),
    dict(code="hr", name="Croatia"),
    dict(code="my", name="Malaysia", all=True, min_area=0.004),
    dict(code="se", name="Sweden"),
    dict(code="na", name="Namibia"),
    dict(code="pa", name="Panama"),
    dict(code="la", name="Laos"),
    dict(code="gm", name="Gambia"),
]

_last = 0.0


def get(url: str, **kw) -> requests.Response:
    """GET with a polite delay, a User-Agent and retries on 429 / 5xx."""
    global _last
    for attempt in range(5):
        wait = DELAY - (time.time() - _last)
        if wait > 0:
            time.sleep(wait)
        _last = time.time()
        try:
            r = requests.get(url, headers=UA, timeout=60, **kw)
        except requests.RequestException:
            time.sleep(2 + attempt * 2)
            continue
        if r.status_code in (429, 500, 502, 503, 504):
            time.sleep(3 + attempt * 4)
            continue
        return r
    raise RuntimeError(f"giving up on {url}")


# ---------------------------------------------------------------- data


def load_geojson() -> dict:
    WORK.mkdir(parents=True, exist_ok=True)
    if not GEOJSON.exists() or GEOJSON.stat().st_size < 100_000:
        print("downloading Natural Earth 50m countries ...")
        r = get(GEOJSON_URL)
        if r.status_code != 200:
            raise SystemExit(f"Natural Earth download failed: HTTP {r.status_code}")
        GEOJSON.write_bytes(r.content)
    return json.loads(GEOJSON.read_text(encoding="utf-8"))


def index_features(data: dict) -> tuple[dict, dict]:
    """(by ISO A2, by ADM0_A3). ISO_A2 is '-99' for some countries (France, Norway): use ISO_A2_EH then."""
    by_a2, by_a3 = {}, {}
    for f in data["features"]:
        p = {k.upper(): v for k, v in f["properties"].items()}
        f["_p"] = p
        for key in ("ISO_A2", "ISO_A2_EH"):
            v = p.get(key)
            if v and v != "-99":
                by_a2.setdefault(v.lower(), f)
                break
        if p.get("ADM0_A3"):
            by_a3.setdefault(p["ADM0_A3"].upper(), f)
    return by_a2, by_a3


def find_feature(c: dict, by_a2: dict, by_a3: dict) -> dict:
    f = by_a2.get(c["code"]) or (by_a3.get(c["a3"]) if c.get("a3") else None)
    if f is None:
        raise RuntimeError(f"{c['code']}: no Natural Earth feature (give it an `a3`)")
    return f


def polygons_of(feature: dict, shift: bool) -> list[list[list[tuple[float, float]]]]:
    """A feature's polygons: each a list of rings (exterior first, then holes) of (lon, lat)."""
    g = feature["geometry"]
    polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
    out = []
    for poly in polys:
        rings = []
        for ring in poly:
            pts = [((x + 360.0) if (shift and x < 0) else x, y) for x, y in ((pt[0], pt[1]) for pt in ring)]
            rings.append(pts)
        out.append(rings)
    return out


def bbox_of(rings) -> tuple[float, float, float, float]:
    xs = [x for x, _ in rings[0]]
    ys = [y for _, y in rings[0]]
    return min(xs), min(ys), max(xs), max(ys)


def ring_area(ring) -> float:
    a = 0.0
    for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]):
        a += x1 * y2 - x2 * y1
    return abs(a) / 2


def poly_area(rings) -> float:
    """Area in squared degrees with a cos(lat) correction for the east-west scale."""
    x0, y0, x1, y1 = bbox_of(rings)
    k = math.cos(math.radians((y0 + y1) / 2))
    return (ring_area(rings[0]) - sum(ring_area(h) for h in rings[1:])) * k


def gap(a, b) -> float:
    """Distance in degrees between two bounding boxes (0 when they overlap)."""
    dx = max(0.0, b[0] - a[2], a[0] - b[2])
    dy = max(0.0, b[1] - a[3], a[1] - b[3])
    k = math.cos(math.radians((a[1] + a[3]) / 2))
    return math.hypot(dx * k, dy)


def select(polys, c: dict) -> list:
    """Mainland + the polygons that belong to the recognisable shape."""
    box = c.get("box")
    info = []
    for rings in polys:
        bb = bbox_of(rings)
        cx, cy = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2
        if box and not (box[0] <= cx <= box[2] and box[1] <= cy <= box[3]):
            continue
        info.append((poly_area(rings), bb, rings))
    info.sort(key=lambda t: t[0], reverse=True)
    if not info:
        raise RuntimeError("no polygons left after the box filter")
    main_area, kept_bb, main = info[0]
    kept = [main]
    min_area = c.get("min_area", 0.0003)
    near = c.get("near", 1.5)
    for area, bb, rings in info[1:]:
        if area < main_area * min_area:
            continue
        if c.get("all") or gap(kept_bb, bb) <= near:
            kept.append(rings)
            kept_bb = (min(kept_bb[0], bb[0]), min(kept_bb[1], bb[1]), max(kept_bb[2], bb[2]), max(kept_bb[3], bb[3]))
    return kept


# ---------------------------------------------------------------- projection


def make_projection(kept, c: dict):
    xs = [x for rings in kept for x, _ in rings[0]]
    ys = [y for rings in kept for _, y in rings[0]]
    lon0, lon1, lat0, lat1 = min(xs), max(xs), min(ys), max(ys)
    clon, clat = (lon0 + lon1) / 2, (lat0 + lat1) / 2
    if c.get("proj") == "albers":
        p1 = math.radians(lat0 + (lat1 - lat0) / 6)
        p2 = math.radians(lat1 - (lat1 - lat0) / 6)
        n = (math.sin(p1) + math.sin(p2)) / 2
        cc = math.cos(p1) ** 2 + 2 * n * math.sin(p1)
        rho0 = math.sqrt(cc - 2 * n * math.sin(math.radians(clat))) / n

        def proj(lon: float, lat: float) -> tuple[float, float]:
            rho = math.sqrt(cc - 2 * n * math.sin(math.radians(lat))) / n
            th = n * math.radians(lon - clon)
            return rho * math.sin(th), -(rho0 - rho * math.cos(th))

        return proj
    k = math.cos(math.radians(clat))

    def proj(lon: float, lat: float) -> tuple[float, float]:
        return lon * k, -lat

    return proj


# ---------------------------------------------------------------- rendering


def render(kept, c: dict):
    """Returns (shape RGBA, flag-filled RGBA or None until the flag is applied, geometry dict)."""
    proj = make_projection(kept, c)
    P = [[[proj(x, y) for x, y in ring] for ring in rings] for rings in kept]
    xs = [x for rings in P for x, _ in rings[0]]
    ys = [y for rings in P for _, y in rings[0]]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    w, h = maxx - minx, maxy - miny
    m = round(SIZE * MARGIN)
    scale = (SIZE - 2 * m) / max(w, h)
    sw, sh = round(w * scale), round(h * scale)
    W, H = max(sw + 2 * m, MIN_SHORT), max(sh + 2 * m, MIN_SHORT)   # a sliver like Chile is centred on a 200 px canvas
    ox, oy = (W - sw) / 2, (H - sh) / 2
    k = SS

    def px(pt):
        return ((pt[0] - minx) * scale + ox) * k, ((pt[1] - miny) * scale + oy) * k

    mask = Image.new("L", (W * k, H * k), 0)
    d = ImageDraw.Draw(mask)
    ring_lines = []
    for rings in sorted(P, key=lambda r: poly_area(r), reverse=True):  # big first: islands in lakes survive
        d.polygon([px(p) for p in rings[0]], fill=255)
        for hole in rings[1:]:
            d.polygon([px(p) for p in hole], fill=0)
        for ring in rings:
            ring_lines.append([px(p) for p in ring])
    line = Image.new("L", (W * k, H * k), 0)
    dl = ImageDraw.Draw(line)
    for pts in ring_lines:
        dl.line(pts + [pts[0]], fill=255, width=OUTLINE * k, joint="curve")
    geo = dict(W=W, H=H, m=m, k=k, region=(round(ox * k), round(oy * k), round((ox + sw) * k), round((oy + sh) * k)))
    return mask, line, geo


def ink_image(mask: Image.Image, geo: dict) -> Image.Image:
    im = Image.new("RGBA", mask.size, INK + (0,))
    im.putalpha(mask)
    return im.resize((geo["W"], geo["H"]), Image.LANCZOS)


def fetch_flag(code: str) -> tuple[Image.Image, str]:
    FLAGS.mkdir(parents=True, exist_ok=True)
    f = FLAGS / f"{code}.png"
    if not f.exists():
        r = get(f"https://flagcdn.com/w1280/{code}.png")
        if r.status_code != 200:
            raise RuntimeError(f"flagcdn {code}: HTTP {r.status_code}")
        f.write_bytes(r.content)
    im = Image.open(f)
    im.load()
    return im.convert("RGBA"), f"flagcdn w1280 {code}"


def flag_image(mask: Image.Image, line: Image.Image, geo: dict, flag: Image.Image, c: dict) -> Image.Image:
    x0, y0, x1, y1 = geo["region"]
    rw, rh = x1 - x0, y1 - y0
    ra, fa = rw / rh, flag.width / flag.height
    sq = c.get("squeeze", 1.4)
    ta = min(max(fa, ra / sq), ra * sq)          # the flag's aspect after the (limited) squeeze
    if ta >= ra:                                  # wider than the region: fit the height, crop the sides
        nh, nw = rh, round(rh * ta)
    else:                                         # taller: fit the width, crop top and bottom
        nw, nh = rw, round(rw / ta)
    big = flag.resize((nw, nh), Image.LANCZOS)
    left = round(c.get("fx", 0.5) * (nw - rw))
    top = round(c.get("fy", 0.5) * (nh - rh))
    big = big.crop((left, top, left + rw, top + rh))
    canvas = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    canvas.paste(big, (x0, y0))
    canvas.putalpha(mask)                               # keep only the shape
    ink = Image.new("RGBA", mask.size, INK + (0,))      # the outline is centred on the border, so it
    ink.putalpha(line)                                  # also reaches 1.5 px outside the shape (inside the margin)
    out = Image.alpha_composite(canvas, ink)
    return out.resize((geo["W"], geo["H"]), Image.LANCZOS)


def save_png(im: Image.Image, path: pathlib.Path) -> dict:
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    path.write_bytes(buf.getvalue())
    return {"srcW": im.width, "srcH": im.height, "w": im.width, "h": im.height, "alpha": True,
            "aspect": round(im.width / im.height, 4), "kb": round(buf.tell() / 1024, 1)}


# ---------------------------------------------------------------- sheets


def sheets() -> None:
    try:
        font = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    cell, cols, rows_per = 230, 6, 4
    for tag in ("shape", "flag"):
        files = [OUT / f"{c['code']}-{tag}.png" for c in COUNTRIES if (OUT / f"{c['code']}-{tag}.png").exists()]
        per = cols * rows_per
        for n, start in enumerate(range(0, len(files), per)):
            chunk = files[start:start + per]
            rows = (len(chunk) + cols - 1) // cols
            sheet = Image.new("RGB", (cols * cell, rows * (cell + 20)), (241, 238, 230))
            dr = ImageDraw.Draw(sheet)
            for i, f in enumerate(chunk):
                x, y = (i % cols) * cell, (i // cols) * (cell + 20)
                im = Image.open(f).convert("RGBA")
                im.thumbnail((cell - 12, cell - 12), Image.LANCZOS)
                sheet.paste(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2), im)
                dr.text((x + 4, y + cell + 2), f"{f.stem}  {Image.open(f).size[0]}x{Image.open(f).size[1]}", fill=(40, 40, 40), font=font)
            target = WORK / f"sheet-{tag}s-{n + 1}.png"
            sheet.save(target)
            print(target.relative_to(ROOT).as_posix())


# ---------------------------------------------------------------- main


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default="", help="comma-separated ISO A2 codes to (re)build")
    ap.add_argument("--force", action="store_true", help="rebuild even finished pictures")
    ap.add_argument("--sheets", action="store_true", help="write contact sheets of the shapes and the flag versions")
    ap.add_argument("--list", action="store_true", help="list the Natural Earth feature behind every code")
    args = ap.parse_args()

    data = load_geojson()
    by_a2, by_a3 = index_features(data)
    if args.list:
        for c in COUNTRIES:
            f = find_feature(c, by_a2, by_a3)
            p = f["_p"]
            print(f"{c['code']}  {c['name']:16} -> {p.get('NAME')} ({p.get('ADMIN')}) A2={p.get('ISO_A2')}/{p.get('ISO_A2_EH')} A3={p.get('ADM0_A3')} "
                  f"{f['geometry']['type']} {len(f['geometry']['coordinates'])}")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    SOURCES.parent.mkdir(parents=True, exist_ok=True)
    prov = json.loads(SOURCES.read_text(encoding="utf-8")) if SOURCES.exists() else {}
    only = {s.strip().lower() for s in args.only.split(",") if s.strip()}
    bad = done = 0
    for c in COUNTRIES:
        code = c["code"]
        if only and code not in only:
            continue
        shape_p, flag_p = OUT / f"{code}-shape.png", OUT / f"{code}-flag.png"
        if shape_p.exists() and flag_p.exists() and not (args.force or only) and f"{code}-shape" in prov:
            done += 1
            continue
        try:
            feat = find_feature(c, by_a2, by_a3)
            polys = polygons_of(feat, c.get("shift", False))
            for a3 in c.get("merge", []):
                polys += polygons_of(by_a3[a3], c.get("shift", False))
            kept = select(polys, c)
            mask, line, geo = render(kept, c)
            flag, flag_file = fetch_flag(code)
            sf = save_png(ink_image(mask, geo), shape_p)
            ff = save_png(flag_image(mask, line, geo, flag, c), flag_p)
        except Exception as e:  # noqa: BLE001
            bad += 1
            print(f"FAILED  {code}: {e}")
            continue
        p = feat["_p"]
        today = time.strftime("%Y-%m-%d")
        prov[f"{code}-shape"] = {
            "page": NE_PAGE, "file": f"ne_50m_admin_0_countries.geojson: {p.get('NAME')} ({p.get('ADM0_A3')}), {len(kept)} of {len(polys)} polygons",
            "license": "Natural Earth, public domain (map data)", "source": "natural-earth", "facts": sf, "fetched": today}
        prov[f"{code}-flag"] = {
            "page": f"https://flagcdn.com/{code}.svg", "file": f"{flag_file} masked by the Natural Earth shape",
            "license": "flag artwork, public domain; shape from Natural Earth, public domain", "source": "flagcdn+natural-earth", "facts": ff, "fetched": today}
        done += 1
        print(f"ok      {code}: {sf['w']}x{sf['h']}  shape {sf['kb']}KB  flag {ff['kb']}KB  polygons {len(kept)}/{len(polys)}  ({c['name']})")
    SOURCES.write_text(json.dumps(prov, indent=1, ensure_ascii=False), encoding="utf-8")
    total = sum(f.stat().st_size for f in OUT.iterdir())
    print(f"\n{done} built, {bad} failed; folder {total / 1024 / 1024:.1f} MB in {OUT.relative_to(ROOT).as_posix()}")
    if args.sheets:
        sheets()


if __name__ == "__main__":
    main()
