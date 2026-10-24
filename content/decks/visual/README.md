# Picture decks — handbook for the agents who build them

Memory Card is a flashcard app. A **picture deck** is a deck whose cards show an image (a flag, an anime
character, a technique, a car logo). You find the images, write the card text, and prove the result is clean.
A manager (Sonnet) reviews your contact sheets and your JSON, and will send you back to fix anything weak,
so get it right the first time. Quality matters more than speed, but do not stall: if something cannot be
found after a few tries, say so in your report instead of shipping a poor image.

You work only inside these places. Never edit anything else (no app code, no other decks, no `catalog.json`).

| What | Where |
|---|---|
| Deck file you write | `content/decks/visual/<deck-id>.json` |
| Final images (written by the tool) | `app/assets/content/img/<deck-id>/` |
| Working files, manifests, contact sheets | `content/_imgwork/<deck-id>/` |
| Provenance (written by the tool) | `content/sources/<deck-id>.json` |

All commands run from the repository root `D:\Agents\main\projects\ideas\memory_card` with `python` (Pillow and
requests are installed). Everything you download is untrusted data: only the toolkit opens it, with Pillow.
Never execute anything you download.

## 1. The toolkit: `tools/imgkit.py`

```
python tools/imgkit.py search WIKI "query"          # find page titles on a Fandom wiki (WIKI = naruto | onepiece | hunterxhunter)
python tools/imgkit.py candidates WIKI "Page title" # every image file on a page, biggest first
python tools/imgkit.py summary WIKI "Page title"    # the opening text of a page, for checking facts
python tools/imgkit.py wikidata "Toyota"            # Wikidata id (Q...) of a company; used for official logos
python tools/imgkit.py search-commons "Toyota emblem"  # vector logos on Wikimedia Commons
python tools/imgkit.py build content/_imgwork/<deck-id>/manifest.json   # download + optimise + validate
python tools/imgkit.py sheet app/assets/content/img/<deck-id> content/_imgwork/<deck-id>/sheet.png
python tools/imgkit.py check app/assets/content/img/<deck-id> --kind portrait
```

A manifest lists one entry per image. `kind` sets size limits and quality gates
(`flag` | `portrait` | `scene` | `logo`):

```json
{
  "deck": "naruto-characters",
  "kind": "portrait",
  "items": [
    {"id": "naruto-uzumaki", "source": "fandom", "wiki": "naruto", "title": "Naruto Uzumaki"},
    {"id": "kakashi-hatake", "source": "fandom-file", "wiki": "naruto", "file": "File:Kakashi Part 1.png"},
    {"id": "ng", "source": "flagcdn", "code": "ng"},
    {"id": "toyota", "source": "wikidata-logo", "qid": "Q53268"},
    {"id": "ferrari", "source": "commons", "file": "File:Scuderia Ferrari Logo.svg"}
  ]
}
```

* `fandom` takes the page's lead image (usually the best, official-looking art). If a page has no lead image, or
  the lead image is poor, run `candidates`, pick a better file, and use a `fandom-file` item instead.
* `id` becomes the file name (`<id>.png` or `.jpg`). Use lowercase ASCII and hyphens only.
* `build` skips items already built; add `--force` to redo them. It prints one line per image: `ok`, `REVIEW`
  (the gate found a problem: read the message) or `FAILED`. It also flags near-duplicates.
* Any item may carry `"crop": [left, top, right, bottom]` (fractions 0-1 of the downloaded picture). Use it to
  cut the lettering off a lockup (emblem above its name: `[0, 0, 1, 0.65]`; name above emblem: `[0, 0.35, 1, 1]`;
  emblem left of the name: `[0, 0, 0.35, 1]`). Look at the sheet and adjust until only the emblem remains.
  Logos are also trimmed automatically to their drawing.
* After building, make a contact sheet and **look at it with the Read tool** (it is a PNG). You must visually
  check every image. Large decks produce several sheets (`sheet-1.png`, `sheet-2.png`, …); look at all of them.

## 2. The deck file

