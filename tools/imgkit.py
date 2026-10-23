"""Image toolkit for the picture decks (flags, anime characters and powers, car brands).

    python tools/imgkit.py build MANIFEST.json [--force]   download, optimise and validate every item
    python tools/imgkit.py search WIKI "query"             find page titles on a Fandom wiki
    python tools/imgkit.py candidates WIKI "Page title"    list every image file on a Fandom page, biggest first
    python tools/imgkit.py summary WIKI "Page title"       first paragraphs of a Fandom page, as plain text (for facts)
    python tools/imgkit.py wikidata "Toyota"               find the Wikidata id (Q...) of a company, person or thing
    python tools/imgkit.py commons-category "Toyota logos" files in a Wikimedia Commons category (alternative logos)
    python tools/imgkit.py search-commons "query"          free-text Commons file search (noisy; rarely needed)
    python tools/imgkit.py check DIR                       re-validate the images already in a deck folder
    python tools/imgkit.py sheet DIR OUT.png [--cols 8]    contact sheet(s) so a human can eyeball the result

A manifest is JSON:
    {
      "deck": "naruto-characters",
      "kind": "portrait",                         # flag | portrait | scene | logo  (sets size and quality gates)
      "items": [
        {"id": "naruto-uzumaki", "source": "fandom", "wiki": "naruto", "title": "Naruto Uzumaki"},
        {"id": "rasengan-2",     "source": "fandom-file", "wiki": "naruto", "file": "File:Rasengan.png"},
        {"id": "ng",             "source": "flagcdn", "code": "ng"},
        {"id": "toyota",         "source": "wikidata-logo", "qid": "Q53268"},          # the company's official logo
        {"id": "toyota-2",       "source": "commons", "file": "File:Toyota Motor Corporation Logo.svg"},
        {"id": "x",              "source": "url", "url": "https://example.com/pic.jpg"},
        {"id": "mazda",          "source": "wikidata-logo", "qid": "Q35996", "crop": [0, 0, 1, 0.68]}   # keep only the top 68 %
      ]
    }

Images land in app/assets/content/img/<deck>/<id>.(png|jpg); provenance (page, file, licence note, sizes)
goes to content/sources/<deck>.json; downloads and reports are staged in content/_imgwork/<deck>/ (git-ignored).
Everything fetched is untrusted data: it is only ever opened with Pillow, never executed.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import io
import json
import pathlib
import re
import sys
import time
from html.parser import HTMLParser

import requests
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = pathlib.Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app" / "assets" / "content" / "img"
SOURCES = ROOT / "content" / "sources"
WORK = ROOT / "content" / "_imgwork"
UA = {"User-Agent": "MemoryCardApp/1.0 (personal flashcard app; contact polkgvd2@gmail.com)"}
DELAY = 0.4  # seconds between requests: be polite to the wikis

# kind -> (longest side we keep, shortest side we accept, aspect range we accept, max kilobytes)
KINDS = {
    "flag": dict(max_side=640, min_short=200, aspect=(0.9, 2.2), max_kb=120),
    "portrait": dict(max_side=900, min_short=300, aspect=(0.35, 2.2), max_kb=380),
    "scene": dict(max_side=960, min_short=270, aspect=(0.4, 2.6), max_kb=380),
    "logo": dict(max_side=512, min_short=200, aspect=(0.3, 3.5), max_kb=160),
}

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
            r = requests.get(url, headers=UA, timeout=40, **kw)
        except requests.RequestException:
            time.sleep(2 + attempt * 2)
            continue
        if r.status_code in (429, 500, 502, 503, 504):
            time.sleep(3 + attempt * 4)
            continue
        return r
    raise RuntimeError(f"giving up on {url}")


def api(base: str, **params) -> dict:
    params.setdefault("format", "json")
    r = get(base, params=params)
    r.raise_for_status()
    return r.json()


def fandom_api(wiki: str) -> str:
    return f"https://{wiki}.fandom.com/api.php"


COMMONS = "https://commons.wikimedia.org/w/api.php"
WIKIDATA = "https://www.wikidata.org/w/api.php"


# ---------------------------------------------------------------- sources


def src_flagcdn(item: dict) -> tuple[bytes, dict]:
    code = item["code"].lower()
    r = get(f"https://flagcdn.com/w640/{code}.png")
    if r.status_code != 200:
        raise RuntimeError(f"flagcdn {code}: HTTP {r.status_code}")
    return r.content, {"page": f"https://flagcdn.com/{code}.svg", "file": f"flagcdn w640 {code}", "license": "flag artwork, public domain"}


def src_fandom(item: dict) -> tuple[bytes, dict]:
    wiki, title = item["wiki"], item["title"]
    data = api(fandom_api(wiki), action="query", titles=title, prop="pageimages", pithumbsize=1000, redirects=1)
    page = next(iter(data["query"]["pages"].values()))
    thumb = page.get("thumbnail")
    if not thumb:
        raise RuntimeError(f"{wiki}:{title}: page has no lead image (try `candidates`, then a fandom-file item)")
    r = get(thumb["source"])
    if r.status_code != 200:
        raise RuntimeError(f"{wiki}:{title}: HTTP {r.status_code}")
    return r.content, {
        "page": f"https://{wiki}.fandom.com/wiki/{page['title'].replace(' ', '_')}",
        "file": page.get("pageimage", ""),
        "license": "Fandom wiki image (fair use for identification; personal study use)",
    }


def src_fandom_file(item: dict) -> tuple[bytes, dict]:
    wiki, file = item["wiki"], item["file"]
    if not file.lower().startswith("file:"):
        file = "File:" + file
    data = api(fandom_api(wiki), action="query", titles=file, prop="imageinfo", iiprop="url|size|mime", iiurlwidth=1000)
    page = next(iter(data["query"]["pages"].values()))
    info = (page.get("imageinfo") or [None])[0]
    if not info:
        raise RuntimeError(f"{wiki}:{file}: file not found")
    url = info.get("thumburl") or info["url"]
    r = get(url)
    if r.status_code != 200:
        raise RuntimeError(f"{wiki}:{file}: HTTP {r.status_code}")
    return r.content, {
        "page": f"https://{wiki}.fandom.com/wiki/{file.replace(' ', '_')}",
        "file": file,
        "license": "Fandom wiki image (fair use for identification; personal study use)",
    }


def src_commons(item: dict) -> tuple[bytes, dict]:
    file = item["file"]
    if not file.lower().startswith("file:"):
        file = "File:" + file
    data = api(COMMONS, action="query", titles=file, prop="imageinfo", iiprop="url|size|mime|extmetadata", iiurlwidth=900)
    page = next(iter(data["query"]["pages"].values()))
    info = (page.get("imageinfo") or [None])[0]
    if not info:
        raise RuntimeError(f"commons {file}: file not found")
    meta = info.get("extmetadata", {})
    lic = meta.get("LicenseShortName", {}).get("value", "see file page")
    url = info.get("thumburl") or info["url"]  # for an SVG the thumbnail is a transparent PNG render
    r = get(url)
    if r.status_code != 200:
        raise RuntimeError(f"commons {file}: HTTP {r.status_code}")
    return r.content, {
        "page": "https://commons.wikimedia.org/wiki/" + file.replace(" ", "_"),
        "file": file,
        "license": f"Wikimedia Commons: {lic}; logo may be a registered trademark of its owner",
    }


def src_wikidata_logo(item: dict) -> tuple[bytes, dict]:
    """The official logo file Wikidata lists (property P154) for a company, fetched from Commons."""
    qid = item["qid"]
    data = api(WIKIDATA, action="wbgetclaims", entity=qid, property="P154")
    claims = data.get("claims", {}).get("P154", [])
    if not claims:
        raise RuntimeError(f"{qid}: no logo (P154) on Wikidata; use a commons item with an explicit file")

    def score(c: dict) -> tuple:
        return (c.get("rank") == "preferred", "P582" not in c.get("qualifiers", {}), "P582" not in c.get("qualifiers", {}))

    best = sorted(claims, key=score, reverse=True)[0]
    return src_commons({"file": "File:" + best["mainsnak"]["datavalue"]["value"]})


def src_url(item: dict) -> tuple[bytes, dict]:
    r = get(item["url"])
    if r.status_code != 200:
        raise RuntimeError(f"{item['url']}: HTTP {r.status_code}")
    return r.content, {"page": item.get("page", item["url"]), "file": item["url"], "license": item.get("license", "unknown")}


SOURCES_FN = {"flagcdn": src_flagcdn, "fandom": src_fandom, "fandom-file": src_fandom_file, "commons": src_commons, "wikidata-logo": src_wikidata_logo, "url": src_url}


# ---------------------------------------------------------------- image handling


def has_alpha(im: Image.Image) -> bool:
    if im.mode in ("RGBA", "LA"):
        return im.getchannel("A").getextrema()[0] < 250
    return im.mode == "P" and "transparency" in im.info


def dhash(im: Image.Image, size: int = 8) -> int:
    g = ImageOps.grayscale(im.convert("RGB")).resize((size + 1, size), Image.LANCZOS)
    px = list(g.getdata())
    bits = 0
    for row in range(size):
        for col in range(size):
            bits = (bits << 1) | (px[row * (size + 1) + col] > px[row * (size + 1) + col + 1])
    return bits


def crop_raw(raw: bytes, box: list) -> bytes:
    """Cut a download down to a fraction box [left, top, right, bottom] (each 0-1): lets a logo lose the
    lettering under (or beside) its emblem."""
    im = Image.open(io.BytesIO(raw))
    im.load()
    w, h = im.size
    left, top, right, bottom = box
    im = im.convert("RGBA").crop((round(left * w), round(top * h), round(right * w), round(bottom * h)))
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue()


def trim_margins(im: Image.Image) -> Image.Image:
    """Logos come with wide empty margins: cut to the drawing plus a small border."""
    if im.mode != "RGBA":
        return im
    box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if not box:
        return im
    pad = round(max(box[2] - box[0], box[3] - box[1]) * 0.04)
    return im.crop((max(0, box[0] - pad), max(0, box[1] - pad), min(im.width, box[2] + pad), min(im.height, box[3] + pad)))


def optimise(raw: bytes, kind: str) -> tuple[bytes, str, dict, list[str]]:
    """Returns (bytes, extension, facts, problems)."""
    gate = KINDS[kind]
    problems: list[str] = []
    try:
        im = Image.open(io.BytesIO(raw))
        im.load()
    except Exception as e:  # noqa: BLE001 - anything unreadable is a rejection
        raise RuntimeError(f"not a readable image ({e.__class__.__name__}); got {raw[:40]!r}") from e
    if getattr(im, "is_animated", False):
        im.seek(0)
    alpha = has_alpha(im)
    im = im.convert("RGBA" if alpha else "RGB")
    if kind == "logo":
        im = trim_margins(im)
    src_w, src_h = im.size
    if min(src_w, src_h) < gate["min_short"]:
        problems.append(f"too small: {src_w}x{src_h} (need short side >= {gate['min_short']})")
    aspect = src_w / src_h
    if not gate["aspect"][0] <= aspect <= gate["aspect"][1]:
        problems.append(f"odd aspect {aspect:.2f} (accepted {gate['aspect'][0]}-{gate['aspect'][1]})")
    gray = ImageOps.grayscale(im.convert("RGB"))
    ex = gray.getextrema()
    if ex[1] - ex[0] < 12 and not alpha:
        problems.append("looks blank / a single flat colour")
    scale = gate["max_side"] / max(src_w, src_h)
    if scale < 1:
        im = im.resize((max(1, round(src_w * scale)), max(1, round(src_h * scale))), Image.LANCZOS)
    facts = {"srcW": src_w, "srcH": src_h, "w": im.width, "h": im.height, "alpha": alpha, "aspect": round(im.width / im.height, 4)}
    buf = io.BytesIO()
    if alpha or kind in ("logo", "flag"):
        im.save(buf, "PNG", optimize=True)
        ext = "png"
        if buf.tell() > gate["max_kb"] * 1024 and kind in ("flag", "logo") and not alpha:
            # a busy flag: palette-reduce, still lossless to the eye
            buf = io.BytesIO()
            im.convert("P", palette=Image.ADAPTIVE, colors=128).save(buf, "PNG", optimize=True)
    else:
        ext = "jpg"
        for q in (88, 82, 76, 70):
            buf = io.BytesIO()
            im.save(buf, "JPEG", quality=q, optimize=True, progressive=True)
            if buf.tell() <= gate["max_kb"] * 1024:
                break
    facts["kb"] = round(buf.tell() / 1024, 1)
    if buf.tell() > gate["max_kb"] * 1024 * 1.5:
        problems.append(f"heavy file: {facts['kb']} KB")
    return buf.getvalue(), ext, facts, problems


def cmd_build(args: argparse.Namespace) -> None:
    manifest = json.loads(pathlib.Path(args.manifest).read_text(encoding="utf-8"))
    deck, kind = manifest["deck"], manifest["kind"]
    if kind not in KINDS:
        raise SystemExit(f"unknown kind {kind!r}; use one of {sorted(KINDS)}")
    out_dir = ASSETS / deck
    work = WORK / deck
    out_dir.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    SOURCES.mkdir(parents=True, exist_ok=True)
    prov_path = SOURCES / f"{deck}.json"
    prov = json.loads(prov_path.read_text(encoding="utf-8")) if prov_path.exists() else {}
    report, hashes = {}, {}
    ok = bad = 0
    for item in manifest["items"]:
        iid = item["id"]
        existing = next(iter(out_dir.glob(f"{iid}.*")), None)
        if existing and not args.force and iid in prov:
            report[iid] = {"status": "kept", **prov[iid].get("facts", {})}
            ok += 1
            continue
        try:
            fn = SOURCES_FN[item["source"]]
            raw, origin = fn(item)
            if item.get("crop"):
                raw = crop_raw(raw, item["crop"])
            (work / f"{iid}.raw").write_bytes(raw)
            data, ext, facts, problems = optimise(raw, kind)
        except Exception as e:  # noqa: BLE001
            report[iid] = {"status": "FAILED", "why": str(e)[:300]}
            bad += 1
            print(f"FAILED  {iid}: {str(e)[:160]}")
            continue
        for old in out_dir.glob(f"{iid}.*"):
            old.unlink()
        (out_dir / f"{iid}.{ext}").write_bytes(data)
        h = dhash(Image.open(io.BytesIO(data)))
        for other, oh in hashes.items():
            # plain-striped flags always hash alike, so the check is for pictures only
            if kind != "flag" and bin(h ^ oh).count("1") <= 3:
                problems.append(f"near-duplicate of {other}")
        hashes[iid] = h
        status = "REVIEW" if problems else "ok"
        report[iid] = {"status": status, "problems": problems, **facts}
        prov[iid] = {**origin, "source": item["source"], "facts": facts, "fetched": time.strftime("%Y-%m-%d")}
        if status == "ok":
            ok += 1
        else:
            bad += 1
        print(f"{status:7} {iid}: {facts['w']}x{facts['h']} {facts['kb']}KB {'alpha ' if facts['alpha'] else ''}{'; '.join(problems)}")
    prov_path.write_text(json.dumps(prov, indent=1, ensure_ascii=False), encoding="utf-8")
    (work / "report.json").write_text(json.dumps(report, indent=1), encoding="utf-8")
    flagged = [k for k, v in report.items() if v["status"] in ("FAILED", "REVIEW")]
    print(f"\n{deck}: {len(report) - len(flagged)} fine, {len(flagged)} need attention -> {', '.join(flagged) or 'none'}")
    total = sum(f.stat().st_size for f in out_dir.iterdir())
    print(f"folder size {total / 1024 / 1024:.1f} MB in {out_dir.relative_to(ROOT).as_posix()}")


# ---------------------------------------------------------------- discovery helpers


def cmd_search(args: argparse.Namespace) -> None:
    data = api(fandom_api(args.wiki), action="query", list="search", srsearch=args.query, srlimit=10)
    for hit in data["query"]["search"]:
        snippet = re.sub(r"<[^>]+>", "", html.unescape(hit.get("snippet", "")))[:110]
        print(f"{hit['title']}  --  {snippet}")


def cmd_candidates(args: argparse.Namespace) -> None:
    data = api(fandom_api(args.wiki), action="query", titles=args.title, prop="images", imlimit=60, redirects=1)
    page = next(iter(data["query"]["pages"].values()))
    names = [i["title"] for i in page.get("images", []) if not re.search(r"\.(svg|gif|ogg|webm|mp4)$", i["title"], re.I)]
    if not names:
        print("no image files on that page; try `search` for the right title")
        return
    rows = []
    for chunk in range(0, len(names), 25):
        info = api(fandom_api(args.wiki), action="query", titles="|".join(names[chunk:chunk + 25]), prop="imageinfo", iiprop="size|mime")
        for p in info["query"]["pages"].values():
            ii = (p.get("imageinfo") or [None])[0]
            if ii:
                rows.append((ii["width"] * ii["height"], p["title"], ii["width"], ii["height"]))
    for _, title, w, h in sorted(rows, reverse=True)[:25]:
        print(f"{w}x{h}  {title}")


class _Text(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.out: list[str] = []
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "table", "aside", "sup"):
            self.skip += 1
        if tag in ("p", "li", "br"):
            self.out.append("\n")

    def handle_endtag(self, tag):
        if tag in ("script", "style", "table", "aside", "sup"):
            self.skip = max(0, self.skip - 1)

    def handle_data(self, data):
        if not self.skip:
            self.out.append(data)


def cmd_summary(args: argparse.Namespace) -> None:
    data = api(fandom_api(args.wiki), action="parse", page=args.title, prop="text", section=0, redirects=1, disablelimitreport=1)
    p = _Text()
    p.feed(data["parse"]["text"]["*"])
    text = re.sub(r"\n\s*\n+", "\n", "".join(p.out)).strip()
    print(text[:1800])


def cmd_wikidata(args: argparse.Namespace) -> None:
    data = api(WIKIDATA, action="wbsearchentities", search=args.query, language="en", limit=8, type="item")
    for hit in data.get("search", []):
        print(f"{hit['id']}  {hit.get('label', '')} -- {hit.get('description', '')}")


def cmd_commons_category(args: argparse.Namespace) -> None:
    data = api(COMMONS, action="query", list="categorymembers", cmtitle="Category:" + args.name.removeprefix("Category:"),
               cmtype="file", cmlimit=40)
    titles = [m["title"] for m in data["query"]["categorymembers"]]
    for i in range(0, len(titles), 25):
        info = api(COMMONS, action="query", titles="|".join(titles[i:i + 25]), prop="imageinfo", iiprop="size|mime")
        for p in info["query"]["pages"].values():
            ii = (p.get("imageinfo") or [{}])[0]
            print(f"{p['title']}  ({ii.get('width')}x{ii.get('height')} {ii.get('mime')})")


def cmd_search_commons(args: argparse.Namespace) -> None:
    query = args.query if args.any else f"{args.query} filetype:drawing"  # vector drawings = logos, no photos
    data = api(COMMONS, action="query", generator="search", gsrsearch=query, gsrnamespace=6, gsrlimit=12,
               prop="imageinfo", iiprop="size|mime")
    pages = sorted(data.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 99))
    for p in pages:
        ii = (p.get("imageinfo") or [{}])[0]
        print(f"{p['title']}  ({ii.get('width')}x{ii.get('height')} {ii.get('mime')})")


# ---------------------------------------------------------------- review helpers


def cmd_check(args: argparse.Namespace) -> None:
    folder = pathlib.Path(args.dir)
    kind = args.kind
    bad = 0
    for f in sorted(folder.iterdir()):
        if f.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        try:
            im = Image.open(f)
            im.load()
            gate = KINDS[kind]
            issues = []
            if min(im.size) < gate["min_short"]:
                issues.append(f"small {im.size}")
            if f.stat().st_size > gate["max_kb"] * 1024 * 1.5:
                issues.append(f"heavy {f.stat().st_size // 1024}KB")
            if issues:
                bad += 1
                print(f"{f.name}: {'; '.join(issues)}")
        except Exception as e:  # noqa: BLE001
            bad += 1
            print(f"{f.name}: unreadable ({e})")
    print(f"{bad} problem(s)")


def cmd_sheet(args: argparse.Namespace) -> None:
    folder = pathlib.Path(args.dir)
    files = [f for f in sorted(folder.iterdir()) if f.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")]
    cols, cell, label_h = args.cols, args.cell, 22
    per_sheet = cols * 5
    try:
        font = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    out = pathlib.Path(args.out)
    for n, start in enumerate(range(0, len(files), per_sheet)):
        chunk = files[start:start + per_sheet]
        rows = (len(chunk) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * (cell + label_h)), (60, 60, 60))
        d = ImageDraw.Draw(sheet)
        for i, f in enumerate(chunk):
            x, y = (i % cols) * cell, (i // cols) * (cell + label_h)
            # checkerboard so transparency is visible
            for cy in range(0, cell, 16):
                for cx in range(0, cell, 16):
                    c = (200, 200, 200) if (cx // 16 + cy // 16) % 2 else (150, 150, 150)
                    d.rectangle([x + cx, y + cy, x + cx + 15, y + cy + 15], fill=c)
            im = Image.open(f).convert("RGBA")
            im.thumbnail((cell - 6, cell - 6))
            sheet.paste(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2), im)
            d.text((x + 3, y + cell + 3), f"{f.stem[:22]} {Image.open(f).size[0]}x{Image.open(f).size[1]}", fill=(255, 255, 255), font=font)
        target = out if len(files) <= per_sheet else out.with_name(f"{out.stem}-{n + 1}{out.suffix}")
        sheet.save(target)
        print(target)


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("manifest")
    b.add_argument("--force", action="store_true")
    b.set_defaults(fn=cmd_build)
    s = sub.add_parser("search")
    s.add_argument("wiki")
    s.add_argument("query")
    s.set_defaults(fn=cmd_search)
    c = sub.add_parser("candidates")
    c.add_argument("wiki")
    c.add_argument("title")
    c.set_defaults(fn=cmd_candidates)
    m = sub.add_parser("summary")
    m.add_argument("wiki")
    m.add_argument("title")
    m.set_defaults(fn=cmd_summary)
    wd = sub.add_parser("wikidata")
    wd.add_argument("query")
    wd.set_defaults(fn=cmd_wikidata)
    cc = sub.add_parser("commons-category")
    cc.add_argument("name")
    cc.set_defaults(fn=cmd_commons_category)
    sc = sub.add_parser("search-commons")
    sc.add_argument("query")
    sc.add_argument("--any", action="store_true", help="include photos, not just vector drawings")
    sc.set_defaults(fn=cmd_search_commons)
    ck = sub.add_parser("check")
    ck.add_argument("dir")
    ck.add_argument("--kind", default="portrait", choices=sorted(KINDS))
    ck.set_defaults(fn=cmd_check)
    sh = sub.add_parser("sheet")
    sh.add_argument("dir")
    sh.add_argument("out")
    sh.add_argument("--cols", type=int, default=8)
    sh.add_argument("--cell", type=int, default=150)
    sh.set_defaults(fn=cmd_sheet)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
