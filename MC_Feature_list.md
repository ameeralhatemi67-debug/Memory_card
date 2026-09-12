---
type: architecture
tags:
  - memory-card
  - feature-list
  - mvp-scope
  - product-roadmap
  - project-planning
created: 2026-08-14
updated: 2026-08-14
---

# 🗂️ Memory Card — Complete Feature List

> **Parent Hub:** [[Ideas]] | [[Ideas/Future]] | [[Main Work Flow]]
> **Source Documents:** [[Ideas/Future/Memory Card/brain_dump.md|brain_dump.md]] | [[Ideas/Future/Memory Card/brain_storming.md|brain_storming.md]] | [[Ideas/Future/Memory Card/Questions.md|Questions.md]] | [[Ideas/Future/Memory Card/research.md|research.md]] | [[Ideas/Future/Memory Card/research_check_list.md|research_check_list.md]]

---

## 📖 How to Read This Document

Every feature is listed with:
- **`[MVP]`** — Ships in the first version.
- **`[LATER]`** — Deferred to a future update.
- Sub-features are nested under their parent.
- Features are grouped by **product area** in the order a user encounters them.

---

# ═══════════════════════════════════════════════════
# 📦 PART 1: MVP FEATURES (Version 1.0)
# ═══════════════════════════════════════════════════

---

## 1. Platform & Tech Stack

| # | Feature | Decision Source |
|---|---------|-----------------|
| 1.1 | **Flutter / Dart** mobile-first native app (Impeller engine) | Q1.2 |
| 1.2 | **iOS + Android** dual-platform release | Q1.1 |
| 1.3 | **120 FPS target** on all gesture-driven screens (8.33ms frame budget) | RES-39 |

---

## 2. Application Shell & Navigation

| # | Feature | Details |
|---|---------|---------|
| 2.1 | **Top Header Bar** | Left: App logo glyph (tap opens Side Drawer). Right: 3-dot menu icon. |
| 2.2 | **3-Dot Dropdown Menu** | Contains: Dark/Light mode toggle, Settings link, Send Feedback link. Minimal and paper-thin. | 
| 2.3 | **Bottom Navigation Bar** | 3 items: `[🏠 Home]` (Active Decks), `[⬡ + Create]` (Context-Aware), `[🛍️ Shop]` (Deck Shop). |
| 2.4 | **Context-Aware Create Button** | Inside a folder → creates a Deck. Inside a deck → creates a Card. Does NOT create folders (folders are created from the side drawer). |
| 2.5 | **Light Mode + Dark Mode + System-Adaptive** | Full theming support from day one. Sun/Moon toggle in dropdown. |
| 2.6 | **Custom Typography** | "Bernard MT Condensed" as the primary UI font. Card content supports additional experimental fonts. |
| 2.7 | **Custom Icon Set** | 20 custom SVG glyphs: logo (light/dark), folder, home, shop, burger dots, settings, sun, search, filter, box, done, delete, archive, move, pin, share, save, apple, google. |

---