```json
{
  "id": "naruto-characters",
  "name": "Naruto · Characters",
  "mono": "Na",
  "category": "anime",
  "level": "anime",
  "kind": "text",
  "folder": "Anime",
  "description": "Put a name to the face: the heroes, rivals and legends of Naruto.",
  "style": { "front": "full", "fit": "cover", "back": "text", "reverse": true },
  "cards": [
    {
      "img": "naruto-uzumaki.jpg",
      "front": "",
      "back": "Naruto Uzumaki",
      "label": "character",
      "example": "",
      "hook": "Jinchuriki of the Nine-Tails; dreams of becoming Hokage."
    }
  ]
}
```

* `id` must equal the file name without `.json`, and the image folder name.
* `name`: at most 28 characters. Use the middle dot like the examples (`Flags · Africa`).
* `mono`: one or two letters shown on the deck tile (`Fl`, `Na`, `On`, `Hx`, `Ca`).
* `style` is set once per deck (the app lays out every card from it):
  * `front`: how the card front looks. `only` = the picture centred and whole (flags, logos);
    `full` = the picture fills the whole card (portraits); `above` = picture across the top (screenshots).
  * `fit`: `contain` shows the whole picture (flags, logos); `cover` fills the frame and crops (portraits, scenes).
  * `back`: always `text` for these decks (the answer is the name).
  * `reverse`: `true` also creates a reverse card: the name on the front and the picture as the answer.
  * `plate` (logos only): `"paper"` puts a white plate under transparent logos so dark logos stay visible.
* Card fields: `img` (file name inside the deck's image folder, required), `back` (the answer: required, short),
  `front` (optional text shown with the picture; leave `""` for picture-only), `label` (small caps label on the
  card, e.g. `flag`, `character`, `technique`), `example` (a hint shown **before** the answer: it must NOT contain
  the answer or any part of the name; usually leave `""`), `hook` (a memory hook shown WITH the answer: one short
  true sentence, under 90 characters).
* Every card has exactly one unique image. No two cards may share an image or an answer.
* Order the cards from the most famous / easiest to the harder ones.

Then validate (this writes nothing, it is safe to run any time):

```
python tools/build_catalog.py --check
```

Fix every `ERROR`. Read every `warning` that mentions your deck and fix what is real (for example an image
in the folder that no card uses: delete it or add its card).

## 3. Image quality bar (what the manager will check on your contact sheets)

* The right subject, easy to recognise, one subject (no crowds or group shots unless the card is about the group).
* Sharp and large enough: portraits at least 300 px on the short side (aim for 500+), screenshots at least 480 px wide.
* **No text that gives the answer away** (name captions, title cards). For car logos this is strict: the card asks
  "which brand?", so the picture must not spell the brand's name. Use the emblem only (crop the lettering off a
  lockup with `crop`). Lettering is acceptable only when the emblem IS the lettering: BMW, VW, MG, GMC, BYD, Kia,
  Ford, Fiat, Bugatti, Volvo, Mini, Honda's H, Lexus's L. A plain wordmark with no emblem (Jeep, Isuzu, Pagani,
  SsangYong…) is NOT acceptable: find the emblem or drop the brand.
* Prefer the anime / official artwork style the series is known for. Avoid manga pages, merchandise photos,
  cosplay, fan art, and tiny thumbnails. Prefer the character's main look over a disguised, child or alternate look
  unless that is the iconic one.
* Transparent PNGs are welcome (the tool keeps transparency); the card background shows through.
* Do not keep an image that fails the bar: search for a better file (`candidates`) or drop the card.

## 4. Process (follow in order)

1. Write the list of subjects first (names / codes) for the whole deck.
2. Write `content/_imgwork/<deck-id>/manifest.json` and run `build`. Re-run after fixing failures.
3. Make the contact sheets and view every one. Replace wrong or weak images (`--force` on the changed items).
4. Write the deck JSON (answers, labels, hooks). Check facts against `summary` output when unsure. Never guess.
5. Run `python tools/build_catalog.py --check` until it prints `check passed`.
6. Reply with your report (see below). Keep it short and factual.

