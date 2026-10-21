# Memory Card — Design Canvas

Live, interactive design: https://claude.ai/artifact/2zRQWJ3mF2x1hezhZL9A3u (private to the owner).

`canvas/` holds the source of every artboard (`*.dc.html`) and the canvas index (`canvas.json`).
They are the reference the Flutter build is checked against.

| Row | Artboards |
|---|---|
| 1 · Study loop | Main (decks), Study (interactive stack), Goal |
| 2 · Library | Drawer, DeckActions (swipe states), EmptyFolder |
| 3 · Create & discover | Editor (card + CSV import), Shop (2/3/4-column tweak), ShopHold, Preview |
| 4 · You | Profile (stats membership card), Settings |
| 5 · Dark mode | DarkMain, DarkStudy, DarkDrawer, DarkProfile |

Tokens (from the reference PNGs): ink `#333333`, paper `#F1F1F1`, red `#D35F5F`, delete `#FF8080`,
peach `#FFC680`, blue `#80AEFF`. Rule: surfaces are the inverse of the canvas ("inverse ink").
Display font: Bernard MT Condensed (local only, see audit F3), fallback Noto Serif Display condensed;
text font: Barlow Semi Condensed. Icons: `icons/*.svg` converted with `tools/icons2inline.py`.
