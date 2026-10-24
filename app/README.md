# Memory Card — the app

The Flutter app: the design canvas ("Memory Card — App Design") built for real, on the engine from
[RES-47](../docs/research/RES-47_Repetition_Engine_Comparative_Research.md) and
[RES-48](../docs/research/RES-48_Engine_v2.md). Everything runs and is stored on the phone: no account,
no server, no analytics.

## Install on an Android phone

1. Copy `../release/MemoryCard-1.3.0.apk` (the same file as `build/app/outputs/flutter-apk/app-release.apk`)
   to the phone: USB, a cloud drive, or email it to yourself.
2. Open it on the phone. Android asks once to allow installs from that app (Files, Drive, Gmail…): allow it.
3. Install, then open **Memory Card**.

The APK is signed with this computer's debug key, so every newer build installs **over** the old one and
keeps your cards and streak. Before reinstalling from scratch, use *Settings › Your data › Export backup*.

Permissions: internet (only to download the two Google fonts once; they are cached), notifications
(asked only if you turn the daily reminder on) and starting after a reboot (to keep that reminder).

**iPhone:** an iOS build needs a Mac with Xcode; it isn't possible from this Windows machine. The code has
no Android-only parts, so it is the same app once built on a Mac.

## Build from source

Requirements: Flutter 3.41+ (Dart 3.11), Android SDK 36, JDK 17+.

```bash
# The display font is commercial and not in git: copy it in once.
cp ../fonts/BernardMTCondensed.ttf assets/fonts/
flutter pub get
flutter build apk --release        # → build/app/outputs/flutter-apk/app-release.apk
flutter run                        # on a connected phone or an emulator
flutter build web --release --no-web-resources-cdn   # desktop browser preview (build/web)
```

The deck catalog (`assets/content/catalog.json`) is generated from `../content/decks`:
`python ../tools/build_catalog.py`. Sounds come from `python ../tools/make_sounds.py`.

## What's inside

| | |
|---|---|
| `lib/engine/` | The repetition engine, pure Dart: FSRS-6 (`fsrs.dart`), reading how you answer (`assessor.dart`, `baselines.dart`), personal calibration and training (`calibration.dart`, `optimizer.dart`), stack placement (`stack_rules.dart`), the study loop, pacing, goal and streak (`study_engine.dart`), seals, typed answers. |
| `lib/data/` | Models, the `AppStore` (single source of truth, `ChangeNotifier`), Hive persistence, the bundled catalog, CSV import, and `card_layout.dart` (how a card side places its text and pictures). |
| `lib/ui/` | Design tokens and typography (`theme.dart`), motion curves and keyframes, sounds and haptics (`fx.dart`), custom shapes (wax seal, folders, polar badges), sheets/dialogs/toasts, coach marks. |
| `lib/features/` | One folder per screen: onboarding, decks, study, drawer, shop, editor, today, profile, settings, browse (deck and card detail), search, Memory Lab, help; `layout/` draws card sides (`layout_face.dart`) and edits them (`layout_editor.dart`, structured or free canvas). |
| `lib/services/` | Daily reminder (local notifications), text-to-speech, and `image_ingest.dart` (bringing pictures in: PNG transparency kept, big photos shrunk). |
| `assets/` | 56 decks / 1,355 cards, synthesized sound effects, the Bernard font (local only). |