## 3. The Conscious Side Drawer (Folder Stack)

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 3.1 | **Skewed Folder Stack** | Folders rendered as offset stacked shapes with distinct vertical tab offsets. | RES-44 |
| 3.2 | **Inverted Z-Index Depth Illusion** | Top folder (first in array) is lightest in color; bottom folder (last in array) is darkest. Visual depth contradicts z-order intentionally. | RES-08 |
| 3.3 | **OKLCH Real-Time Color Interpolation** | Dragging a folder up/down smoothly re-interpolates its lightness/darkness in the perceptually uniform OKLCH color space. | RES-08 |
| 3.4 | **Parametric Bézier Folder Silhouettes** | Asymmetric curved folder shapes using parametric cubic Bézier paths with C¹ continuity. Custom `RenderBox` for non-rectangular hit-testing. | RES-44 |
| 3.5 | **Peeking Deck Spine Tabs (Max 3)** | Selecting a folder animates up to 3 colored file tabs protruding from the folder spine with elastic staggered bounce (35ms per tab). | RES-09, RES-44 |
| 3.6 | **Cyclic 3-Color Tab Permutation** | Tab colors cycle in non-repeating ℤ₃ order: [Blue, Yellow, Red] → [Yellow, Red, Blue] → [Red, Blue, Yellow]. Represents the last 3 used decks. | RES-44 |
| 3.7 | **Hold & Drag Folder Reordering** | Long-press a folder to lift it with drop-shadow bloom. Dragging up → lighter tint (deeper in stack). Dragging down → darker tint (higher in stack). | brain_dump |
| 3.8 | **Emotional "Conscious" Folder States** | | |
|     | → Delete Mode (Fear) | All folders zoom-out-zoom-in pulse, then continuous nervous wiggle. Selected folder for deletion recoils with exaggerated high-frequency tremor. | RES-07 |
|     | → Create/Edit Mode (Excitement) | Background folders wiggle with eager, buoyant bounce when creating a new folder or deck. | RES-07 |
|     | → Deselection (Retraction) | Protruding tabs snap back with elastic retraction. | RES-09 |
| 3.9 | **Multi-Harmonic Wiggle Physics** | Fear: 3 layered sine waves (18Hz, 29.1Hz, 43.7Hz) with Perlin noise perturbation. Excitement: bouncy spring with overshoot. | RES-07, RES-44 |
| 3.10 | **Strict 1-Level Hierarchy** | Folders → Decks → Cards. No nested sub-folders. | Q3.2 |
| 3.11 | **Create Folder** | Dedicated `[+ Folder]` button at the bottom of the side drawer. Opens a modal to name the folder. | brain_dump |
| 3.12 | **Empty Folder State** | Displays "Empty Mind" text, "Look for something to remember" link (navigates to Shop), and a "Create a Deck — Coming Soon" label. Illustration of a brain with "???". | Q9.2 |
| 3.13 | **Folder Fade-to-Background** | Bottom of the folder list fades smoothly into the base background color rather than hard-clipping. | brain_dump |

---

## 4. Decks List Page (Inside a Folder)

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 4.1 | **Vertical Deck Card List** | Wide horizontal deck cards. Each shows deck title, creator metadata, and a stylized 3D layered card-stack silhouette on the right. | brain_dump |
| 4.2 | **Boundary Fade (Top & Bottom)** | Decks smoothly fade into the background color as they scroll out of view. No hard-clip at edges. | brain_dump |
| 4.3 | **Left Swipe → Delete / Archive** | Swiping left reveals a red `[✖ Delete]` action. Extended swipe reveals amber `[⬇ Archive]`. The trailing edge of the card sinks into the background using adaptive gradient opacity masking (not a hard cut). | RES-02 |
| 4.4 | **Right Swipe → Move to Folder** | Swiping right reveals a blue `[» Move]` action. | brain_dump |
| 4.5 | **35% Threshold Lock** | Swiping past 35% locks the action open on release. Below 35% → spring snap-back. | brain_dump |
| 4.6 | **Overshoot & Squash Collision** | Released past threshold: the action block springs out with +12% overshoot. The deck squishes horizontally on contact before settling at equilibrium. Damped harmonic oscillator (ζ = 0.72, ωₙ = 28 rad/s). | RES-03 |
| 4.7 | **Edge-Sinking Gradient Shaders** | Trailing card edge blends into canvas using custom fragment shaders (SkSL/GLSL) rather than cutting off at screen border. | RES-02 |
| 4.8 | **Long Press & Drag Reorder** | Long-pressing a deck lifts it with drop-shadow bloom for drag-and-drop reordering within the folder. | brain_dump |

---

