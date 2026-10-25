# Fonts

Memory Card is set in two families: a condensed display serif for headlines and deck names, and a condensed
sans for everything you read.

| Font | Where it is used | Where it comes from |
|---|---|---|
| **Bernard MT Condensed** (`BernardMTCondensed.ttf`) | Display type: deck names, headlines, the seal lettering and the home-screen widgets | Monotype. Included here because the app, the web mockup and the promo videos cannot be built or rendered without it |
| **Barlow Semi Condensed** | Body text and buttons | Google Fonts, SIL Open Font License. Fetched by the app the first time it runs and then cached on the phone |
| **JetBrains Mono** | Small numbers and code-like labels | Google Fonts, SIL Open Font License. Fetched like Barlow |
| **Roboto Condensed** | Stand-in for Barlow in the screenshot tests and the promo videos | Apache License 2.0 (`promo/v03-home-screen/assets/fonts/robotocondensed_license.txt`) |

## Where the Bernard file lives

The same file is kept in each place that needs it, so every project builds from a plain checkout:

| Path | Used by |
|---|---|
| `fonts/BernardMTCondensed.ttf` | The shared copy (this folder) |
| `app/assets/fonts/BernardMTCondensed.ttf` | The Flutter app (`app/pubspec.yaml` declares it as the `Bernard` family) |
| `text_Mockup/fonts/BernardMTCondensed.ttf` | The web design lab |
| `promo/v01-you-will-forget-this/assets/fonts/` and `promo/v03-home-screen/assets/fonts/` | The promo videos |

Bernard has no middle dot (·), no euro sign and a few other glyphs, so the app falls back to Barlow for them
(`app/lib/ui/theme.dart`).

## Using a different display font

The app asks for the display font by family name (`T.displayFamily` in `app/lib/ui/theme.dart`), and
`app/pubspec.yaml` maps that name to a file. To swap it, drop another `.ttf` into `app/assets/fonts/`, point the
`asset:` line at it and rebuild. The screenshot tests in `app/test_gallery/` load the file by its old name, so
update the path there too if you run them.
