# Where the picture-deck images come from

One JSON file per picture deck: for every image, the page it came from, the file name there, a licence
note, the original and stored size, and the date it was fetched. `tools/imgkit.py` writes them.

| Decks | Source | Rights |
|---|---|---|
| Flags (Africa, Asia, Europe, Americas) | flagcdn.com (renders of the public-domain flag artwork) | Flags are not copyrightable artwork; free to use. |
| Car brands | Wikimedia Commons logo files (found through Wikidata's logo property) | Many are public domain because of simple geometry; **all remain registered trademarks of their makers**. Used here to identify the brand. |
| Naruto, One Piece, Hunter x Hunter (characters and powers) | The series' Fandom wikis (pictures of the anime) | **Copyrighted artwork** of the rights holders, used for identification in a personal study app (fair use / fair dealing arguments only). |

**Before the app is published or distributed to other people**, replace or license the anime pictures and
re-check the logo files: a store release needs the rights holders' permission, or original artwork, or
pictures the user supplies themselves. The decks are plain data (`content/decks/visual/*.json` plus
`app/assets/content/img/<deck>/`), so they can be removed from the catalogue without touching code:
delete the deck file and run `python tools/build_catalog.py`.