## 5. Card Study Session (6-Tier 3D Stack & Swipe Engine)

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 5.1 | **6-Tier Visible Depth Stack** | Deck presented as 6 stacked card layers with progressive scale reduction and vertical offset. Lower cards are blank silhouettes. | brain_dump |
| 5.2 | **3D Swipe Physics** | Lateral displacement (X, Y) + adaptive scale reduction (1.0 → 0.75 at max) + dynamic rotation (up to ±45°) + parabolic downward drift. All continuously mapped to finger displacement. | RES-01 |
| 5.3 | **60% Commitment Threshold** | Releasing at ≥60% commits the swipe action and triggers exit animation. Releasing <60% → damped spring snap-back to (0, 0, rot:0, scale:1). | brain_dump |
| 5.4 | **40% Indicator Reveal** | At 40% displacement, an indicator badge slides in from the corner. Left → `[🗃️ Box]` "Review More". Right → `[✓ Done]` "Mastered". | brain_dump |
| 5.5 | **Progressive Next-Card Reveal** | As top card is swiped past 40%, the blank second-tier card transitions in color and progressively fades in its title and media content. Acts as a real-time visual loader. | RES-15 |
| 5.6 | **Tier 6 Spawn on Commit** | After a commit, Tier 2→1 promotion cascades. A new blank card fades into Tier 6 at the bottom of the stack. | brain_dump |
| 5.7 | **Card Reveal Modes (3 Options, User Picks)** | | Q2.1, Q11.3 |
|     | → Mode A: Tap to Flip (3D) | Card physically rotates 180° in 3D to show the back face. | |
|     | → Mode B: Color Transform Reveal | Front face smoothly transforms to a different accent color as the answer content wipes in. | |
|     | → Mode C: No Flip (Front Only) | Card has no hidden info; user swipes directly based on self-assessment. | |
| 5.8 | **Adaptive Re-Insertion Queue** | Swiped-right cards go to the very back of the stack. Swiped-left cards go back N positions, where N is dynamically calculated using confidence score, hesitation, memory stability, and session position. | RES-43, Q2.2 |
| 5.9 | **Dual-Queue Memory Engine** | Tier 1: Active Working Ring Buffer (W ∈ [5, 7]). Tier 2: Master Long-Term Queue. Dynamic re-insertion formula N* = f(C, Hₛ, S, D, L_session, W_active). Forgetting threshold targeting R* ≈ 0.80–0.88. | RES-43 |
| 5.10 | **Multi-Touch Interruptible Gestures** | User can catch a card mid-flight after a fast fling to reverse an accidental swipe, or interrupt an ongoing spring reset. Pointer capture hijacking + zero-latency animation preemption. | RES-04 |
| 5.11 | **Gyroscope 3D Parallax** | Tilting the phone shifts the 6 card layers with realistic multi-plane parallax depth + dynamic specular sheen on embossed borders. Battery-efficient sensor sampling with low-pass filtering. | RES-05 |
| 5.12 | **Dynamic Canvas Ambient Glow** | Dark backdrop softly glows with blurred ambient gradients extracted from the current top card's dominant color palette (K-Means quantization). Cross-fades during swipe transitions. | RES-10 |

---

## 6. Card Content & Rich Editor

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 6.1 | **Card Content Types (MVP)** | Text + Image per side. Audio exists in pre-made cards but user audio recording is "Coming Soon" for MVP. | Q11.1 |
| 6.2 | **Rich Text Editor** | Full formatting toolbar: font size, font family, bold, italic, alignment (left/center/right), bullet list, numbered list, checklist. | Q11.2 |
| 6.3 | **Image Editor** | Import from camera/gallery. Edit: resize, crop, border radius, placement/alignment within the card. | Q11.2 |
| 6.4 | **Bottom Sheet Card Creator** | Card editor appears as a bottom sheet with input fields for front content, back content, and optional image attachment. | Q11.2 |
| 6.5 | **Pre-Made Cards Support Audio** | Curated starter decks include audio pronunciation. Users cannot record their own audio in MVP, but the playback engine is fully built. | Q11.1 |

---

## 7. FSRS-5 Spaced Repetition Engine

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 7.1 | **On-Device FSRS-5.0 Algorithm** | Pure mathematical implementation: continuous retrievability R(t), stability S, difficulty D. No cloud dependency. | RES-12 |
| 7.2 | **Hesitation Score (Hₛ)** | Normalized 0.0–1.0 metric calculated from: time to first touch, swipe oscillation count, drag velocity, hold duration, direction reversals. High hesitation on a "Mastered" swipe still increases review frequency. | RES-13 |
| 7.3 | **Confidence Score (Cₛ)** | Combines historical swipe ratios with recent hesitation scores to dynamically place the card into optimal spaced repetition buckets (review in 4h, 1d, 3d, 10d, 30d). | brain_dump |
| 7.4 | **Passive Dwell Time Tracking** | Starts the millisecond the card top-layer is revealed. Records reading time per card in milliseconds. | brain_dump |
| 7.5 | **AFK / Distraction Filter** | If no touch or motion occurs within 30 seconds → AFK detection clamps the recorded dwell time. Uses exponential moving average dwell baselines and optional accelerometer micro-motion verification. | RES-14 |
| 7.6 | **Interleaved Practice Scheduling** | When studying multiple decks in a folder, the queue dynamically interleaves cards from different decks for better long-term retention (vs sequential blocked practice). | RES-17 |
| 7.7 | **Smart Push Notifications** | FSRS calculates what's due. A notification fires at a user-set time (e.g., 7 PM): "You have 24 cards due in German Basics." | Q13.3 |