Data lives in Hive boxes on the device (IndexedDB on web). *Settings › Your data* exports a JSON backup
(cards, history and the engine's learned state), restores it, and exports the review log as CSV.

## Tests

Run each file on its own (Hive is global to a test isolate):

```bash
flutter test test/fsrs_test.dart        # FSRS-6 == the reference fsrs package, to 1e-9
flutter test test/engine_test.dart      # stack rules, assessor, pacing, streaks, leeches, warm-up…
flutter test test/model_fit_test.dart   # calibration and on-device training
flutter test test/ui_tour_test.dart     # the swipe tour, card by card
flutter test test/ui_study_test.dart    # onboarding → first stack → swipes, chip, undo
flutter test test/ui_screens_test.dart  # every screen builds; coach marks; shop; editor
flutter test test/layout_test.dart      # layout model, PNG transparency, blur settings, catalogue layouts
flutter test test/layout_store_test.dart # picture decks, reverse cards with pictures, backups
flutter test test/layout_ui_test.dart   # study with picture cards (tap, flip), the layout editor
flutter test test/deck_swipe_test.dart  # the deck bar's swipe: follows the finger, one spring, no wobble, nothing rebuilt
flutter test test/widget_snapshot_test.dart # home-screen widgets: the snapshot, the inbox, answers replayed through the engine, the Look settings
flutter test test/widgets_screen_test.dart  # Settings › Widgets: the look controls and every widget row
```

Visual review: `test_gallery/` renders every screen to `build/gallery/*.png` with real fonts, light and
dark, after a simulated two weeks of study:

```bash
flutter test test_gallery/tour_gallery_test.dart
flutter test test_gallery/app_gallery_test.dart
flutter test test_gallery/icon_gen_test.dart   # regenerates the launcher icons from the logo
flutter test test_gallery/pictures_gallery_test.dart  # picture cards, the layout editor, Settings blur → build/gallery/pic-*.png
flutter test test_gallery/swipe_gallery_test.dart     # a deck bar mid-swipe and on each detent, both ways
flutter test test_gallery/shop_texture_gallery_test.dart  # shop hero, long-press badges, the Texture tab
```

## Pictures on cards

Every side of a card can carry pictures and text (`CardItem.frontLayout` / `backLayout`, a `SideLayout`).
In the editor, tap a side: **Structured** offers five guided shapes (text, picture on top, picture below, full
picture, picture only) and lets you drag inside the picture to crop it; **Free canvas** lets you add any number of
pictures and text boxes, move, resize (corner handles), crop (pan and pinch inside the frame), restyle text (size,
colour, backdrop for reading over pictures) and reorder. PNG cut-outs keep their transparency (`ImageIngest`),
optionally on a paper or dark plate. Positions are fractions of the card, so a layout looks the same everywhere.

Study: a side without a layout is the classic text card. With pictures, tap and icon modes swap the front for the
answer face on reveal; flip mode turns it. **Settings › Study › Pictures before the reveal** (blur · hide · show,
with a strength slider and a live preview) decides what pictures marked *Blur until revealed* do, and the answer
picture peeks out blurred behind *Tap to reveal*. Reverse cards swap pictures along with the words.

Picture decks come from `content/decks/visual/*.json` (see the README there) with images in
`assets/content/img/<deck>/`; `python ../tools/imgkit.py` fetches and checks them and `build_catalog.py` bundles them.

## Home-screen widgets (Android)

Fifteen widgets in the launcher's widget list (or *Settings › Home screen widgets*, where each one has a live
preview, its sizes and an Add button), plus a Quick Settings tile. Sizes are columns × rows; each widget can only be
resized to the sizes it was designed for.

| Widget | Sizes | Tap |
|---|---|---|
| **Daily goal seal**: today's cards against the goal; the red DONE seal once it is met | 2×2 | studies the last deck |
| **Daily goal seal · slim** | 1×1 pill, 2×1 | studies the last deck |
| **Streak flame**: the streak and this month's grace shields; with room, this week and your best; after 18:00 with the goal not met it asks for today | 1×1 to 4×1 | opens Today |
| **Streak flame · tall**: the streak, this week day by day, shields, best | 1×2 | opens Today |
| **Today**: seal, what is left, the streak, reviewed / remembered / relearned, the answers bar, memory health, *Keep going* | 4×2, 4×3 | studies |
| **Quick card**: the card you are closest to forgetting; Reveal, then Again or Got it (stacked, or side by side) | 4×2, 4×3 | the buttons answer; the deck name opens it |
| **Quick actions**: Study, Daily mix, New card, Search as the shop's badges, a card, or four buttons | 1×1 to 4×1, and a 2×2 | goes straight there |
| **Activity**: the study heatmap, five weeks to sixteen | 2×2 to 4×2 | opens Profile |
| **Next two weeks**: cards that start slipping each day | 4×1, 4×2 | opens Memory Lab |
| **Membership card**: tier, name, four numbers; tap to turn it over; your latest seals underneath | 4×2 | turns the card |
| **Memory health**: recall across the library now, cards slipping | 2×1, 2×2 | opens Memory Lab |
| **Card of the day**: a card you know cold, prompt and answer | 4×1, 4×2 | studies that deck |
| **Seals**: the latest seals and the next one in reach | 2×1 to 4×1 | opens the seal gallery |
| **Continue a deck**: deck bars with their progress fans; the Daily mix | 4×1 to 4×3 | studies that deck |
| **Quick Settings tile**: "8 to go · tap to study" | the tile | studies |

