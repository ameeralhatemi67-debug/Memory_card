# Memory Card — Playable Prototype (v0.1)

Live (private to the owner): https://claude.ai/artifact/VL2PecyNZFkcxaCgsHTZki

Every artboard of the design canvas ([docs/design](../docs/design/README.md)), connected into one app with shared state.
It exists to collect detailed notes before the Flutter build. It is not the product.

## What is real

| Area | Behaviour |
|---|---|
| Study loop | RES-47 §5.1: right = back of the stack; left = back in `round(8 + 12 × success rate)`, clamped to [8, 20], never closer than 5; reveal before the ears unlock; undo |
| Pacing | Relaxed 80 % / Balanced 75 % / Intense; new decks start with 15 active cards, the rest wait in a reservoir |
| Shadow FSRS-6 | Default parameters, prediction only: memory health, the stepped fan, "slipping" counts, warm-up after 2+ days |
| Day, goal, streak | 04:00 boundary; goal = swipe target or every card slipping at the start of the day seen once; 2 grace shields a month |
| Library | Folders (create, rename, reorder by hold, delete with undo), decks (pin, move, archive/restore, delete with undo) |
| Authoring | Card editor (image, reverse card, edit, delete), CSV/TSV import with separator detection |
| Shop | Search, categories, sort, favourites, long-press quick actions, preview, add to a folder |
| You | Membership card computed from the data, 35-day heatmap, settings that change behaviour, JSON backup export/restore |

All data lives in the browser (`localStorage`). The Lab panel (desktop: right side; phone: the LAB tab) leaves notes on the
current screen, shows the engine X-ray, moves the clock and resets the data.

## Files

`index.html` (styles and tokens), `app.js` (routing, actions, shell, Lab), `engine.js` (stack engine, FSRS, store),
`content.js` (starter decks and shop catalogue), one module per area: `decks.js`, `study.js`, `drawer.js`, `create.js`, `shop.js`, `you.js`.
Preact + htm load from unpkg; there is no build step.

## Run locally

`index.html` is written for the artifact host, which adds the document skeleton. To run it locally:

```bash
python tools/serve_prototype.py prototype 8765
```

Then open http://localhost:8765/.