---

## 8. Telemetry & Behavioral Analytics

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 8.1 | **High-Frequency Touch Telemetry** | Logs touch coordinates, swipe velocity, oscillation patterns, and hesitation events per card review at millisecond precision. | RES-31 |
| 8.2 | **Tiered Roll-Up Compaction** | Raw logs retained 14 days → daily learning summary rollups retained indefinitely in compact format → automated monthly SQLite VACUUM. | RES-31 |
| 8.3 | **Zero-Knowledge On-Device Retention** | All telemetry data stays on-device. No server upload. User owns all data. | RES-31, Q7.1 |
| 8.4 | **Data Export (JSON)** | User can export their full learning history, deck data, and telemetry as a JSON dump for portability. | RES-31 |

---

## 9. Local-First Database (SQLite)

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 9.1 | **SQLite + Drift ORM** | Local-first relational schema: `folders`, `decks`, `cards`, `review_telemetry_logs`, `user_preferences`. | RES-28 |
| 9.2 | **Sub-16ms Read/Write Queries** | B-Tree composite indexing, prepared statements, WAL mode, PRAGMA optimizations (mmap_size, synchronous, cache_size). Guaranteed for 120 FPS animation sync. | RES-28 |
| 9.3 | **Migration Versioning Engine** | Automatic backward-compatible schema upgrades with numbered migration files. | RES-28 |
| 9.4 | **100% Offline Guest-First** | All data stays on local device. No account required. No internet required for any core feature. | Q7.1 |

---

## 10. Pinterest-Style Deck Shop

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 10.1 | **6-Row Staggered Masonry Grid** | Horizontal scrollable rows of card tiles in a Pinterest-style staggered layout. | RES-23, brain_dump |
| 10.2 | **Search Bar + Filter** | Top search bar with adjacent `[⚞ Filter]` button. FTS5 full-text search with BM25 ranking and prefix matching. | RES-27 |
| 10.3 | **Curated Official Starter Decks** | Ships with 10–20 pre-built decks across categories: Language (Spanish, French, Arabic, English, German levels), Coding (Python, Dart, C++). | Q5.1, Q9.1 |
| 10.4 | **Long-Press Reactive FAB** | Long-pressing a deck card dims the viewport (85% opacity + 12px blur) and pops up a radial floating action cluster: `[📌 Pin]`, `[✈️ Share]`, `[🔍 Search Similar]`, `[💾 Save]`. | RES-24, RES-25 |
| 10.5 | **Living Floating FAB Motion** | FAB options carry continuous subtle organic bobbing motion while visible. | brain_dump |
| 10.6 | **Edge Collision Avoidance** | If the user long-presses near a screen edge, the FAB cluster dynamically repositions inward so no buttons clip outside the viewport. Polar-to-cartesian with angular fan reflection. | RES-24 |
| 10.7 | **Deck Preview Bottom Sheet** | Tapping a shop card opens a bottom sheet with: mini swipeable card preview stack, metadata (author, card count, tags, description), and "Similar Decks" recommendations. | RES-26 |
| 10.8 | **Save to Folder Workflow** | Saving a deck from the shop places it into the user's selected folder. | brain_dump |
| 10.9 | **Viewport Dimming & Focus Isolation** | Long-press dims the background using inverted vignette mask shaders. Single-pass compositing to avoid GPU memory waste. Damped spring entrance/exit transitions. | RES-25 |

---

