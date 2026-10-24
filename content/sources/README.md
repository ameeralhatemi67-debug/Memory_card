# Where the picture-deck images come from

One JSON file per picture deck: for every image, the page it came from, the file name there, a licence
note, the original and stored size, and the date it was fetched. `tools/imgkit.py` writes them.

| Decks | Source | Rights |
|---|---|---|
| Flags (Africa, Asia, Europe, Americas) | flagcdn.com (renders of the public-domain flag artwork) | Flags are not copyrightable artwork; free to use. |
| Car brands | Wikimedia Commons logo files (found through Wikidata's logo property) | Many are public domain because of simple geometry; **all remain registered trademarks of their makers**. Used here to identify the brand. |
| Naruto, One Piece, Hunter x Hunter (characters and powers) | The series' Fandom wikis (pictures of the anime) | **Copyrighted artwork** of the rights holders, used for identification in a personal study app (fair use / fair dealing arguments only). |
| Football crests (English clubs, European giants) | English Wikipedia lead images (club crest SVG renders, most of them non-free files hosted on Wikipedia) | **Trademarks and copyrighted logos of the clubs**, used to identify them in a personal study app. |
| Football legends, stadiums, deck skins and football seal art | Wikimedia Commons / Wikipedia photos (CC BY, CC BY-SA, CC0, public domain; each file's licence is in the deck's provenance JSON) and CC0 Pinhead icons | Free licences, most need attribution (photographer and licence) if the app is published. |
| Anime deck skins and seal art | The series' Fandom wikis (scenery frames, symbols), English Wikipedia (Straw Hat Jolly Roger), Commons (CC0 icons) | Copyrighted artwork of the rights holders, like the anime character pictures. |

**Before the app is published or distributed to other people**, replace or license the anime pictures and
re-check the logo files: a store release needs the rights holders' permission, or original artwork, or
pictures the user supplies themselves. The decks are plain data (`content/decks/visual/*.json` plus
`app/assets/content/img/<deck>/`), so they can be removed from the catalogue without touching code:
delete the deck file and run `python tools/build_catalog.py`.
