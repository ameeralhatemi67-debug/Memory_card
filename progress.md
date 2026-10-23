---
type: changelog
okm_type: dated
project: "[[README|Memory Card]]"
tags:
  - project/memory-card
  - document/progress
  - knowledge/dated
created: 2026-08-13
updated: 2026-10-23
status: active
aliases:
  - Memory Card Progress
  - Memory Card Progress Log
  - Memory Card Verified Outcomes
related:
  - "[[Roadmap|Memory Card Roadmap]]"
  - "[[Status|Memory Card Status]]"
  - "[[feature_checklist|Feature Checklist]]"
  - "[[idea_Audit|Project Audit]]"
---

# Memory Card Progress Log

**Last updated:** 2026-10-23

**Current release line:** Version 2.0 (Design Finalization & Resizable Living Lab)

**Active checkpoint:** Checkpoint 2.1 (Repository Baseline & Feature Checklist)

> [!abstract] Project Navigation
> - **Parent Hub:** [[README|Memory Card Project Hub]]
> - **Future Work:** [[Roadmap|Product Roadmap]]
> - **Present State:** [[Status|Current Status]]
> - **Verification Ledger:** [[feature_checklist|Feature Reverification Checklist]]
> - **Audit Report:** [[idea_Audit|Architectural & UX Audit]]

This document records verified outcomes, technical approaches, and architectural decisions. It is not a second roadmap. Future tasks and their sequencing belong only in [[Roadmap|Roadmap]]; present conditions belong in [[Status|Status]].

---

## Flutter App Outcomes (pulled forward from Version 4.0)

### 2026-10-23 — Deck swipe rebuilt (v1.1.2), more shop categories

- **Outcome Summary:** Swiping a deck bar left and right is smooth: it follows the finger from the first pixel, lets go into a single spring that settles on a detent (at most a couple of pixels of soft overshoot, never a wobble), closes without swinging past, and no longer hitches on the first frame. The shop gains Geography, History & Culture, Anime and Cars categories (the picture decks no longer all sit under Knowledge).
- **How We Built It & Technical Approach:** A frame-by-frame analysis of the owner's 120 fps screen recording (phase correlation of the row band) showed three things: a one-frame spike at the start of every swipe, a bouncy back-and-forth after release (an under-damped hand-made spring chasing an artificial overshoot target), and a hard-edged un-faded strip of the bar at the screen edge. Causes and fixes in `lib/features/decks/deck_row.dart`: (1) the action tiles were inserted before the bar in an unkeyed `Stack`, and a `ShaderMask` was added around the bar only while swiping, so Flutter threw the bar's subtree away (and the live drag recognizer with it) when the swipe began; now the slots are keyed and the fade is a `SinkMask` (`lib/ui/sink_mask.dart`), a mask that stays in the tree and is simply switched off at rest. (2) every tick rebuilt the whole bar (text, fan, textures, shadows); now the swipe state is a notifier that only moves the offset, the tiles and the fade, and the bar is a cached `RepaintBoundary` layer. (3) the release is one `SpringSimulation` that starts at the finger's speed (closing critically damped, opening ζ = 0.74), with a cancel handler. (4) the fade mask spans the whole row, so nothing pokes out unfaded. Touch events are resampled to the frame clock (`GestureBinding.resamplingEnabled`) for steadier drags everywhere.
- **Verification Evidence:** `test/deck_swipe_test.dart` (5 tests): the bar and its fan are not rebuilt by a swipe, a left swipe settles with ≤ 4 px overshoot and no abrupt speed changes, closing never undershoots, the right side and second detent work, a cancelled drag settles; the sampled position traces were also read by eye. The old code failed the same drag in the test harness (it died after the first update). The full suite passes; the new swipe renders were reviewed in light and dark.

### 2026-10-23 — Pictures on cards (v1.1): layouts, a canvas editor, PNG cut-outs, blur before the reveal, 11 picture decks