*Settings › Home screen widgets › Widgets* changes how they all look, with live previews: **theme** (follow the
phone, light, dark), **accent** (the seal, flame and rings), **corners**, how solid the **background** is, **motion**
(off also while the app's Reduced motion is on), the **face** each widget wears (as designed, paper or ink), and the
Quick card's layout.

How it fits together:

- **The app writes, the widgets draw.** `lib/data/widget_snapshot.dart` builds one JSON snapshot: the day, goal,
  streak, shields, today's answers, 126 days of swipes, the next 14 days of slipping cards, the library's health for
  the next 48 hours (recall only falls while you are away, so the widget can step along it with the app closed),
  membership, seals, decks, cards of the day, the Look settings, and the Quick card's queue (the 12 lowest-recall
  cards, interleaved across decks, new cards left out). `lib/services/home_widgets.dart` saves it through the
  `home_widget` plugin a moment after any change and when the app goes to the background, and books redraws for 04:00
  (a new study day) and 18:00.
- **Every widget draws itself** (`android/app/src/main/kotlin/com/memorycard/memory_card/widgets/`) at the exact size
  the launcher reports, so a design can use whatever the size allows. `Scene.kt` is the drawing board: three layers
  (the face's ink, the ink for lettering on ink, and colours that never change), drawn in dp with the app's Bernard
  face. The launcher tints the layers, with one colour for day and one for night (Android 12), so the theme follows
  the phone without the app running; a forced theme just sends the same colour twice. `SceneWidget.kt` turns a scene
  into RemoteViews: two pages so a change turns or dissolves into the next, tap targets and moving pieces placed in dp.
  `WidgetState.kt` and `StateExt.kt` bring the snapshot up to the present on their own: a new study day starts empty,
  missed days use grace shields or end the streak, as the engine would.
- **Motion** lives in the launcher, not the app: the seal and the shop's badges are ProgressBars turning a shape (each at
  its own speed), the flame is an animated vector that never holds still, rings pulse on "today", a band of light
  crosses cards and bars, and Quick card, the membership card and Card of the day turn over when they change; any
  other change dissolves. Switching motion off in Settings draws stills and removes the transitions. Phones older than
  Android 12 keep the stills (and tap anywhere to open the app).
- **Quick card answers never need Dart in the background.** A tap appends `{card, deck, grade, ts}` to an inbox in
  the widget's storage and shows the next card. When the app next opens (or comes back from the background),
  `AppStore.applyWidgetReviews` replays them through `StudyEngine.swipe` at the time they were given, as mode
  `widget`, Again or Good only, never learning timing from them; then it moves a watermark so nothing is applied
  twice. The seal, streak and every other widget count those answers straight away.
- Taps open `memorycard://study` (optionally `?deck=`), `today`, `mix`, `new`, `search`, `profile`, `lab` or `seals`,
  routed in `lib/app.dart`. Flutter's own deep linking is turned off in the manifest so it does not push a second home
  screen over that.
- After an APK update Android shows each widget's placeholder layout again; the widgets listen for
  `MY_PACKAGE_REPLACED` and redraw themselves from the last snapshot without waiting for the app.
- Sizes: each provider in `res/xml/wg_*_info.xml` sets its first and largest size from what the Pixel launcher really
  does, not from the docs: it rounds up and ignores `targetCellWidth` for the first size (290 dp wide gives four
  columns, 110 dp tall two rows; caps of 190, 300 and 160 dp stop at two rows, three rows and two columns). Check a
  change by opening the widget picker and by dragging a resize handle.
- Development: the debug build has a receiver to drive the widgets over adb (`DebugReceiver.kt`): `PIN` places one,
  `DUMP` draws every widget at every size, light and dark, into PNGs (used to make the widget picker previews in
  `res/drawable-*nodpi`), `INFO` prints how Android read each widget's size limits.

## Hidden tools

Tap the version number in Settings seven times for the **Lab**: move the clock forward (see cards slip,
the warm-up, grace shields) and read the engine's internals.
