"""Validate every deck in content/decks/** and bundle them into app/assets/content/catalog.json.

    python tools/build_catalog.py            # validate + write the catalogue
    python tools/build_catalog.py --print    # also print every card (front | back) for review

Decks are grouped by origin: content/decks/originals (hand-written) and content/decks/haiku
(written by Claude Haiku, reviewed). Problems that would break the app stop the build; style issues
are listed as warnings.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "content" / "decks"
OUT = ROOT / "app" / "assets" / "content" / "catalog.json"

CATEGORIES = {"lang": "Languages", "code": "Coding", "med": "Medicine", "science": "Science", "knowledge": "Knowledge"}
ORDER = ["lang", "code", "med", "science", "knowledge"]


def check(deck: dict, path: pathlib.Path, errors: list, warnings: list) -> None:
    where = path.relative_to(ROOT).as_posix()
    for key in ("id", "name", "category", "cards"):
        if key not in deck:
            errors.append(f"{where}: missing {key}")
            return
    if deck["id"] != path.stem:
        errors.append(f"{where}: id {deck['id']!r} does not match the filename")
    if deck["category"] not in CATEGORIES:
        errors.append(f"{where}: unknown category {deck['category']!r}")
    if len(deck["name"]) > 28:
        warnings.append(f"{where}: name longer than 28 characters")
    if not deck["cards"]:
        errors.append(f"{where}: no cards")
    seen = set()
    for i, c in enumerate(deck["cards"]):
        front, back = (c.get("front") or "").strip(), (c.get("back") or "").strip()
        if not front or not back:
            errors.append(f"{where}: card {i} has an empty side")
        if front in seen:
            errors.append(f"{where}: duplicate front {front!r}")
        seen.add(front)
        if len(front) > 70 or len(back) > 70:
            warnings.append(f"{where}: long side on card {i}: {front[:30]!r}")
        ex = (c.get("example") or "").strip()
        if ex and back and back.lower() in ex.lower() and deck["category"] != "lang":
            warnings.append(f"{where}: example may give away the answer on {front!r}")


def main() -> None:
    printing = "--print" in sys.argv
    errors, warnings, decks = [], [], []
    ids = set()
    for path in sorted(SRC.rglob("*.json")):
        deck = json.loads(path.read_text(encoding="utf-8"))
        origin = path.parent.name
        deck["origin"] = "haiku" if origin == "haiku" else "originals"
        deck.setdefault("folder", CATEGORIES.get(deck.get("category"), "Library"))
        deck.setdefault("lang", None)
        deck.setdefault("kind", "text")
        deck.setdefault("level", "")
        deck.setdefault("description", "")
        check(deck, path, errors, warnings)
        if deck["id"] in ids:
            errors.append(f"{path.name}: duplicate deck id {deck['id']!r}")
        ids.add(deck["id"])
        for c in deck["cards"]:
            for k in ("label", "example", "hook"):
                c[k] = (c.get(k) or "").strip()
            c["front"] = c["front"].strip()
            c["back"] = c["back"].strip()
        decks.append(deck)
        if printing:
            print(f"\n## {deck['id']} · {deck['name']} [{deck['category']}, {deck.get('lang')}] {len(deck['cards'])} cards")
            for c in deck["cards"]:
                extra = f"  ({c['label']})" if c["label"] else ""
                print(f"  {c['front']} | {c['back']}{extra}")

    decks.sort(key=lambda d: (ORDER.index(d["category"]) if d["category"] in ORDER else 99, d["origin"] != "originals", d["name"]))
    for w in warnings:
        print("warning:", w)
    if errors:
        for e in errors:
            print("ERROR:", e)
        raise SystemExit(1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"v": 1, "decks": decks}, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    total = sum(len(d["cards"]) for d in decks)
    by_origin = {}
    for d in decks:
        by_origin.setdefault(d["origin"], [0, 0])
        by_origin[d["origin"]][0] += 1
        by_origin[d["origin"]][1] += len(d["cards"])
    print(f"\n{len(decks)} decks, {total} cards -> {OUT.relative_to(ROOT).as_posix()}")
    for k, (n, c) in by_origin.items():
        print(f"  {k}: {n} decks, {c} cards")


if __name__ == "__main__":
    main()
