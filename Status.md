---
type: status
okm_type: pointer
project: "[[README|Memory Card]]"
tags:
  - project/memory-card
  - document/status
  - status/in-progress
created: 2026-09-12
updated: 2026-10-22
status: active
current_version: "2.0"
current_checkpoint: "2.1"
aliases:
  - Memory Card Status
  - Memory Card Current State
related:
  - "[[Roadmap|Memory Card Roadmap]]"
  - "[[progress|Memory Card Progress]]"
  - "[[feature_checklist|Feature Checklist]]"
  - "[[idea_Audit|Project Audit]]"
---

# Memory Card Current Status

**Last Updated:** 2026-10-22

**Current Version:** Version 2.0 (Design Finalization & Resizable Living Lab)

**Current Checkpoint:** Checkpoint 2.1 (Repository Baseline & Feature Checklist)

> [!success] 2026-10-22 — the Flutter app exists
> The native app planned for Version 4.0 was pulled forward at the owner's request and is built: `app/` (Flutter 3.41), every screen of the design canvas, the RES-47/RES-48 engine, onboarding, 56 decks / 1,355 cards, local storage only, Android release APK. See `app/README.md` and [[progress|Progress]]. Not published anywhere; no backend.

**System Status:** Active Design Lab — Version 1.0 (Research, Master Specs, and Initial Prototype) complete; entering Version 2.0 Checkpoint 2.1 (Git Ingestion, Canonical Checklist & Documentation Baseline) transitioning into Checkpoint 2.2 (Visual Reference Parity) and Checkpoint 2.3 (Interactive Resizable Phone View).

> [!abstract] Project Navigation
> - **Parent Hub:** [[README|Memory Card Project Hub]]
> - **Master Plan:** [[Roadmap|Product Roadmap]]
> - **Verified History:** [[progress|Progress Log]]
> - **Verification Ledger:** [[feature_checklist|Feature Reverification Checklist]]
> - **Audit Report:** [[idea_Audit|Architectural & UX Audit]]

This file reports the present operational state only. Planned work belongs in [[Roadmap|Roadmap]], and verified completed outcomes belong in [[progress|Progress]].

---

## Current Objective

> [!important] Active Milestone Goal
> Establish clean Git version control, author the canonical feature checklist, bring `text_Mockup/` into 100% visual parity with reference mockups (stepped staircase fans, Bernard MT typography, dual swipe actions, corner edge buttons), and build a fully interactive drag-to-resize phone testing frame.

---

## Current State

| Area | Status | Evidence-Based Operational Note |
|---|:---:|---|
| **Product Direction** | Approved | Clear 4-version trajectory recorded in [[Roadmap|Roadmap]]; North Star focused on tactile retention without cognitive fatigue. |
| **Architectural Audit** | Complete | [[idea_Audit|idea_Audit.md]] delivered with 433 lines analyzing 120 FPS Impeller constraints, GC pause risks, sensory nausea, and Day-2 retention blind spots. |
| **Cognitive & Physics Research** | 100% Complete | All 46 specialized papers in `research/` (`RES-01` to `RES-45`, `FES-46`) are finalized and cross-referenced. |
| **Living Mockup Prototype** | Operational; needs refinement | `text_Mockup/` runs zero-latency in any browser with interactive 3D swipe sandbox, but exhibits visual deviations from `reference/*.png` (stepped fans, font, edge buttons). |
| **Interactive Resizable Viewport** | Planned (V2 Checkpoint 2.3) | Static 390×844 iPhone frame to be upgraded with a draggable bottom-right corner controller and live aspect ratio HUD. |
| **Git Version Control** | Initializing | Scaffolding Git repository and clean `.gitignore` to enable phase-by-phase commit checkpoints. |
| **Native Flutter Codebase** | Built (v1.0, local-only) | `app/`: all designed screens, onboarding tour, engine, catalog, backup/restore, reminders, TTS. 6 test files pass; every screen reviewed as rendered PNGs (light/dark). Android release APK builds. |
| **Repetition Engine** | Implemented | MCRE v2 ([[RES-48_Engine_v2]]): endless stack, shadow FSRS-6 verified against the reference package, grading from speed/hesitation/confidence, self-tuning thresholds, personal calibration, on-device training. |
| **iOS build** | Blocked (needs a Mac) | Same code; an iOS build requires Xcode on macOS. |

---

## Active Work

### Checkpoint 2.1 — Repository Baseline, Git Scaffolding & Feature Checklist
- **Phase 2.1.1 (Git Scaffolding):** Initializing repository, creating `.gitignore`, and staging baseline commit.
- **Phase 2.1.2 (Feature Checklist):** Authoring `feature_checklist.md` to establish formal retest gates for all 13 core visual feature groups.
- **Phase 2.1.3 (Documentation Alignment):** Publishing canonical `README.md`, `Roadmap.md`, `Status.md`, and `progress.md`.

### Next Immediate Checkpoints:
- **Checkpoint 2.2 (Mockup Discrepancy Remediation):**
  - Inject Bernard MT Condensed typography.
  - Implement 4–5 layer stepped staircase fans on deck items (`Card_stacks_page.png`).
  - Implement dual split swipe underlays (Delete + Archive) and dynamic edge-sinking gradient opacity masks (`side_swaip_justes.png`).
  - Implement screen-edge notched corner buttons and 3D stack inside the mobile study screen (`Cards_page.png`).
  - Rebuild Shop into a true 4-column Pinterest masonry feed with orbiting radial FABs (`shop_page.png`, `highlited_deck_shop.png`).
- **Checkpoint 2.3 (Interactive Resizable Phone View):**
  - Draggable bottom-right corner resize handle (320px–768px width, 568px–1024px height).
  - Quick-select device presets (iPhone SE, iPhone 15 Pro, Pixel 8, iPad Mini, Foldable).
  - Real-time aspect ratio and layout adaptability testing.

---

## Baseline Safety Boundary & Git Commit Policy

> [!success] Recovery Baseline Policy
> To prevent unreviewed drift and code churn:
> 1. All work must be compartmentalized into named Version $\to$ Checkpoint $\to$ Phase milestones.
> 2. Every phase must conclude with an automated or visual verification pass.
> 3. Clean, atomic Git commits must be executed at every phase boundary, ensuring complete traceability and rollback capability.

---

## Deferred Direction

The following capabilities are deliberately excluded from current active milestones based on audit recommendations:
- **Heavy AI Deck Generation / Video Scraping**: Deferred to future updates; MVP focuses on high-quality curated decks and local authoring.
- **Continuous Background Gyroscope Parallax**: Deferred to Version 3.0 sensory lab to prevent device thermal throttling and battery drain.
- **2D Virtualized Marketplace with Revenue Sharing**: Deferred; Version 2.0 shop focuses on curated starter deck discovery.
- **High-Frequency (18Hz–43Hz) Folder Shivering**: Softened to an organic, subtle 3Hz pulse to prevent user sensory nausea during study sessions.
