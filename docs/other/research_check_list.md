---
type: architecture
tags:
  - memory-card
  - research-checklist
  - roadmap
  - task-matrix
  - future-planning
created: 2026-08-13
updated: 2026-08-13
---

# 📋 Memory Card — Master Research Checklist (30+ Deep Research Topics)

> **Parent Hub:** [[Ideas]] | [[Ideas/Future]] | [[Main Work Flow]]  
> **Master Concept:** [[Ideas/Future/Memory Card/brain_dump.md|brain_dump.md]] | [[Ideas/Future/Memory Card/research.md|research.md]] | [[Ideas/Future/Memory Card/brain_storming.md|brain_storming.md]]  
> **Interactive Q&A:** [[Ideas/Future/Memory Card/Questions.md|Questions.md]]

---

## 🧭 How to Use This Checklist

This document serves as the master catalog of research tracks for **Memory Card**. Each topic represents a self-contained research investigation that can be turned into a dedicated research file (e.g., `research/01_card_swipe_physics.md`) when selected.

Items are organized across **8 core engineering and design domains**, spanning from micro-interaction mathematics to cognitive algorithms and offline storage systems.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          RESEARCH DOMAIN MATRIX                             │
├─────────────────────────────────────────┬───────────────────────────────────┤
│ Domain                                  │ Scope                             │
├─────────────────────────────────────────┼───────────────────────────────────┤
│ 1. Gesture Physics & Shaders (01–06)    │ 3D card math, edge-sinking, squash│
│ 2. Conscious UI & Motion (07–11)        │ Wiggle math, color gradation, tabs│
│ 3. Cognitive Science & SRS (12–17)      │ FSRS-5 algorithm, hesitation ML   │
│ 4. Audio & Haptic Engineering (18–22)   │ Web Audio synthesis, earcons      │
│ 5. Shop & Discovery UX (23–27)          │ Staggered masonry, radial FAB math│
│ 6. Local-First Data & Sync (28–32)      │ SQLite, CRDTs, deck branching     │
│ 7. Multi-Modal Cards & AI (33–37)       │ Cloze, image occlusion, AI decks  │
│ 8. Performance & Accessibility (38–42)  │ 120fps benchmarks, RTL, low-motion│
└─────────────────────────────────────────┴───────────────────────────────────┘
```

---

## 🎴 Domain 1: Gesture Physics, Interactive Shaders & 3D Math

- [x] **`RES-01` | [[Ideas/Future/Memory Card/research/RES-01_3D_Card_Swipe_Physics.md|3D Card Stack Swipe Trajectory & Non-Linear Scale/Rotation Math]]**
  - **Problem**: How to create a continuous, lag-free gesture mapping where lateral displacement $u$ simultaneously controls $X/Y$ translation, $-45^\circ \dots +45^\circ$ rotation, $0\% \dots 25\%$ scale reduction, and parabolic downward drift without gimbal lock or touch jitter.
  - **Key Tech/Methods**: React Native Reanimated 3 interpolation curves, Flutter `GestureDetector` + `Transform`, 4x4 matrix decomposition, Euler rotation clamp.
  - **Target Deliverable**: Precise mathematical transfer function and reproducible code sandbox. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-01_3D_Card_Swipe_Physics.md)

- [x] **`RES-02` | [[Ideas/Future/Memory Card/research/RES-02_Gradient_Opacity_Edge_Sinking_Shaders.md|Dynamic Gradient Opacity Masking & Edge-Sinking Shaders]]**
  - **Problem**: In the deck list, swiping a deck left/right must sink the trailing edge into the canvas background rather than cutting it off abruptly at the screen edge.
  - **Key Tech/Methods**: Custom Fragment Shaders (GLSL / SkSL), CSS `mask-image` with dynamic linear gradient alphas, Skia `Paint.shader` gradient masking, OKLCH color interpolation toward ambient canvas.
  - **Target Deliverable**: Cross-platform shader code and GPU-accelerated implementation guide. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-02_Gradient_Opacity_Edge_Sinking_Shaders.md)

- [x] **`RES-03` | [[Ideas/Future/Memory Card/research/RES-03_Squash_Stretch_Collision_Dynamics.md|Squash-and-Stretch Collision Dynamics & Action Block Overshoot]]**
  - **Problem**: When a swiped deck crosses the 35% threshold, the action button springs out with $+12\%$ overshoot, causing the deck to squish horizontally upon contact before settling.
  - **Key Tech/Methods**: Damped Harmonic Oscillator equations ($\zeta = 0.72, \omega_n = 28\text{ rad/s}$), mass-spring-damper physics engines, physical impulse transfer between adjacent layout nodes.
  - **Target Deliverable**: Spring configuration profiles and collision response algorithms. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-03_Squash_Stretch_Collision_Dynamics.md)

- [x] **`RES-04` | [[Ideas/Future/Memory Card/research/RES-04_Interruptible_Gesture_Timelines.md|Multi-Touch Interruptible Gesture Timelines & Mid-Air Fling Catching]]**
  - **Problem**: Allowing the user to catch a card mid-flight after a fast fling to reverse an accidental swipe, or seamlessly interrupt ongoing spring resets.
  - **Key Tech/Methods**: Gesture State Machine tracking velocity vectors ($v_x, v_y$), momentum decay cancellation, pointer capture hijacking, zero-latency animation frame preemption.
  - **Target Deliverable**: Interaction statechart for gesture preemption and interruption. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-04_Interruptible_Gesture_Timelines.md)

- [x] **`RES-05` | [[Ideas/Future/Memory Card/research/RES-05_Gyroscope_3D_Parallax_Depth_Engine.md|Gyroscope 3D Multi-Plane Parallax Depth Engine]]**
  - **Problem**: Tilting the physical phone should tilt the 6 visible card stack layers with realistic spatial parallax, dynamic specular sheen, and embossed border highlights.
  - **Key Tech/Methods**: Accelerometer/Gyroscope low-pass filtering, CoreMotion (iOS) / SensorManager (Android) sensor fusion, perspective projection matrix with dynamic Z-index elevation.
  - **Target Deliverable**: Battery-efficient sensor sampling pipeline and parallax matrix math. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-05_Gyroscope_3D_Parallax_Depth_Engine.md)

- [x] **`RES-06` | [[Ideas/Future/Memory Card/research/RES-06_Two_Finger_Undo_Shake_Physics.md|Two-Finger Undo Shake & Reverse Trajectory Animation]]**
  - **Problem**: Quick shake of the phone or a two-finger tap triggers a fluid reverse-motion swoop, pulling the previously swiped card back from offscreen onto the top of the stack.
  - **Key Tech/Methods**: Accelerometer shake gesture detection algorithms (threshold jerk $> 1.8g$), reverse Bezier motion curves, undo history ring buffer.
  - **Target Deliverable**: Shake detection filter and reverse animation timeline specification. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-06_Two_Finger_Undo_Shake_Physics.md)

---

## 📂 Domain 2: Emotionally Conscious UI & Micro-Animations

- [x] **`RES-07` | [[Ideas/Future/Memory Card/research/RES-07_Harmonic_Wiggle_Conscious_Folder_States.md|Organic Multi-Harmonic Wiggle Physics for "Conscious" Folder States]]**
  - **Problem**: Folders in the side drawer must feel emotionally aware—expressing "fear of deletion" with high-frequency nervous trembling when targeted by trash, and "excitement" when creating a new folder.
  - **Key Tech/Methods**: Multi-harmonic sinusoidal wave synthesis ($\theta(t) = A_1 \sin(\omega_1 t) + A_2 \cos(\omega_2 t)$), Perlin noise perturbation, spring contraction physics.
  - **Target Deliverable**: Parameterized emotional animation curves (Fear, Excitement, Idle Breathing, Drag Relief).

- [x] **`RES-08` | [[Ideas/Future/Memory Card/research/RES-08_Inverted_Z_Index_Color_Interpolation.md|Inverted Z-Index Layering with Real-Time Lightness-to-Darkness Interpolation]]**
  - **Problem**: In the folder drawer, the first folder sits physically deepest but is colored lightest, while the bottom folder sits highest visually and is darkest. Dragging folders must smoothly re-interpolate lightness in real time.
  - **Key Tech/Methods**: OKLCH / HSL perceptually uniform color spaces, dynamic Z-index layout layering, touch-driven color lerp shaders.
  - **Target Deliverable**: Mathematical formula for dynamic palette generation and drag interpolation.

- [x] **`RES-09` | [[Ideas/Future/Memory Card/research/RES-09_Peeking_Deck_Spine_Tabs_Animation.md|Peeking Deck Spine Tabs Animation & Staggered Accordion Expansion]]**
  - **Problem**: Selecting a folder animates up to 3 colored file tabs protruding from its spine with elastic staggered bounce; handling $>3$ decks without visual clutter.
  - **Key Tech/Methods**: Staggered spring animations, spring delay chains ($t_i = i \times 35\text{ms}$), dynamic tab width compression, "+N more" overflow capsule pills.
  - **Target Deliverable**: Component specification and overflow handling layout logic.

- [x] **`RES-10` | [[Ideas/Future/Memory Card/research/RES-10_Dynamic_Canvas_Ambient_Glow_Shaders.md|Dynamic Canvas Ambient Glow Shaders Matching Active Card Accent]]**
  - **Problem**: The app's dark backdrop should softly glow with dynamic, blurred ambient gradients extracted from the current card's dominant color palette, cross-fading during swipe transitions.
  - **Key Tech/Methods**: Color quantization (K-Means / ColorThief), dual-buffer cross-fading canvas shaders, high-radius Gaussian blur optimization ($R = 80\text{px}$) with GPU mipmapping.
  - **Target Deliverable**: GPU-optimized ambient backdrop shader and color extraction pipeline.

- [x] **`RES-11` | [[Ideas/Future/Memory Card/research/RES-11_3D_Wax_Seal_Confetti_Celebration_Physics.md|3D Wax Seal Stamping & Confetti Particle Physics for Win Celebrations]]**
  - **Problem**: Completing a full deck loop triggers a dopamine-rich celebration featuring a physics-driven 3D wax seal stamping "MASTERED" onto the deck and explosive particle confetti.
  - **Key Tech/Methods**: 2D/3D Particle emitter physics (gravity, air drag, angular velocity, elastic bounce), 3D embossed stamp mesh deformation, haptic impact synchronization.
  - **Target Deliverable**: Lightweight particle engine and stamp animation blueprint.

- [x] **`RES-44` | [[Ideas/Future/Memory Card/research/RES-44_Flutter_Conscious_Folder_Drawer_Engine.md|Flutter Conscious Folder Drawer Engine — Inverted Z-Index Geometry, 3-Color Deck Tab Permutations & Living Tactile Micro-Interactions]]**
  - **Problem**: Engineering an organic, physical folder stack drawer with parametric asymmetrical Bézier silhouettes, inverted luminance Z-stacking, deterministic $\mathbb{Z}_3$ cyclic deck tab color cycling, living emotional physics (fear/excitement/drag springs), and 120 FPS Impeller rendering.
  - **Key Tech/Methods**: Parametric Cubic Bézier S-curve silhouette with $C^1$ continuity, OKLCH continuous drag color interpolation $\tilde{i}(y)$, $\mathbb{Z}_3$ cyclic color permutations ($[B,Y,R] \to [Y,R,B] \to [R,B,Y]$), multi-harmonic fear tremors ($18\text{Hz}, 29.1\text{Hz}, 43.7\text{Hz}$), custom `RenderBox` non-rectangular hit-testing, Impeller GPU DisplayList optimization.
  - **Target Deliverable**: Comprehensive mathematical paper and complete, production-ready Flutter/Dart implementation (`ConsciousFolderDrawer.dart`). [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-44_Flutter_Conscious_Folder_Drawer_Engine.md)


---

## 🧠 Domain 3: Cognitive Science, Spaced Repetition & Behavioral Telemetry

- [x] **`RES-12` | [[Ideas/Future/Memory Card/research/RES-12_FSRS5_Spaced_Repetition_Engine.md|FSRS-5.0 (Free Spaced Repetition Scheduler) On-Device Implementation]]**
  - **Problem**: Implementing modern FSRS-5.0 on-device without cloud dependencies to calculate continuous retrievability $R(t)$, stability $S$, and difficulty $D$.
  - **Key Tech/Methods**: FSRS mathematical formula implementation in TypeScript/Dart/Rust, matrix parameter optimization, forgetting curve fitting.
  - **Target Deliverable**: Pure mathematical FSRS-5 engine and test harness. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-12_FSRS5_Spaced_Repetition_Engine.md)

- [x] **`RES-13` | [[Ideas/Future/Memory Card/research/RES-13_Hesitation_Metric_Mathematical_Model.md|Mathematical Formulation of the User Hesitation Metric (Hs)]]**
  - **Problem**: How to convert subtle touch nuances (time to first touch, drag hesitation, left-right direction reversals, hold durations) into a normalized $0.0 \dots 1.0$ score that scales spaced repetition intervals.
  - **Key Tech/Methods**: Multi-variate weighted regression, touch velocity calculus, hesitation penalty weighting for "Right (Mastered)" swipes with high hesitation.
  - **Target Deliverable**: Rigorous mathematical formula and edge-case calibration dataset. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-13_Hesitation_Metric_Mathematical_Model.md)

- [x] **`RES-14` | [[Ideas/Future/Memory Card/research/RES-14_Passive_Dwell_AFK_Filter_Algorithms.md|Passive Dwell Time & Intelligent AFK/Distraction Filtering Algorithms]]**
  - **Problem**: Distinguishing genuine cognitive retrieval effort (user thinking hard for 6 seconds) from distraction/AFK (user left phone on desk for 40 seconds) to prevent corrupting learning statistics.
  - **Key Tech/Methods**: Exponential moving average dwell baselines, statistical outlier rejection, accelerometer micro-motion verification, 25-second clamp thresholds.
  - **Target Deliverable**: AFK detection state machine and dwell time normalization algorithm. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-14_Passive_Dwell_AFK_Filter_Algorithms.md)

- [x] **`RES-15` | [[Ideas/Future/Memory Card/research/RES-15_Active_Recall_Progressive_Revelation.md|Active Recall Optimization via Progressive Content Revelation on Under-Cards]]**
  - **Problem**: Why keeping cards 2–6 completely blank until swipe transition reaches 40% improves focus, and how progressive opacity cross-fading acts as a zero-latency asset loader.
  - **Key Tech/Methods**: Cognitive Load Theory (Sweller), testing effect neuroscience, progressive rendering pipeline linked to swipe displacement $u$.
  - **Target Deliverable**: Cognitive justification paper and synchronous asset pre-warming architecture. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-15_Active_Recall_Progressive_Revelation.md)

- [x] **`RES-16` | [[Ideas/Future/Memory Card/research/RES-16_Multi_Modal_Dual_Coding_Retention.md|Multi-Modal Dual-Coding Memory Retention Analysis]]**
  - **Problem**: Analyzing optimal memory retention improvements when combining text definitions, visual iconography, phonetic audio playback, and micro-animations.
  - **Key Tech/Methods**: Paivio's Dual-Coding Theory, cognitive load indexing per card modality, phonological loop reinforcement in language learning.
  - **Target Deliverable**: Content authoring best practices guide and optimal card structure rules. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-16_Multi_Modal_Dual_Coding_Retention.md)

- [x] **`RES-17` | [[Ideas/Future/Memory Card/research/RES-17_Interleaved_Practice_Queue_Scheduling.md|Interleaved vs Blocked Practice Scheduling in Nested Folders & Decks]]**
  - **Problem**: How the app should structure review sessions across multiple decks in a folder (e.g., studying 10 German verbs + 10 German nouns interleaved vs sequentially).
  - **Key Tech/Methods**: Interleaving cognitive research, dynamic queue merging algorithms, session mixing ratios.
  - **Target Deliverable**: Smart Multi-Deck Queue Merger algorithm specification. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-17_Interleaved_Practice_Queue_Scheduling.md)

- [x] **`RES-43` | [[Ideas/Future/Memory Card/research/RES-43_Short_Term_vs_Long_Term_Adaptive_Reinsertion_Engine.md|Short-Term vs Long-Term Memory Dynamics & Adaptive In-Session Card Re-Insertion Engine]]**
  - **Problem**: Overcoming the intra-session spacing dilemma: immediate re-testing ($N=1$) produces a false illusion of competence via passive phonological echo, while queue-tail dumping causes complete memory extinction.
  - **Key Tech/Methods**: Dual-store cognitive architecture (Tier 1 working ring buffer $W \in [5, 7]$ vs Tier 2 long-term queue), mathematical dynamic re-insertion calculus $N^* = f(C, H_s, S, D, L_{\text{session}}, W_{\text{active}})$, optimal forgetting threshold targeting ($R^* \approx 0.80\text{--}0.88$), zero-allocation Dart ring buffers.
  - **Target Deliverable**: Rigorous cognitive neuroscience paper, complete Dart/Flutter `AdaptiveMemoryQueueEngine.dart`, and Monte Carlo simulation verification. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-43_Short_Term_vs_Long_Term_Adaptive_Reinsertion_Engine.md)

- [x] **`RES-46` / `FES-46` | [[projects/ideas/memory_card/docs/research/FES-46_Mobile_Gamification_Behavioral_Psychology_And_Sustainable_Retention_Architecture|Mobile Gamification, Behavioral Psychology & Sustainable Habit Progression Systems]]**
  - **Problem**: 80% of gamified systems fail due to the Overjustification Effect and toxic streak loss-aversion; designing an intrinsically motivating, mobile-first gamification architecture that balances Self-Determination Theory (SDT), Octalysis White-Hat mechanics, non-punitive habit loops, and multi-tier prestige shaders without causing cognitive fatigue.
  - **Key Tech/Methods**: Self-Determination Theory (SDT), Octalysis framework (80/20 White/Black Hat ratio), Soft Streaks with Grace Shields (2 rolling monthly saves + 48h Frozen Embers surge), Composite Mastery Score (CMS) metric formula for Bronze-to-Obsidian card tiers, Dunbar-sized leaderboards ($N=30$), living biome shaders (Skia/Impeller), full production Flutter/Dart and React Native/Reanimated 3 engines.
  - **Target Deliverable**: Publication-grade master research paper, mathematical CMS model, and complete cross-platform gamification engine. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/FES-46.md)

---

## 🔊 Domain 4: Audio Engineering & Tactile Haptic Synthesis

- [x] **`RES-18` | [[Ideas/Future/Memory Card/research/RES-18_Procedural_Audio_Synthesis_Engine.md|Procedural Zero-Bundle Web Audio / Native AudioGraph Sound Synthesis]]**
  - **Problem**: Generating all micro-sounds, clicks, whooshes, and chimes procedurally in real time without shipping heavy audio asset files (MP3/WAV).
  - **Key Tech/Methods**: Web Audio API `OscillatorNode`, `BiquadFilterNode`, `GainNode` envelopes; Native CoreAudio / Oboe synthesis, FM synthesis, white/pink noise filtering.
  - **Target Deliverable**: Modular, zero-dependency procedural audio synthesis class. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-18_Procedural_Audio_Synthesis_Engine.md)

- [x] **`RES-19` | [[Ideas/Future/Memory Card/research/RES-19_Depth_Scaled_Mechanical_Ticks.md|Frequency-Modulated Mechanical Ticks & Pitch-Scaling on Folder Depth]]**
  - **Problem**: Producing crisp, wooden tactile clicks when dragging folders that dynamically scale in pitch (higher pitch for shallow folders, deep low resonant pitch for deep folders).
  - **Key Tech/Methods**: Short impulse synthesis ($20\text{ms}$ decayed sine waves), resonant bandpass filters, pitch modulation mapping functions.
  - **Target Deliverable**: Tactile click generator with depth-scaling API. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-19_Depth_Scaled_Mechanical_Ticks.md)

- [x] **`RES-20` | [[Ideas/Future/Memory Card/research/RES-20_Velocity_Tied_Spatial_Audio_Panning.md|Velocity-Tied Spatial Audio Panning for Lateral Swiping]]**
  - **Problem**: Swiping left pans audio whoosh and click feedback to the left stereo channel ($-1.0$), swiping right pans to the right channel ($+1.0$), with volume scaled by swipe velocity.
  - **Key Tech/Methods**: `StereoPannerNode` / 3D HRTF spatial audio nodes, velocity-to-gain curve mapping, pan interpolation.
  - **Target Deliverable**: Spatial audio controller integrated with swipe gesture coordinates. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-20_Velocity_Tied_Spatial_Audio_Panning.md)

- [x] **`RES-21` | [[Ideas/Future/Memory Card/research/RES-21_Advanced_Haptics_Waveform_Engineering.md|CoreHaptics (iOS) & Android Advanced Vibration Waveform Engineering]]**
  - **Problem**: Designing tactile haptic sensations that match the exact physical weight of cards, folder snapping, threshold crossing, and wiggle tremors.
  - **Key Tech/Methods**: Apple `CHHapticEngine` transient and continuous patterns, Android `VibrationEffect` composition curves, haptic-audio waveform synchronization.
  - **Target Deliverable**: Custom haptic profile library (`.ahap` patterns and Android vibration definitions). [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-21_Advanced_Haptics_Waveform_Engineering.md)

- [x] **`RES-22` | [[Ideas/Future/Memory Card/research/RES-22_Celebratory_Harmonic_Chords_Soundscapes.md|Dynamic Celebratory Harmonic Chords & Soundscapes for Milestone Wins]]**
  - **Problem**: Creating procedurally synthesized ascending harmonic chord progressions (Cmaj7 $\rightarrow$ D9 $\rightarrow$ Gmaj7) with subtle reverb upon completing study sets.
  - **Key Tech/Methods**: Additive synthesizer polyphony, algorithmic chord generators, exponential decay envelopes, convolution reverb impulse responses.
  - **Target Deliverable**: Algorithmic fanfare generator for win states. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-22_Celebratory_Harmonic_Chords_Soundscapes.md)

- [x] **`RES-45` | [[Ideas/Future/Memory Card/research/RES-45_Flutter_Haptic_Feedback_Engineering.md|Flutter Haptic Feedback Engineering — Mechanoreceptor Science, Platform APIs, Waveform Design & Application Mapping]]**
  - **Problem**: Flutter's built-in `HapticFeedback` class exposes only 5 generic methods, concealing an enormous expressive surface — Apple Core Haptics (CHHapticEngine + AHAP), Android `VibrationEffect.Composition` (9 named primitives with delay/amplitude control), and the deep neuroscience governing which frequencies feel pleasant vs alarming.
  - **Key Tech/Methods**: Mechanoreceptor physiology (FA-I Meissner, FA-II Pacinian, SA-I Merkel, SA-II Ruffini), Apple Taptic Engine generational analysis (v1–v4), `CHHapticEngine` + `.ahap` JSON waveform authoring, `VibrationEffect.Composition` Kotlin bridge, `HapticEvent` sealed class dispatcher with 50ms throttle + battery guard + accessibility layer, 6 waveform archetypes (Click/Tick/Thud/Pop/Rumble/Crescendo), Memory Card interaction-to-haptic mapping table (15 interactions), audio-haptic synchronization within ±20ms binding window.
  - **Target Deliverable**: Complete cross-platform haptic service architecture (Dart/Swift/Kotlin), all AHAP patterns, all waveform archetypes, QA device matrix. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-45_Flutter_Haptic_Feedback_Engineering.md)

---

## 🛍️ Domain 5: Shop Architecture, Reactive UI & Discovery

- [x] **`RES-23` | [[Ideas/Future/Memory Card/research/RES-23_Staggered_6Row_Masonry_Virtualization.md|Staggered 6-Row Masonry Layout with Bidirectional Virtualization]]**
  - **Problem**: Creating a 6-row horizontally scrollable Pinterest-style deck masonry grid that maintains 120fps scrolling with hundreds of community decks without memory leaks.
  - **Key Tech/Methods**: Custom 2D Virtualization windowing algorithms, recycling view pools, dynamic card dimension calculation, off-screen unmounting.
  - **Target Deliverable**: High-performance 2D virtualized masonry grid component. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-23_Staggered_6Row_Masonry_Virtualization.md)

- [x] **`RES-24` | [[Ideas/Future/Memory Card/research/RES-24_Radial_FAB_Collision_Positioning.md|Collision-Aware Radial FAB Mathematical Positioning & Inward Reflection]]**
  - **Problem**: Long-pressing a deck opens a 4-button radial FAB menu (`[Pin]`, `[Share]`, `[Search]`, `[Save]`); if pressed near screen edges, the menu must reflect inward to avoid clipping.
  - **Key Tech/Methods**: Geometric boundary collision detection, polar-to-cartesian coordinate transformations, angular fan reflection algorithms.
  - **Target Deliverable**: Complete mathematical positioning function with boundary constraints. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-24_Radial_FAB_Collision_Positioning.md)

- [x] **`RES-25` | [[Ideas/Future/Memory Card/research/RES-25_Fluid_Viewport_Dimming_Focus_Isolation.md|Fluid Viewport Dimming & Radial Focus Isolation Techniques]]**
  - **Problem**: When a shop deck is long-pressed, the rest of the UI dims smoothly with a dark backdrop filter while keeping the target card and floating FAB elevated and floating.
  - **Key Tech/Methods**: Layer isolation, backdrop blur shaders (`backdrop-filter: blur(12px)`), hero elevation transitions, living bobbing floating physics.
  - **Target Deliverable**: Modal focus layer and organic floating animation loop. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-25_Fluid_Viewport_Dimming_Focus_Isolation.md)

- [x] **`RES-26` | [[Ideas/Future/Memory Card/research/RES-26_Card_Preview_Carousel_Bottom_Sheet.md|Instant Card Preview Carousel Bottom-Sheet UX (deck_shop_selected)]]**
  - **Problem**: Tapping a shop card opens a lightweight bottom sheet with a mini swipeable card stack preview, deck metadata, creator stats, and related deck recommendations.
  - **Key Tech/Methods**: Interactive nested gesture bottom sheets, mini card stack carousel, dynamic height expansion.
  - **Target Deliverable**: Bottom sheet interaction blueprint and preview stack statechart. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-26_Card_Preview_Carousel_Bottom_Sheet.md)

- [x] **`RES-27` | [[Ideas/Future/Memory Card/research/RES-27_Search_Indexing_Vector_Recommendations.md|Tag Taxonomy, Full-Text Search Indexing & Embedding-Based Recommendations]]**
  - **Problem**: Fast client-side search across thousands of shop decks by title, creator, tags, and semantic similarity ("German grammar" finding "Deutsch Verben").
  - **Key Tech/Methods**: SQLite FTS5 full-text indexing, lightweight on-device vector embeddings (MiniLM / WebAssembly SQLite-VSS), fuzzy typo-tolerant matching.
  - **Target Deliverable**: Search indexing architecture and semantic similarity query pipeline. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-27_Search_Indexing_Vector_Recommendations.md)

---

## 💾 Domain 6: Local-First Data Storage & Synchronization

- [x] **`RES-28` | [[Ideas/Future/Memory Card/research/RES-28_Local_First_SQLite_Schema_Optimization.md|Local-First SQLite Schema Design, Migrations & Sub-16ms Query Optimization]]**
  - **Problem**: Structuring the relational database (`folders`, `decks`, `cards`, `review_telemetry_logs`) to support instant offline CRUD and guaranteed sub-16ms reads for 120fps animations.
  - **Key Tech/Methods**: SQLite indexes on foreign keys and review timestamps, prepared statements, in-memory caching layers, schema migration versioning.
  - **Target Deliverable**: Optimized SQL schema, indexing strategy, and database access layer. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-28_Local_First_SQLite_Schema_Optimization.md)

- [x] **`RES-29` | [[Ideas/Future/Memory Card/research/RES-29_CRDT_PowerSync_Offline_Synchronization.md|Conflict-Free Replicated Data Types (CRDTs) & PowerSync/ElectricSQL for Offline Sync]]**
  - **Problem**: Enabling multi-device synchronization (e.g., studying on phone during commute, editing decks on tablet) without merge conflicts or lost review streaks.
  - **Key Tech/Methods**: Yjs / Automerge CRDTs, PowerSync / ElectricSQL sync engines, Postgres logical replication backends, Last-Write-Wins timestamps for SRS stability.
  - **Target Deliverable**: Multi-device sync architecture and conflict resolution rules. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-29_CRDT_PowerSync_Offline_Synchronization.md)

- [x] **`RES-30` | [[Ideas/Future/Memory Card/research/RES-30_Media_Asset_Caching_Blob_Compression.md|Media Asset Caching, Local Blob Storage & WebP/Opus Compression]]**
  - **Problem**: Efficiently storing and streaming thousands of card images, phonetic audio files, and Lottie animations locally on device without ballooning app storage.
  - **Key Tech/Methods**: Content-addressable storage (SHA-256 hashes), WebP image compression, Opus audio encoding (16kbps voice clarity), LRU cache eviction.
  - **Target Deliverable**: Media storage manager and compression pipeline specification. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-30_Media_Asset_Caching_Blob_Compression.md)

- [x] **`RES-31` | [[Ideas/Future/Memory Card/research/RES-31_Telemetry_Aggregation_Log_Compaction.md|Telemetry Aggregation, Log Compaction & On-Device Privacy Storage]]**
  - **Problem**: Capturing granular touch and hesitation telemetry for every card review without causing database bloat over months of continuous daily use.
  - **Key Tech/Methods**: Rollup tables, daily summary aggregations, raw log compaction after 14 days, zero-knowledge on-device data retention, Differential Privacy Laplace noise.
  - **Target Deliverable**: Telemetry logging lifecycle and data compaction job specification. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-31_Telemetry_Aggregation_Log_Compaction.md)

- [x] **`RES-32` | [[Ideas/Future/Memory Card/research/RES-32_Git_For_Flashcards_Branching_Merging.md|"Git for Flashcards" — Deck Branching, Forking & Upstream Merging]]**
  - **Problem**: Allowing users to fork a community shop deck, add their own custom mnemonic cards or notes, and still pull updates from the original creator.
  - **Key Tech/Methods**: Directed Acyclic Graph (DAG) commit models for flashcards, three-way merge algorithms for card decks, patch generation and validation.
  - **Target Deliverable**: Deck versioning model and fork/merge specification. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-32_Git_For_Flashcards_Branching_Merging.md)

---

## 🤖 Domain 7: Multi-Modal Card Engines & AI Co-Pilot

- [x] **`RES-33` | [[Ideas/Future/Memory Card/research/RES-33_Interactive_Cloze_Deletion_Engine.md|Interactive Cloze Deletion DOM & Gesture Mechanics]]**
  - **Problem**: Building rich cloze deletion cards where users tap blurred/blanked words to reveal them sequentially before deciding to swipe left or right.
  - **Key Tech/Methods**: Custom rich text parser, inline interactive tap targets, cloze hint state machines, automated cloze generation algorithms.
  - **Target Deliverable**: Cloze card rendering engine and interaction model. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-33_Interactive_Cloze_Deletion_Engine.md)

- [x] **`RES-34` | [[Ideas/Future/Memory Card/research/RES-34_Image_Occlusion_Masking_Engine.md|Image Occlusion Interactive Masking Engine (Anatomy & Geography)]]**
  - **Problem**: Creating diagram flashcards where anatomical labels or map regions are covered by colored interactive masking tape that peels off on tap.
  - **Key Tech/Methods**: SVG `<path>` and `<rect>` occlusion layers, touch hit-testing on irregular shapes, sticker peel deformation shaders.
  - **Target Deliverable**: Image occlusion authoring and study canvas component. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-34_Image_Occlusion_Masking_Engine.md)

- [x] **`RES-35` | [[Ideas/Future/Memory Card/research/RES-35_Audio_First_Blind_Testing_Workflow.md|Audio-First Blind Testing Gesture Workflow & Real-Time Waveform Telemetry]]**
  - **Problem**: Enabling pure auditory flashcards (listening comprehension) where the user hears a phrase, visualizes the meaning, swipes to grade, and only then reveals the written text.
  - **Key Tech/Methods**: Audio pre-loading and auto-play triggers, procedural Skia/Canvas waveform visualizers, Bluetooth output latency compensation, comprehension latency telemetry ($T_{\text{comp}}$), FSRS-5 auditory stability modulation.
  - **Target Deliverable**: Audio-first review lifecycle specification and complete cross-platform React Native + Flutter implementation. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-35_Audio_First_Blind_Testing_Workflow.md)

- [x] **`RES-36` | [[Ideas/Future/Memory Card/research/RES-36_LLM_Atomic_Flashcard_Extraction_Pipeline.md|LLM Document/Video to Atomic Flashcard Extraction Pipeline]]**
  - **Problem**: Transforming a YouTube video transcript, textbook PDF, or Wikipedia URL into atomic, high-retention flashcards adhering to the minimum information principle.
  - **Key Tech/Methods**: Context-aware propositional chunking, Minimum Information Principle (MIP) Chain-of-Thought prompts, vector-space semantic distractor synthesis ($0.60 \le \cos(\theta) \le 0.85$), dual-coding mnemonics, grammar-constrained JSON schemas (Pydantic v2 / Zod), deterministic AST auto-repair.
  - **Target Deliverable**: End-to-end Python microservice, TypeScript client ingestion engine, and automated evaluation benchmark test suites. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-36_LLM_Atomic_Flashcard_Extraction_Pipeline.md)

- [x] **`RES-37` | [[Ideas/Future/Memory Card/research/RES-37_On_Device_TTS_Phonetic_Alignment.md|On-Device Speech Synthesis & Multi-Dialect Phonetic Alignment]]**
  - **Problem**: Generating clear audio pronunciations for vocabulary cards in any language, supporting regional dialects (e.g. High German vs Bavarian) without third-party API costs.
  - **Key Tech/Methods**: On-device TTS (iOS `AVSpeechSynthesizer`, Android `TextToSpeech`), Web Speech API, IPA (International Phonetic Alphabet) stress matching, Piper ONNX int8 neural VITS fallback, eSpeak-NG G2P core.
  - **Target Deliverable**: Multi-dialect TTS engine with offline caching, DTW karaoke boundary highlight, and complete TypeScript & Flutter bridges. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-37_On_Device_TTS_Phonetic_Alignment.md)

---

## ⚡ Domain 8: Cross-Platform Performance, Accessibility & Inclusion

- [x] **`RES-38` | [[Ideas/Future/Memory Card/research/RES-38_Cross_Platform_Architecture_Benchmark_ADR.md|Flutter (Impeller) vs React Native (Skia + Reanimated 3) vs Web Benchmark (ADR)]]**
  - **Problem**: Determining the definitive tech stack for 120fps gesture fluidity, custom shader support, procedural audio latency, and developer velocity.
  - **Key Tech/Methods**: Benchmark matrix across frame drop rates, gesture-to-render latency (ms), battery consumption, and bundle footprint.
  - **Target Deliverable**: Formal Tech Stack Architecture Decision Record (ADR). [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-38_Cross_Platform_Architecture_Benchmark_ADR.md)

- [x] **`RES-39` | [[Ideas/Future/Memory Card/research/RES-39_120Hz_GPU_Optimization_6Layer_Stacks.md|120Hz Jank-Free Rendering & GPU Memory Optimization for 6-Layer Stacks]]**
  - **Problem**: Ensuring the 6-layer card stack renders at a constant 120fps on mid-range Android and iOS devices without overheating or dropping frames during rapid swiping.
  - **Key Tech/Methods**: GPU layer flattening, render-tree virtualization, off-screen canvas caching, elimination of bridge bottlenecks.
  - **Target Deliverable**: Profiling benchmark protocol and performance optimization guide. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-39_120Hz_GPU_Optimization_6Layer_Stacks.md)

- [x] **`RES-40` | [[Ideas/Future/Memory Card/research/RES-40_RTL_Swipe_Semantic_Inversion.md|Full Right-to-Left (RTL) Swipe Semantic Inversion for Arabic & Hebrew]]**
  - **Problem**: Inverting all spatial swipe mechanics (Swipe Left = Mastered, Swipe Right = Review) and drawer tab directions for RTL language speakers while preserving physical intuition.
  - **Key Tech/Methods**: Directional layout engine transforms, mirrored gesture physics coordinates, dynamic icon flipping.
  - **Target Deliverable**: RTL localization and spatial gesture inversion matrix. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-40_RTL_Swipe_Semantic_Inversion.md)

- [x] **`RES-41` | [[Ideas/Future/Memory Card/research/RES-41_Screen_Reader_Reduced_Motion_Accessibility.md|Screen Reader Spatial Accessibility & Reduced Motion Graceful Degradation]]**
  - **Problem**: Making the complex 3D visual card stack and emotional wiggles accessible to users with screen readers (VoiceOver/TalkBack) and vestibular motion sensitivities.
  - **Key Tech/Methods**: `prefers-reduced-motion` CSS/Native hooks, ARIA live regions, alternative non-gestural review buttons (`Mastered`, `Review Again`).
  - **Target Deliverable**: WCAG 2.2 AAA accessibility compliance blueprint. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-41_Screen_Reader_Reduced_Motion_Accessibility.md)

- [x] **`RES-42` | [[Ideas/Future/Memory Card/research/RES-42_Dynamic_Type_Autoscaling_Architecture.md|Dynamic Type Autoscaling & Extreme Accessibility Layout Scaling]]**
  - **Problem**: Ensuring card text, folder drawer titles, and shop badges remain fully readable and beautifully proportioned even at maximum system accessibility font sizes.
  - **Key Tech/Methods**: Dynamic font scaling curves, container query text reflow, expandable bottom-sheet reading drawers for large text.
  - **Target Deliverable**: Responsive typography scale and overflow layout rules. [📄 Paper Available](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Future/Memory%20Card/research/RES-42_Dynamic_Type_Autoscaling_Architecture.md)
