---
type: project
okm_type: map
tags:
  - project/memory-card
  - spaced-repetition
  - mobile-first
  - flutter
  - status/active
created: 2026-08-13
updated: 2026-09-12
status: active
current_version: "2.0"
current_checkpoint: "2.1"
verification_state: evidence-reconciled
aliases:
  - Memory Card
  - Memory Card Project Hub
related:
  - "[[Roadmap|Memory Card Roadmap]]"
  - "[[Status|Memory Card Status]]"
  - "[[progress|Memory Card Progress]]"
  - "[[feature_checklist|Feature Checklist]]"
  - "[[idea_Audit|Project Audit]]"
---

# 🧠 Memory Card — Hyper-Tactile Spaced-Repetition Platform

**Memory Card** is a mobile-first spaced-repetition memory application designed for iOS and Android. Built on the conviction that memorization shouldn't feel like a grueling chore, it wraps the scientifically proven **FSRS-5** cognitive scheduling engine in an intoxicating, tactile UI with micro-animated "conscious" states, physical spatial layering, and visceral audio-haptic feedback.

> [!success] 2026-10-22 — The app is built
> **Memory Card v1.0** (Flutter) lives in `app/`: every designed screen, the repetition engine ([[RES-48_Engine_v2]]), onboarding, 56 decks. Local-only, Android APK; see `app/README.md` to install or build it. The rest of this hub describes the design programme that led here.

> [!warning] Current Product State
> **Version 1.0 (Deep Research & Initial Prototype)** is complete, producing 46 research papers and an initial web lab (`text_Mockup/`).  
> We are currently in **Version 2.0 (Design Finalization & Resizable Living Lab)**, systematically closing visual discrepancies identified in [[idea_Audit|the architectural audit]], implementing a live resizable phone testing canvas, establishing Git version boundaries, and locking design tokens.  
> **Native Flutter production code has not yet started** (scheduled for Version 4.0). See [[Status|Current Status]] and [[Roadmap|Roadmap]] before relying on any feature.

---

## Primary Objective

The intended daily study journey is:

1. **Open Memory Card**: Greeted by the clean, minimal header and active folders.
2. **Access Conscious Drawer**: Fluidly browse skewed folder stacks with inverted OKLCH luminance and peeking cyclic deck tabs.
3. **Select a Stepped Deck**: Choose a deck featuring 4–5 layered staircase card fans and edge-sinking swipe actions.
4. **Enter 3D Study Session**: Interact with a 6-layer 3D card stack; tap to reveal definition and mnemonics.
5. **Tactile Swipe Decision**: Swipe left (Review Again) or swipe right (Mastered) across calibrated 40%/60% gesture thresholds.
6. **Adaptive Rescheduling**: Passive dwell time and FSRS-5 calculate optimal memory stability intervals.
7. **Visceral Victory Payoff**: Celebrate completed sets with sound fanfares and streak momentum.

```mermaid
flowchart LR
    Open[Open Memory Card] --> Drawer[Conscious Drawer: Select Folder]
    Drawer --> Decks[Decks List: Choose Stepped Deck]
    Decks --> Study[6-Layer 3D Study Stack]
    Study --> Recall[Active Recall: Tap to Reveal]
    Recall --> Swipe[Tactile Swipe: Review vs Master]
    Swipe --> Scheduled[FSRS-5 Dynamic Rescheduling]
    Scheduled --> Celebrate[Completion Fanfare & Streak]
```

---

## Current Capability Truth

| Classification | Count | Summary |
|---|:---:|---|
| **Verified (Research & Math)** | 46 | All mathematical models (3D card transforms, FSRS-5 DSR equations, OKLCH lerp, damped spring harmonic equations) are formally solved in `research/`. |
| **Prototype (Living Design Lab)** | 6 | 6-layer 3D card stack sandbox, 5 mobile phone walkthrough screens, procedural Web Audio synthesis, Bézier folder silhouette, and OKLCH depth sliders in `text_Mockup/`. |
| **In Progress (Version 2.0)** | 4 | Git repository initialization, `feature_checklist.md`, resizable phone frame controller, and visual reference discrepancy remediation. |
| **Planned (Version 3.0)** | 4 | Physical mechanical click WAV library (<50KB), low-power gyroscope 3D parallax, ambient backdrop glow shaders, and 6-tier membership profile shaders. |
| **Future (Version 4.0)** | 6 | Flutter Impeller 120 FPS native project, local-first SQLite persistence (`drift`), native FSRS-5 Dart engine, frictionless card editor, 1-tap Anki import, and App Store release. |