- **Outcome Summary:** Either side of a card can now hold pictures and text placed where you want them. Pictures can be the answer (with or without words), words can sit over a picture, pictures can be cropped, resized and moved, transparent PNGs stay transparent, and each card is built either in a guided **Structured** mode or on a **Free canvas**. Pictures can be blurred (or hidden) until the reveal, with the strength set in Settings › Study. 11 new picture decks: flags of Africa, Asia, Europe and the Americas, Naruto / One Piece / Hunter x Hunter characters and powers, and car brands.
- **How We Built It & Technical Approach:**
  - Model (`lib/data/card_layout.dart`): a `SideLayout` per side (`CardItem.frontLayout` / `backLayout`, stored with the card; null = the classic text card, so old cards are untouched). A layout is a mode, a template and a list of elements: `ImageEl` (frame, fill or whole, zoom and pan like object-fit, corner radius, plate, outline, blur flag) and `TextEl` (words from the card's own fields or custom, size, align, colour, backdrop, font). Positions are fractions of the face, so one layout fits every phone, the editor preview and thumbnails. The text fields stay the single copy the engine, search, typing and speech use.
  - Editor (`lib/features/layout/layout_editor.dart`): full-screen. Structured = five templates and drag-to-crop; canvas = add pictures and text, move, corner-handle resize (shape lock), a Crop mode that pans and pinches inside the frame and shows the rest of the picture faintly outside it, centre and margin snapping with a tick, z-order, per-element styling, undo. The card form shows both sides as small previews with "+ Picture" quick paths; the buttons are pinned under the form.
  - Bringing pictures in (`lib/services/image_ingest.dart`): gallery, files or camera; the pure-Dart `image` package decodes (EXIF rotation honoured), shrinks to 1,600 px, keeps transparency as PNG and re-encodes photos as JPEG; the phone's own codec is the fallback for formats it cannot read. Backups embed and restore layout pictures.
  - Study: tap and icon modes swap the front for the answer face; flip mode turns it, flagged answer pictures sharpen as they land. The answer picture peeks out blurred behind "Tap to reveal". The card texture sits behind pictures so they stay clean; a memory hook over a picture gets a backing. Reverse cards swap pictures with the words (the original's front picture becomes the reverse's answer).
  - Settings › Study › Pictures before the reveal: Blur / Hide / Show, a strength slider and a live painted preview.
  - Decks: `tools/imgkit.py` (Fandom MediaWiki, flagcdn, Wikidata logo property + Wikimedia Commons; quality gates, optimisation, near-duplicate check, crop for logos, contact sheets, provenance in `content/sources/`) and a handbook (`content/decks/visual/README.md`). Five Claude Haiku 5.5 agents worked in parallel on it; I reviewed every contact sheet and sent the car-brands agent back once because many logos spelled the brand's name (now emblem-only, 61 brands). `tools/build_catalog.py` validates picture decks, measures images and lists their folders in `pubspec.yaml`.
- **Verification Evidence:** 19 new tests (layout model and templates, PNG alpha kept through `ImageIngest.prepare`, blur settings, catalogue layouts, picture decks and reverse cards, backup round trip, study with picture cards in tap and flip modes, the editor: add text and drag it, drag inside a picture to crop and slider-zoom) plus the whole existing suite (all passing); every new screen rendered in light and dark with real fonts and reviewed (`test_gallery/pictures_gallery_test.dart`).
- **Known limits:** anime pictures and car logos are copyrighted / trademarked (see `content/sources/README.md`): fine for a personal study app, not for a public release. Ferrari, Lamborghini, Peugeot, Jaguar, Aston Martin, Jeep, Dodge, Ram and a few others have no free emblem-only file, so they are not in the car deck.

### 2026-10-22 — Textures (Settings › Texture)

- **Outcome Summary:** Surfaces instead of flat colour, on request: a white plaster wall behind every screen in light mode (felt in dark mode), card stock on cards and tiles, kraft folders, wax seals, soft daylight across the wall, plus optional paper grain and vignette. Every element has its own texture choice and strength in a new Texture tab in Settings, with a live preview and a reset.
- **How We Built It & Technical Approach:** `tools/make_textures.py` makes 15 seamless maps from periodic noise (white noise shaped in the frequency domain, so they tile with no seam): plaster, limewash, stucco, painted brick, concrete, slate, felt, card stock, linen, laid paper, pressed, kraft, wax, fine and coarse grain. Each is stored white-where-lighter / black-where-darker with the amount in alpha, so one map works on any colour in either theme with plain alpha blending (no costly blend modes). In the app (`lib/ui/textures.dart`) walls are a repeating image shader under each screen, containers get a foreground decoration, folders and seals a painter clipped to their outline; scroll fades now fade the content itself (a mask) so the wall shows through.
- **Verification Evidence:** texture settings round-trip and old saves get the defaults (`test/texture_settings_test.dart`); the Texture tab drives the stored settings (`test/ui_screens_test.dart`); every screen re-rendered in light and dark and reviewed.


### 2026-10-22 — Memory Card v1.0: the Flutter app, local-only, Android APK

- **Outcome Summary:** The full app, built from the design artifact "Memory Card — App Design" at the owner's request ("a fully working version I can start using on my phone, no publication or backend yet"). Source in `app/`, guide in `app/README.md`, engine in [[RES-48_Engine_v2]].
- **How We Built It & Technical Approach:**
  - Flutter 3.41 / Dart 3.11; Hive local storage; one `AppStore` (`ChangeNotifier`) as the single source of truth; design tokens from the canvas (inverse-ink light/dark), Bernard MT Condensed for display (local only) and Barlow Semi Condensed / JetBrains Mono from Google Fonts, cached after first launch.
  - Engine (MCRE v2): endless stack with 8–20 re-insertion, pacing with a flow guard, warm-up, leeches, resting mastered cards; shadow FSRS-6 equal to the reference `fsrs` package to 1e-9; grades read from think time against a personal robust baseline, drag reversals, commit-line crossings, opposite excursion, release speed and answer-checking time, with an interruption filter; self-tuning Easy/Hard thresholds; per-user calibration multiplier; on-device FSRS training after 150 long-gap reviews.
  - Screens: decks with two-detent swipe actions and progress fans, study stack with swinging ears, grade chip with undo and regrade, folder drawer, Daily mix, shop with long-press quick actions and preview, editor with images, reverse cards and CSV import, Today, profile with the flippable membership card and seals, settings, deck browser, card detail with the forgetting curve, search, Memory Lab, help.
  - Onboarding: a tour you swipe through (recall a card, miss one and see where it goes), topic and deck picker, goal and pace, reminder, your card, then a tutorial deck that teaches the app by using it; spotlight coach marks.
  - Content: 28 original decks plus 28 decks written by Claude Haiku and reviewed (56 decks, 1,355 cards).
  - Extras beyond the canvas: typing mode, text-to-speech, daily reminder whose text names the slipping deck, 20 wax-seal achievements, a MASTERED seal when a whole deck is strong (feature list 14.2), grace shields, comeback seal, deck of the day, similar decks in the preview (10.7), a quick light/dark toggle (2.2), top and bottom list fades (4.2), JSON backup with images, review-log CSV export, a hidden Lab with time travel.
- **Verification Evidence:** `test/` (FSRS reference match, 20 engine tests, model-fitting tests, the swipe tour, onboarding → study → undo, every screen); `test_gallery/` renders every screen to PNG with real fonts after two simulated weeks (light and dark) and was reviewed screen by screen, which found and fixed invisible progress bars, overflows, a missing glyph in Bernard, unreadable overlays and a coach mark that could appear over sheets; `flutter build apk --release` succeeds, and the release APK was installed on an Android emulator (Pixel 5 image) and driven with real touch input: the swipe tour, the refusal hint, the missed-card lesson, the deck picker, the notification permission prompt, the first stack, the first-swipe seal.

## Version 2.0 Outcomes

### 2026-10-21 — Playable prototype v0.1 (all design screens connected)

- **Outcome Summary:** A playable web prototype built from the 16 design-canvas artboards, connected into one app with shared, persistent state, published as a private artifact (https://claude.ai/artifact/VL2PecyNZFkcxaCgsHTZki), source in `prototype/`. Its purpose is to collect detailed notes before the Flutter build.
- **How We Built It & Technical Approach:**
  - Preact + htm modules (no build step); the canvas tokens became CSS variables with an inverse-ink `.dark` theme; gesture code (stepped deck swipes, study stack, drawer motion, shop long-press) ported from the `.dc.html` artboards.
  - `prototype/engine.js` implements RES-47 §5: endless stack with failed-card re-insertion at round(8 + 12 x success rate) in [8, 20], pacing reservoir (Relaxed / Balanced / Intense), shadow FSRS-6 (default parameters) for health, fans, slipping counts and warm-up, 04:00 day boundary, daily goal and grace-shield streaks, and an exportable review log.
  - Real starter content (about 440 cards across 24 library decks and a 12-deck shop), card authoring with images and reverse cards, CSV import, JSON backup export/restore.
  - A Lab panel for in-page notes (claude.ai comments), an engine X-ray of the live stack, and a clock that can be moved forward to see slipping, warm-up and shields.
- **Verification Evidence:** Exercised in a local browser at 1400 x 900 and 375 x 812, light and dark: study (reveal, swipe, keyboard, undo, re-insert distance), deck swipe detents, drawer select/open, card save, shop long-press save-to-folder, profile flip, settings, empty folder, goal celebration, +3-day clock jump (shields used, streak reset). No console errors.

### 2026-10-21 — Audit v2 & Repetition Engine Research (RES-47)

- **Outcome Summary:** Second audit ([[audit_v2_2026-10-21]]) and a comparative study of every repetition approach in the repo against external evidence and a simulation. Decisions taken with the user: build a full interactive design artifact next, then the Flutter app; MVP includes deck/card creation + CSV import; Bernard MT stays for local dev only.
- **Key findings:** RES-12 FSRS-5 formulas contain errors (use the `fsrs` Dart package, FSRS-6, instead). RES-43's 2–5 card ring buffer performed worst in simulation. The original endless stack (Q2.2) performed best or tied at equal study time in 5 of 6 runs and becomes the core of the engine ("Endless Stack + Shadow FSRS", RES-47 §5).
- **Verification Evidence:** `tools/srs_sim/simulate.py` (ACT-R learner, Pavlik & Anderson 2005), with results in `tools/srs_sim/results_h0.025.md` and `results_h0.1.md`. The commercial font file is no longer tracked in git; it remains in earlier history.

### 2026-09-12 — Bernard MT Condensed Typography Integration & Visual Parity (Task 2.2.1.1)

- **Task Reference:** [[Roadmap#Phase 2.2.1: Typography & Asset Calibration|Checkpoint 2.2, Phase 2.2.1, Task 2.2.1.1]]
- **Outcome Summary:** Integrated the authentic **Bernard MT Condensed** typeface across all headlines, folder labels, deck titles, card study terms, action underlays, and badges. Eliminated the font discrepancy where the prototype previously fell back to Cinzel / Plus Jakarta Sans.
- **How We Built It & Technical Approach:**
  - Discovered `BernardMTCondensed.ttf` on the user's system and bundled it into `text_Mockup/fonts/` and project `fonts/`.
  - Configured `@font-face` in `text_Mockup/styles.css` with local system fallbacks and bundled asset loading.
  - Applied `var(--font-display)` across brand titles, folder labels (`.df-title`), deck list titles (`.deck-info h4`), study card terms (`.sc-term`, `.card-term`), action underlays (`.deck-action-underlay-left`, `.deck-action-underlay-right`), shop cards (`.shop-tile h5`), and membership cards (`.em-number`, `.em-holder span`).
  - Added URL hash navigation routing in `text_Mockup/app.js` enabling direct tab and screen testing.
- **Verification Evidence:**
  - Automated headless Chrome screenshots captured at 1280×1200 across all 5 mobile frames and sandbox stages (`screenshot_overview.png`, `screenshot_components.png`, `screenshot_physics.png`, `screenshot_screen_drawer.png`, `screenshot_screen_decks.png`, `screenshot_screen_study.png`, `screenshot_screen_shop.png`, `screenshot_screen_profile.png`).
  - Visual verification confirms 100% typographic match to reference mockups (`Card_stacks_page.png`, `side_drwer.png`, `Cards_page.png`).

### 2026-09-12 — Version 2.0 Roadmap & Core Documentation Alignment (Checkpoint 2.1, Phase 2.1.3)

- **Task Reference:** [[Roadmap#Phase 2.1.3: Documentation Alignment|Checkpoint 2.1, Phase 2.1.3, Tasks 2.1.3.1–2.1.3.4]]
- **Outcome Summary:** Established the canonical four-document knowledge architecture (`README.md`, `Roadmap.md`, `Status.md`, `progress.md`) adhering to proven project standards. Defined the 4-version trajectory (Version 1.0 Done, Version 2.0 Active Design Lab & Resizable Viewport, Version 3.0 Sensory Lab, Version 4.0 Native Flutter Build).
- **How We Built It & Technical Approach:**
  - **Roadmap Architecture (`Roadmap.md`):** Structured across strict Version $\to$ Checkpoint $\to$ Phase $\to$ Task hierarchy with clear North Star, Git commit safety policies, and evidence-backed completion criteria.
  - **Master Hub (`README.md`):** Articulated the primary daily study journey, 5-tier capability truth table, directory architecture, and zero-latency browser launch instructions for `text_Mockup/`.
  - **Status Report (`Status.md`):** Grounded present reality, recording active milestones, immediate next steps for visual discrepancy remediation, and deferred items.
  - **Historical Progress Log (`progress.md`):** Inventoried all verified outcomes dating from initial research to current migration.
- **Verification Evidence:**
  - All 4 core documents generated, linked, and verified in workspace `d:\Agents\main\projects\ideas\memory_card\`.

---

## Version 1.0 Outcomes

### 2026-09-12 — Deep Architectural, UX & Engineering Audit (Checkpoint 1.5, Tasks 1.5.1–1.5.3)

- **Task Reference:** [[Roadmap#Checkpoint 1.5: Deep Architectural, UX & Engineering Audit|Checkpoint 1.5, Tasks 1.5.1–1.5.3]]
- **Outcome Summary:** Conducted an uncompromising, 433-line technical, cognitive, and product audit of the entire Memory Card repository, identifying critical mobile hardware bottlenecks, sensory fatigue risks, and the Day-2 card creation blind spot. Delivered actionable remediation recommendations in `idea_Audit.md`.
- **How We Built It & Technical Approach:**
  - **Hardware Feasibility Analysis:** Evaluated the 120 FPS target (8.33ms frame budget) on Flutter Impeller, identifying frame drops caused by Dart nursery GC pauses during per-frame matrix and OKLCH allocations, and GPU fill-rate limits from 80px Gaussian blur passes.
  - **Behavioral Telemetry Audit:** Identified critical failure modes in the proposed "hesitation metric," proving that passive AFK clamps cannot distinguish cognitive retrieval effort from real-world interruptions.
  - **Cognitive Ergonomics:** Uncovered sensory fatigue caused by 18Hz–43Hz trembling folders and excessive $45^\circ$ card swings during repetitive study sessions.
  - **Product Retention Analysis:** Pinpointed the fatal risk of launching with only 10–20 static pre-made starter decks while deferring card authoring and Anki import, and proposed the "Lean Tactile Deck" True MVP.
  - **Visual Parity Audit:** Itemized every visual discrepancy between `reference/*.png` and `text_Mockup/` (stepped staircase fans, Bernard MT font, dual swipe underlays, corner study edge badges).
- **Verification Evidence:**
  - Full report delivered in [`idea_Audit.md`](file:///d:/Agents/main/projects/ideas/memory_card/idea_Audit.md) (45.7 KB).

### 2026-09-12 — Project Workspace Migration (Checkpoint 1.5)

- **Task Reference:** [[Roadmap#Checkpoint 1.5: Deep Architectural, UX & Engineering Audit|Checkpoint 1.5]]
- **Outcome Summary:** Safely migrated all project files, 20 custom SVG icons, 8 reference mockups, 46 research papers, master specifications, and the interactive web lab from `C:\Users\User\Documents\Amir Ob\projects\Ideas\Future\Memory Card` into the dedicated workspace `d:\Agents\main\projects\ideas\memory_card`.
- **Verification Evidence:**
  - 90+ files verified intact and operational in new workspace directory via `list_dir` and `find_by_name`.

### 2026-08-14 — Living Design System Lab & Interactive 3D Gesture Sandbox (Checkpoint 1.4, Tasks 1.4.1–1.4.4)

- **Task Reference:** [[Roadmap#Checkpoint 1.4: Initial Living Design Lab & Gesture Sandbox|Checkpoint 1.4, Tasks 1.4.1–1.4.4]]
- **Outcome Summary:** Built a zero-latency, self-contained web-based living design system and interactive gesture sandbox in `text_Mockup/` allowing real-time inspection of tokens, 3D swipe physics, conscious folder wiggles, and mobile screen previews.
- **How We Built It & Technical Approach:**
  - **Living Design System (`text_Mockup/index.html`, `styles.css`):** Built responsive desktop layout with module tabs for Overview, Design Tokens, Living Components, Gesture Sandbox, Mobile Screens, and Flutter Dart Code Exporter.
  - **3D Gesture Sandbox (`text_Mockup/app.js`):** Implemented draggable 6-layer card stack with live lateral rotation ($\pm 45^\circ$), scale reduction ($1.0 \to 0.75$), 40% threshold badge slide-ins, and 60% offscreen fling exit promotions.
  - **Conscious Folder Physics:** Implemented multi-harmonic sinusoidal wiggle tremors and real-time OKLCH lightness depth interpolation sliders.
  - **Procedural Web Audio Synthesizer:** Built real-time oscillator-based click, thud, and victory fanfare generation without external audio files.
  - **Custom SVG Glyphs:** Embedded all 20 custom icons directly into JavaScript data structures.
- **Verification Evidence:**
  - `text_Mockup/index.html` launches instantly in modern browsers; interactive physics, audio synthesis, and dark/light theming validated.

### 2026-08-14 — Master Feature Specification & Authoritative Decisions (Checkpoint 1.3, Tasks 1.3.1–1.3.4)

- **Task Reference:** [[Roadmap#Checkpoint 1.3: Concept Specification & Q&A Alignment|Checkpoint 1.3, Tasks 1.3.1–1.3.4]]
- **Outcome Summary:** Authored the comprehensive product blueprint, defining the 3-tier physical hierarchy (Folders $\to$ Decks $\to$ Cards), data schemas, and recording locked user decisions across 13 core architectural questions.
- **How We Built It & Technical Approach:**
  - **Master Brain Dump (`brain_dump.md`):** Detailed entities for Folder, Deck, and Card with behavioral telemetry fields.
  - **Master Feature List (`MC_Feature_list.md`):** Itemized ~118 MVP features and ~39 later update features across 18 product domains.
  - **User Q&A Alignment (`Questions.md`):** Locked decisions on Flutter/Dart target platform, Bernard MT Condensed typography, dual-reveal experimentation, strict 1-level folder hierarchy, and curated starter deck scope.
  - **Custom Iconography (`icons/`, `icons list.md`):** Standardized 20 custom SVG glyphs for light/dark themes.
- **Verification Evidence:**
  - Specifications documented in `brain_dump.md`, `MC_Feature_list.md`, and `Questions.md`.

### 2026-08-13 — Comprehensive Cognitive Science & Physics Research Agenda (Checkpoints 1.1 & 1.2)

- **Task Reference:** [[Roadmap#Checkpoint 1.1: Cognitive Science & Mathematical Modeling|Checkpoints 1.1 & 1.2]]
- **Outcome Summary:** Authored 46 deep technical research papers (`RES-01` to `RES-45`, `FES-46`) covering cognitive models, micro-interaction mathematics, statecharts, shaders, and local-first storage.
- **How We Built It & Technical Approach:**
  - Formulated the exact mathematical transfer functions for 3D card swipe trajectories (`RES-01`), edge-sinking gradient alpha masks (`RES-02`), squash-and-stretch collision dynamics (`RES-03`), and multi-harmonic wiggle oscillations (`RES-07`).
  - Evaluated the FSRS-5 spaced repetition algorithm and DSR cognitive model (`RES-12`), passive dwell time filters (`RES-14`), and active recall blank undercards (`RES-15`).
  - Benchmarked cross-platform architecture (`RES-38`), Flutter Impeller 120 FPS frame budgeting (`RES-39`), local-first SQLite schema design (`RES-28`), and mobile haptics engineering (`RES-45`).
- **Verification Evidence:**
  - 46 research files totaling >3.5MB stored in `research/` and cataloged in `research_check_list.md`.