## 11. Audio & Sound Design

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 11.1 | **Subtle Micro-Clicks by Default** | Minimalist paper/wooden clicks on swipe, drag, and threshold crossing. No full soundtrack. | Q4.1 |
| 11.2 | **One Signature Sound Design** | No switchable sound themes. One cohesive sound identity unique to Memory Card. | Q4.2 |
| 11.3 | **Procedural Audio Synthesis** | All micro-sounds generated on-the-fly using native audio graphs. Zero bundle size for audio assets (except pre-made card pronunciation audio). | RES-18 |
| 11.4 | **Depth-Scaled Folder Drag Ticks** | Wooden/paper clicks that pitch up as folders are dragged through lighter layers, and pitch down through darker layers. | RES-19 |
| 11.5 | **Velocity-Tied Spatial Audio Panning** | Swiping left pans audio to the left stereo channel; right → right. Volume scales with swipe velocity. | RES-20 |
| 11.6 | **60% Commit Thud** | Crisp tactile thud when a card crosses the 60% commitment threshold. Low-frequency impulse (90Hz). | brain_dump |
| 11.7 | **Celebratory Win Fanfare** | Dynamic ascending harmonic chord progression on completing a deck study round. Procedurally synthesized polyphony. | RES-22 |
| 11.8 | **Emotional Folder Chimes** | High-pitch rapid tremolo when folders enter delete-fear mode. Bright chord progression on create-folder excitement. | brain_dump |

---

## 12. Haptic Feedback Engine

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 12.1 | **Layered HapticService Architecture** | Abstract `HapticService` → `IOSHapticService` (CHHapticEngine), `AndroidHapticService` (VibrationEffect.Composition), `FallbackHapticService` (HapticFeedback.*). | RES-45, RES-21 |
| 12.2 | **15 Mapped Gesture-to-Haptic Interactions** | Card swipe commit (right = success pop, left = medium thud), card flip (light tick), cloze reveal (soft click), folder drag slot ticks (selection ratchet), deck tab pop-outs (staggered soft ticks), FAB long-press open (heavy thud), and more. | RES-45 |
| 12.3 | **Custom AHAP Waveforms (iOS)** | Full CHHapticEngine patterns: card swipe crescendo, deck graduation stamp, session triumph sequence, folder fear tremor (multi-harmonic continuous). | RES-45 |
| 12.4 | **VibrationEffect.Composition (Android)** | 9 primitives (CLICK, TICK, THUD, POP, RISE, SPIN, SLOW_RISE, QUICK_RISE, QUICK_FALL) with per-primitive scaling and delay chaining. | RES-45 |
| 12.5 | **Battery-Aware Throttling** | Skip haptics if battery < 15% or if last haptic was < 50ms ago. | RES-45 |
| 12.6 | **Accessibility Toggle** | User can disable haptics entirely in Settings. Respects system-level reduced-motion preferences. | RES-45 |
| 12.7 | **Audio-Haptic Synchronization** | Parallel dispatch maintaining ±20ms binding window for crossmodal perceptual enhancement (+20–40% perceived intensity). | RES-45 |

---

## 13. Authentication & User Profile

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 13.1 | **Guest-First (No Mandatory Account)** | App fully functional offline with zero account creation. | Q7.1 |
| 13.2 | **Optional OAuth Sign-In** | Google + Apple sign-in for optional cloud backup. Custom "Memory Card Pass" auth. | brain_dump |
| 13.3 | **Tactile Login Screen** | Interactive embossed "Credit/Membership Card" design. Curved decorative sweep. | brain_dump |
| 13.4 | **Profile Card with Tier Shader** | User profile card transforms visually (Bronze → Silver → Gold → Emerald → Diamond → Obsidian Black) based on Composite Mastery Score (CMS). May also display as a badge. Both will be experimented with. | Q8.1, FES-46 |
| 13.5 | **CMS Progression Formula** | CMS = 10·M + 2500·R̄² + 400·ln(1+Streak) + 150·D. Mastery count, retention quality, streak (log-dampened), completed decks. | FES-46 |

---

## 14. Gamification (MVP Tier)

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 14.1 | **Soft Streak with Grace Shields** | Prominent daily streak counter on home screen. Protected by 2 monthly auto-replenishing grace shields. If streak breaks → 48h "Frozen Embers" state allows recovery via double review session. Milestone celebrations at 7, 30, 100 days. | FES-46, Q10.1 |
| 14.2 | **Wax Seal Deck Mastery Celebration** | Completing a full deck loop triggers a 3D wax seal stamping "MASTERED" + explosive confetti particle physics + haptic triumph sequence. | RES-11 |
| 14.3 | **Holographic Card Foil** | When a user achieves 100% mastery on a card across 5 successive spaced intervals, the card receives a gyroscope-reactive metallic foil border. | brain_storming |