---

## Architecture & Directory Structure

```
memory_card/
├── README.md                 # Master project hub & executive guide (this file)
├── Roadmap.md                # 4-version execution plan (V1 Done, V2 Active, V3 Lab, V4 Build)
├── Status.md                 # Current operational state & active checkpoint
├── progress.md               # Chronological verified outcomes & decision log
├── feature_checklist.md      # Feature verification ledger & retest controls
├── idea_Audit.md             # Comprehensive architectural, UX & engineering audit
├── MC_Feature_list.md        # Master feature catalog (~118 MVP vs ~39 Later)
├── Questions.md              # Authoritative locked user decisions & specifications
├── brain_dump.md             # Master concept document & storage hierarchy
├── brain_storming.md         # Creative ideation & emotional design exploration
├── icons list.md             # Inventory of all 20 custom glyphs
│
├── icons/                    # 20 raw production SVG icon definitions
│   ├── logoDarkMode.svg, folder.svg, home.svg, shop.svg, burggerDotes.svg...
│
├── reference/                # 8 high-resolution visual source-of-truth mockups
│   ├── Card_stacks_page.png, Cards_page.png, side_drwer.png, side_swaip_justes.png...
│
├── research/                 # 46 deep technical research papers (RES-01 to RES-45, FES-46)
│   ├── RES-01 (3D Physics), RES-07 (Wiggle Math), RES-12 (FSRS-5), RES-44 (Folder Engine)...
│
└── text_Mockup/              # Self-contained living design system & gesture laboratory
    ├── index.html            # Master browser interface with mobile frames & physics stage
    ├── styles.css            # Complete design tokens, 3D transforms, and themes
    ├── app.js                # Embedded SVG glyphs, Web Audio synth, gesture physics engine
    └── README.md             # Guide to running and extending the web laboratory
```

---

## Running the Living Mockup & Gesture Lab

The living design system and interactive prototype run directly in any modern desktop browser (Chrome, Edge, Firefox, Safari) with **zero compilation or emulator overhead**:

```powershell
# Double-click text_Mockup/index.html or launch via PowerShell:
Start-Process "d:\Agents\main\projects\ideas\memory_card\text_Mockup\index.html"
```

### What You Can Test Today in the Mockup:
1. **🎨 Design Tokens & Themes**: Real-time Dark/Light theme switching, $\mathbb{Z}_3$ cyclic tab palettes, and OKLCH folder luminance.
2. **🧱 Living Components**: Parametric Bézier folder silhouettes, custom SVG glyph matrix, and action tiles.
3. **🕹️ 3D Gesture Sandbox**: Live 6-layer draggable card stack with lateral rotation, scale reduction, 40% badge thresholds, and 60% fling exits.
4. **📱 Mobile Screen Walkthroughs**: Previews of the Conscious Side Drawer, Decks List, Study Session, Pinterest Shop, and Membership Card.
5. **📋 Flutter Exporter**: One-click copying of generated Dart color palettes and custom painters.

---

## Core Planning & Authority Documents

- **[[Roadmap|Product Roadmap]]**: Single source of truth for planned milestones across Versions 1.0 to 4.0.
- **[[Status|Current Status]]**: Real-time snapshot of the active checkpoint, work in progress, and safety policies.
- **[[progress|Progress Log]]**: Evidence-backed chronological record of all completed outcomes.
- **[[feature_checklist|Feature Checklist]]**: Itemized reverification ledger for testing visual and functional components.
- **[[idea_Audit|Architectural Audit]]**: Uncompromising critique of 120 FPS mobile constraints, cognitive fatigue risks, and Day-2 retention solutions.
