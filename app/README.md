# Memory Card — the app

The Flutter app: the design canvas ("Memory Card — App Design") built for real, on the engine from
[RES-47](../docs/research/RES-47_Repetition_Engine_Comparative_Research.md) and
[RES-48](../docs/research/RES-48_Engine_v2.md). Everything runs and is stored on the phone: no account,
no server, no analytics.

## Install on an Android phone

1. Copy `../release/MemoryCard-1.0.0.apk` (the same file as `build/app/outputs/flutter-apk/app-release.apk`)
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
| `lib/data/` | Models, the `AppStore` (single source of truth, `ChangeNotifier`), Hive persistence, the bundled catalog, CSV import. |
| `lib/ui/` | Design tokens and typography (`theme.dart`), motion curves and keyframes, sounds and haptics (`fx.dart`), custom shapes (wax seal, folders, polar badges), sheets/dialogs/toasts, coach marks. |
| `lib/features/` | One folder per screen: onboarding, decks, study, drawer, shop, editor, today, profile, settings, browse (deck and card detail), search, Memory Lab, help. |
| `lib/services/` | Daily reminder (local notifications) and text-to-speech. |
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
```

Visual review: `test_gallery/` renders every screen to `build/gallery/*.png` with real fonts, light and
dark, after a simulated two weeks of study:

```bash
flutter test test_gallery/tour_gallery_test.dart
flutter test test_gallery/app_gallery_test.dart
flutter test test_gallery/icon_gen_test.dart   # regenerates the launcher icons from the logo
```

## Hidden tools

Tap the version number in Settings seven times for the **Lab**: move the clock forward (see cards slip,
the warm-up, grace shields) and read the engine's internals.