---

## 15. Settings Screen

| # | Feature | Details |
|---|---------|---------|
| 15.1 | **Account Management** | View/edit profile, sign in/out of OAuth. |
| 15.2 | **Notification Preferences** | Enable/disable push notifications. Set preferred reminder time. |
| 15.3 | **On/Off Feature Toggles** | Toggle haptic feedback, sound effects, gyroscope parallax, reduced motion mode. |
| 15.4 | **Card Reveal Mode Selection** | Choose between: Tap to Flip (3D), Color Transform Reveal, or No Flip (Front Only). |
| 15.5 | **Theme Selection** | Light / Dark / System-Adaptive. |
| 15.6 | **Data Export** | Export all learning data as JSON. |
| 15.7 | **Send Feedback** | Link to feedback form/email. |

---

## 16. Accessibility & Inclusion

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 16.1 | **Reduced Motion Mode** | Replaces 45° rotations and wiggles with clean 200ms opacity cross-fades. Zero tilt parallax. | RES-41 |
| 16.2 | **Screen Reader Support (VoiceOver / TalkBack)** | Semantic labels on all 6 tiers. Non-gestural review buttons ("Mark as Mastered", "Mark for Review"). ARIA live regions. | RES-41 |
| 16.3 | **Dynamic Type Autoscaling** | Non-linear logarithmic transfer curves supporting up to 312% iOS Dynamic Type and 200% Android font scaling. Auto-shrink binary search, auto-wrapping titles, expandable bottom-sheet reading drawers for large text. | RES-42 |
| 16.4 | **48×48dp Touch Targets** | WCAG 2.2 AAA minimum touch target enforcement across all interactive elements. | RES-42 |
| 16.5 | **RTL Layout Inversion** | For Arabic, Hebrew, Persian, and Urdu: swipe semantics invert (Left = Mastered, Right = Review), drawer spine tabs mirror, action button anchors flip. | RES-40 |

---

## 17. Onboarding & First-Launch Experience

| # | Feature | Details |
|---|---------|---------|
| 17.1 | **Interactive Onboarding Tour** | 3–4 step animated walkthrough demonstrating swipe gestures, folder drawer, and shop using a real sample deck. Planned after all features are finalized. | 
| 17.2 | **Pre-Installed Starter Content** | 2–3 folders pre-loaded: "Languages" (Spanish, French, Arabic, English), "German" (leveled decks), "Coding" (Python, Dart, C++). Each folder has 3–4 decks. |
| 17.3 | **Empty State: "Empty Mind"** | When a folder has no decks: brain illustration with "???", "Empty Mind" headline, "Look for something to remember" link → Shop, "Create a Deck — Coming Soon" label. |
| 17.4 | **Empty State: Shop-Forward** | When the entire app is empty of user content, the home state surfaces a curated "Start Here" mini-row from the shop. |

---

## 18. Performance & GPU Optimization

| # | Feature | Details | Research |
|---|---------|---------|----------|
| 18.1 | **Custom RenderBox / CustomPainter** | Complex shapes (folder silhouettes, masks) rendered via custom Impeller primitives, not nested widget trees. | RES-44 |
| 18.2 | **GPU Layer Flattening** | Render-tree virtualization and off-screen canvas caching to maintain 120fps during rapid swiping with 6-layer stacks. | RES-39 |
| 18.3 | **Single-Pass Shader Compositing** | Backdrop dimming, gradient masks, and ambient glow rendered in single GPU passes to avoid multi-pass offscreen frame buffer allocations. | RES-25, RES-39 |
| 18.4 | **SkSL / Impeller Shader Warmup** | AOT-compiled shaders to eliminate first-frame jank on cold launch. | RES-39 |

---

# ═══════════════════════════════════════════════════
# 🔮 PART 2: LATER UPDATE FEATURES
# ═══════════════════════════════════════════════════

> The features below are explicitly deferred based on user decisions in [[Ideas/Future/Memory Card/Questions.md|Questions.md]]. They are organized by priority within their domain.

---