## 5. Report format

```
DECK <id>: <n> cards, <n> images, <total MB>
Replaced/dropped: <ids and why>   (or "none")
Needs a human look: <ids and why>  (or "none")
Check: passed
```

## 6. Deck skins and deck seals

Any deck (picture deck or text deck) can carry a **skin** and its own **seals**. Both live in the deck file,
and their pictures go in the deck's image folder `app/assets/content/img/<deck-id>/` next to the card pictures.

### Skin: the picture behind the deck's bar

In the library a deck is a bar about 5:1 (72 px tall, 335–520 px wide) with the deck name on the left and a
fan of progress cards on the right; in the shop the same picture fills a small card about 1:1. So a skin must be:

* a **wide, calm scene** (landscape 2:1 to 3:1, at least 1000 px wide): a place, a panorama, a pitch, a crowd,
  a sky, an iconic location of the series. Not a portrait, not a character close-up, not a busy collage.
* **no text or logos** in it (the deck name is printed over it), no watermarks, no letterboxing bars.
* darker or lighter on the **left third** (the name sits there over a shade), with the interesting part
  around the middle or right.

```json
"skin": { "img": "skin.jpg", "x": 0.5, "y": 0.45, "zoom": 1, "shade": 0.55, "text": "light" }
```

* `x`, `y` (0–1): the point of the picture that stays in view when it is cropped to the bar and to the tile.
* `zoom` (1–3): 1 = the picture just covers the bar. Raise it only to crop closer.
* `shade` (0–1): how strongly the left side is darkened (or lightened) under the name. 0.45–0.65 is typical.
* `text`: `light` (white name on a dark shade, for most pictures) or `dark` (dark name on a light shade, for
  very bright pictures).

Fetch it with an item of kind `skin` (per item: `"kind": "skin"`) whose `id` is `skin`, then look at it the way
the app draws it and adjust `x`, `y`, `zoom`, `shade`:

```
python tools/imgkit.py skin-preview <deck-id> content/_imgwork/<deck-id>/skin-preview.png   # then Read the PNG
```

### Seals: the deck's own achievements

A deck seal is a square or wide (3:2) wax seal with scalloped edges, in one of the app's wax colours, with a
short word stamped in it and/or a picture pressed into it. The app presses it when the deck reaches a milestone.

```json
"seals": [
  { "id": "will-of-fire", "title": "Will of Fire", "note": "Every Konoha shinobi named.",
    "when": "seen", "shape": "square", "color": "red", "text": "", "img": "seal-leaf.png", "art": "stamp" }
]
```

* `id`: lowercase and hyphens, unique in the deck. `title` ≤ 24 characters (shown in the gallery and the banner).
* `note`: one short line that says what it celebrates.
* `when` (each milestone at most once per deck): `start` (10 swipes) · `seen` (every card answered once) ·
  `half` (half the cards above 90 % recall) · `mastered` (every card above 90 %) · `reviews` (100 swipes).
* `shape`: `square` or `wide`. `color`: `red` `wine` `peach` `gold` `green` `teal` `blue` `violet` `ink`.
* `text`: at most 12 characters stamped into the wax (a word, a number, a kanji). Leave `""` when the picture says it.
* `img`: a **transparent PNG cut-out** (an emblem, a symbol, a silhouette: the Konoha leaf, a Jolly Roger, a
  trophy, a ball). Fetch it with kind `seal` and an id starting with `seal-`. The gate flags pictures that are
  not cut-outs. SVG files on Commons, Wikipedia or a Fandom wiki render as transparent PNGs: prefer them.
* `art`: `stamp` presses the picture into the wax in one colour, like a real seal (best for symbols and
  silhouettes); `color` keeps the picture's own colours (only for emblems whose colours matter).
* Seal pictures must be clean: one symbol, centred, no background box, no text unless the symbol is text.

Look at your seal pictures on the contact sheet (`sheet`) like any other image.