## 🔮 19. Card Content Expansion (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 19.1 | **User Audio Recording on Cards** | User can record audio pronunciation directly in the card editor. Playback engine already built in MVP; recording UI is deferred. | Q11.1 |
| 19.2 | **Video Content on Cards** | Embed video clips in card front or back. | Q11.1 answer |
| 19.3 | **YouTube Link Embedding** | Paste a YouTube URL into a card; it auto-embeds the video player. | Q11.1 answer |
| 19.4 | **Cloze Deletion Cards** | Text with interactive tap-to-reveal blanks. Custom rich text parser, inline tap targets, cloze hint state machines. | RES-33 |
| 19.5 | **Image Occlusion Cards** | Diagrams (anatomy, maps) with colored masking tape that peels off on tap with sticker-peel animation. SVG path hit-testing. | RES-34 |
| 19.6 | **Audio-First Blind Testing Cards** | Card front shows only animated soundwave. User swipes to grade auditory recognition before revealing text. | RES-35 |

---

## 🔮 20. User Card & Deck Creation (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 20.1 | **User-Created Decks** | Users can create their own decks from scratch within any folder. Full deck metadata editor (title, description, cover image, tags). | Q5.1 answer |
| 20.2 | **User-Created Cards (Full)** | Full card creation with text + image + audio + video. The MVP card editor supports text + image only; audio recording deferred. | Q11.1 |

---

## 🔮 21. Community & Social (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 21.1 | **Open Community Publishing** | Users can publish and share public decks with tags, descriptions, and cover art to the Shop. | Q5.1 |
| 21.2 | **Deck Branching / Forking ("Git for Flashcards")** | Fork a community deck, add personal mnemonic cards, pull upstream updates from the original creator. DAG commit model with three-way merge. | RES-32 |
| 21.3 | **Curator Verified Badges** | Master educators / polyglots can publish verified premium decks with high-fidelity audio, custom illustrations, and curated memory paths. | brain_storming |
| 21.4 | **Smart Deck Bundles** | Creators can bundle multiple related decks under a branded Folder (e.g., "Full Medical Anatomy: Bones, Muscles, Nerves"). | brain_storming |
| 21.5 | **Deck Marketplace with Revenue Share** | Free app, but creators earn a % of revenue when users purchase their premium decks. | Q13.2 answer |
| 21.6 | **1v1 Memory Duels** | Synchronous or asynchronous multiplayer: both players receive the same 15-card stack. Points for speed + accuracy. Ghost opponent indicator. | brain_storming |

---

## 🔮 22. AI Co-Pilot & Automation (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 22.1 | **YouTube to Deck Generator** | Paste a video URL → extracts transcript → identifies key takeaways → generates a 20-card deck with timestamps. | RES-36, Q6.1 |
| 22.2 | **PDF / Document to Deck** | Drop a PDF syllabus → AI categorizes content into nested Folders and Decks automatically. | RES-36 |
| 22.3 | **Camera OCR & Smart Highlight** | Snap a photo of a textbook page → tap key sentences → instant cloze flashcards. | brain_storming |
| 22.4 | **Neuro-Mnemonic Suggestion Engine** | If a user fails a card >3 times, AI suggests personalized mnemonic devices. | brain_storming |
| 22.5 | **AI-Assisted Card Editing** | User types a word → AI suggests definitions, example sentences, audio phonetics, and icons. | Q6.1 |

---

## 🔮 23. Gamification Expansion (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 23.1 | **Memory Garden Ambient Biome** | Living vector flora that grows/wilts based on FSRS-5 memory stability per folder. Skia canvas shaders with procedural growth. No guilt-based punitive mechanics. | FES-46, Q10.2 |
| 23.2 | **60-Second Memory Sprint** | Time-attack speed-run mode. Rapid-fire swiping with streak multiplier and particle trails. Isolated from core FSRS-5 metrics to avoid corrupting retention data. | FES-46, Q10.4 |
| 23.3 | **Obsidian Black Deck Finish** | Reserved for entire completed decks — unlocks a luxury dark tactile theme variant for the deck card visual. | brain_storming |
| 23.4 | **Dunbar-Sized Leaderboards** | 30-user micro-leagues with dynamic weekly promotion/relegation. Localized friend leaderboards. Asynchronous ghost duels. | FES-46 |

---

## 🔮 24. Multi-Device Sync & Cloud (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 24.1 | **Multi-Device Offline Sync (CRDTs)** | Study on phone during commute, edit decks on tablet. State-based CRDTs (Yjs/Automerge) for deck structure and card ordering. | RES-29 |
| 24.2 | **PowerSync / ElectricSQL Backend** | Syncing local SQLite to backend Postgres via logical replication. | RES-29 |
| 24.3 | **FSRS-5 Merge Rules** | Custom CRDT merge logic for spaced repetition intervals, stability S, and difficulty D. Hybrid Logical Clocks (HLC) for clock skew. | RES-29 |
| 24.4 | **Cloud Backup & Restore** | Requires account sign-in. Full device-to-cloud backup and cross-device restore. | Q7.1 |

---

## 🔮 25. Advanced Audio & TTS (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 25.1 | **On-Device Multi-Dialect TTS** | Generate audio pronunciations in any language with regional dialect support (e.g., High German vs Bavarian). iOS AVSpeechSynthesizer, Android TextToSpeech, Piper ONNX int8 fallback. | RES-37 |
| 25.2 | **DTW Karaoke Boundary Highlight** | Real-time word-level highlighting synced to TTS playback using Dynamic Time Warping. | RES-37 |

---

## 🔮 26. Import / Export Expansion (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 26.1 | **Anki (.apkg) Import** | Parse Anki package files and convert to Memory Card native format. | Q5.2 |
| 26.2 | **Quizlet Import** | Import Quizlet decks via API or export file. | Q5.2 |

---

## 🔮 27. Media Pipeline (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 27.1 | **Content-Addressable Blob Storage (CAS)** | Index media blobs by SHA-256 content hashes to eliminate duplicates. | RES-30 |
| 27.2 | **WebP / AVIF Image Compression** | Real-time encoding with dynamic resolution scaling for card images. | RES-30 |
| 27.3 | **Opus Audio Compression** | 16kbps–24kbps voice encoding for crystal clear pronunciation at minimal storage. | RES-30 |
| 27.4 | **Multi-Tier LRU Cache Eviction** | Dynamic quota allocation (e.g., 500MB max) with background eviction of unpinned shop preview assets. | RES-30 |

---

## 🔮 28. Advanced Interaction Modes (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 28.1 | **Two-Finger Undo / Shake to Reverse** | Quick phone shake or two-finger double tap triggers a reverse-trajectory swoop, pulling the last swiped card back onto the stack. Jerk threshold > 1.8g. | RES-06 |
| 28.2 | **3D Interactive Model Cards** | Embeds touch-rotatable 3D objects (glTF format) for organic chemistry molecules, engine parts, historical artifacts. | brain_storming |

---

## 🔮 29. Security & Privacy Expansion (Later Update)

| # | Feature | Details | Source |
|---|---------|---------|--------|
| 29.1 | **Differential Privacy (DP)** | Laplace noise mechanism for optional federated learning insights without exposing individual user data. | RES-31 |
| 29.2 | **Semantic Vector Search** | On-device MiniLM embeddings (WebAssembly) for semantic similarity search across shop decks ("German grammar" finds "Deutsch Verben"). | RES-27 |

---

# ═══════════════════════════════════════════════════
# 📊 FEATURE COUNT SUMMARY
# ═══════════════════════════════════════════════════

| Category | MVP Features | Later Update Features |
|----------|:---:|:---:|
| Platform & Shell | 9 | — |
| Side Drawer | 13 | — |
| Decks List | 8 | — |
| Card Study Session | 12 | — |
| Card Content & Editor | 5 | 8 |
| FSRS-5 Engine | 7 | — |
| Telemetry | 4 | — |
| Database | 4 | — |
| Shop | 9 | — |
| Audio | 8 | 2 |
| Haptics | 7 | — |
| Auth & Profile | 5 | — |
| Gamification | 3 | 4 |
| Settings | 7 | — |
| Accessibility | 5 | — |
| Onboarding | 4 | — |
| Performance | 4 | — |
| Community & Social | — | 6 |
| AI Co-Pilot | — | 5 |
| Multi-Device Sync | — | 4 |
| Import/Export | — | 2 |
| Media Pipeline | — | 4 |
| Advanced Interactions | — | 2 |
| Security/Privacy | — | 2 |
| **TOTAL** | **~118** | **~39** |
