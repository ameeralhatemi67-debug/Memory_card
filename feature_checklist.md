---
type: checklist
okm_type: pointer
project: "[[README|Memory Card]]"
tags:
  - project/memory-card
  - verification
  - human-review
  - status/in-progress
created: 2026-09-12
updated: 2026-09-12
status: active
verification_state: audit-reconciled
aliases:
  - Memory Card Feature Checklist
  - Memory Card Reverification Ledger
related:
  - "[[Roadmap|Memory Card Roadmap]]"
  - "[[Status|Memory Card Status]]"
  - "[[progress|Memory Card Progress]]"
  - "[[idea_Audit|Project Audit]]"
---

# Feature Reverification Checklist — Memory Card

> [!warning] Verification Labels Reconciled from Audit
> The pre-Version 2.0 specifications cataloged ~118 features, but the 2026-09-12 architectural audit identified significant gaps between the visual reference mockups (`reference/*.png`) and the web prototype (`text_Mockup/`), with zero production Flutter code written. This checklist establishes the strict, evidence-based retest criteria for all composite feature groups.

---

## How to Use This Checklist

The checkboxes below are human-review and automated test controls, not implementation tasks. For each feature group, select exactly one outcome after performing the specified test. Add observations under **User notes** in normal Markdown.

Do not select **Verified now** simply because code exists or an old screenshot looked correct. Verification requires the stated visual or behavioral property to be actively demonstrable in the current build.

---

## Reconciliation Summary

| # | Composite Feature Group | Current Evidence Status | Primary Reference | Target Release |
|---:|---|:---:|---|---|
| 1 | Typography & Custom Icon System | Discrepancy (Missing Bernard MT) | `icons.png`, `Questions.md` | Version 2.0 (Checkpoints 2.1 & 2.2) |
| 2 | Stepped Staircase Fan Deck Cards | Discrepancy (3 flat bars vs 5-step fan) | `Card_stacks_page.png` | Version 2.0 (Checkpoint 2.2) |
| 3 | Dual Split Swipe & Edge-Sinking Masking | Discrepancy (Single underlay, no fade) | `side_swaip_justes.png` | Version 2.0 (Checkpoint 2.2) |
| 4 | 6-Layer 3D Study Stack in Mobile View | Prototype in Sandbox only; screen flat | `Cards_page.png` | Version 2.0 (Checkpoint 2.2) |
| 5 | Screen-Edge Notched Corner Buttons | Missing from mobile study screen | `Cards_page.png` | Version 2.0 (Checkpoint 2.2) |
| 6 | Conscious Drawer & Inverted Luminance | Prototype; tab cutouts & + button drift | `side_drwer.png` | Version 2.0 (Checkpoint 2.2) |
| 7 | Peeking Cyclic Deck Spine Tabs ($\mathbb{Z}_3$) | Prototype | `side_drwer.png`, `RES-44` | Version 2.0 (Checkpoint 2.2) |
| 8 | Interactive Resizable Phone Viewport | Planned | New V2 requirement | Version 2.0 (Checkpoint 2.3) |
| 9 | 4-Column Pinterest Deck Shop Grid | Discrepancy (Horizontal rows vs 4 cols) | `shop_page.png` | Version 2.0 (Checkpoint 2.2) |
| 10 | Scalloped Orbiting Radial FAB Cluster | Prototype (Missing collision & shapes) | `highlited_deck_shop.png` | Version 2.0 (Checkpoint 2.2) |
| 11 | Tactile Membership Card & Auth Screen | Prototype (Missing diagonal sash) | `Log_Sign_pages.png` | Version 2.0 (Checkpoint 2.2) |
| 12 | Local FSRS-5 Spaced Repetition Engine | Math solved; zero code | `RES-12`, `FES-46` | Version 4.0 (Checkpoint 4.4) |
| 13 | Card Authoring & 1-Tap Import (Anki/CSV) | Missing (Crucial Day-2 retention fix) | `idea_Audit.md` | Version 4.0 (Checkpoint 4.5) |

---

## 1. Typography & Custom Icon System

- **Current Classification:** Discrepancy
- **Why:** The prototype loads Google Fonts `Cinzel` and `Plus Jakarta Sans`. The master visual reference and user decisions specify **Bernard MT Condensed** as the primary brand and UI typeface.
- **Retest Gate:** Open `text_Mockup/index.html`; verify that headers, folder names, and action buttons render with Bernard MT Condensed (or high-fidelity match), and all 20 custom SVG glyphs scale crisply without clipping.
- [ ] Verified now
- [x] Still broken / discrepancy
- [ ] Needs guided test
- **User notes:**

---

## 2. Stepped Staircase Fan Deck Cards

- **Current Classification:** Discrepancy
- **Why:** `Card_stacks_page.png` displays a prominent 4–5 layer diagonal stepped staircase fan peeking from the right flank of each deck item. `text_Mockup` currently renders 3 tiny horizontal bars.
- **Retest Gate:** Navigate to Screen 2 in the mobile phone frame; confirm each deck card displays a 4–5 tier diagonal fan with graduated shading.
- [ ] Verified now
- [x] Still broken / discrepancy
- [ ] Needs guided test
- **User notes:**

---

## 3. Dual Split Swipe & Dynamic Edge-Sinking Masking

- **Current Classification:** Discrepancy
- **Why:** `side_swaip_justes.png` displays a split dual underlay on left swipe (Red `[✖ Delete]` + Peach `[⬇ Archive]`), a Blue `[» Move]` underlay on right swipe, and gradient opacity edge-sinking where the trailing edge dissolves into the background during dragging. `text_Mockup` currently only supports static single-action underlays.
- **Retest Gate:** In Screen 2, drag a deck card left to reveal dual split tiles; drag right to reveal the Blue Move tile; confirm dynamic gradient alpha fading on the trailing edge.
- [ ] Verified now
- [x] Still broken / discrepancy
- [ ] Needs guided test
- **User notes:**

---

## 4. 6-Layer 3D Study Stack in Mobile View

- **Current Classification:** Prototype in Sandbox Only
- **Why:** The full 6-layer 3D interactive stack exists only in Tab 4 (the sandbox stage). Screen 3 inside the mobile device frame renders only a single flat card.
- **Retest Gate:** Switch to Screen 3 in the mobile frame; verify that the active deck renders as a full 6-layer 3D stack with lateral drag, $\pm 45^\circ$ rotation, and progressive answer revelation.
- [ ] Verified now
- [x] Still broken / discrepancy
- [ ] Needs guided test
- **User notes:**

---

## 5. Screen-Edge Notched Corner Action Buttons

- **Current Classification:** Missing from Mobile Study Screen
- **Why:** `Cards_page.png` shows large curved triangular "ears" docked to the screen edges (Left: Archive/Box; Right: Checkmark/Done). The prototype only has floating badges attached to the card.
- **Retest Gate:** In Screen 3, confirm docked notched corner buttons anchored to the bottom-left and bottom-right edges of the viewport.
- [ ] Verified now
- [x] Still broken / discrepancy
- [ ] Needs guided test
- **User notes:**

---

## 6. Conscious Folder Drawer & Inverted Luminance

- **Current Classification:** Prototype
- **Why:** Asymmetric folder silhouettes work via SVG canvas, but the bottom folder creation button is a full-width pill instead of the floating bottom-right folder icon with a `+` inside (`side_drwer.png`), and luminance contrast needs fine-tuning.
- **Retest Gate:** Open Screen 1 (Side Drawer); confirm inverted luminance in light/dark modes, authentic Bézier tab silhouette, and bottom-right folder `+` button.
- [ ] Verified now
- [ ] Still broken / discrepancy
- [x] Needs guided test
- **User notes:**

---

## 7. Peeking Cyclic Deck Spine Tabs ($\mathbb{Z}_3$)

- **Current Classification:** Prototype
- **Why:** Peeking tabs are implemented in JS, but need visual alignment with the exact rounded pill geometries and 35ms staggered elastic bounce from the reference specifications.
- **Retest Gate:** Select folders in the drawer; verify up to 3 colored tabs (Blue, Yellow, Red) emerge with non-repeating cyclic color orders.
- [ ] Verified now
- [ ] Still broken / discrepancy
- [x] Needs guided test
- **User notes:**

---

## 8. Interactive Resizable Phone Viewport & Aspect Ratio HUD

- **Current Classification:** Planned (Version 2.0 Checkpoint 2.3)
- **Why:** New requirement: Users must be able to drag the bottom-right corner of the phone frame horizontally and vertically to test responsive layout adaptations live in the browser.
- **Retest Gate:** Click and drag the bottom-right handle of the mobile device frame; confirm smooth real-time width (320px–768px) and height (568px–1024px) scaling, accompanied by a live dimension/aspect-ratio HUD.
- [ ] Verified now
- [x] Still broken / discrepancy
- [ ] Needs guided test
- **User notes:**

---

## 9. 4-Column Pinterest Deck Shop Grid

- **Current Classification:** Discrepancy
- **Why:** `shop_page.png` shows a **4-column vertical staggered masonry grid**. `text_Mockup` currently renders 4 static horizontal row tiles.
- **Retest Gate:** Open Screen 4 (Deck Shop); confirm a scrollable 4-column vertical staggered masonry feed with variable-height pill cards.
- [ ] Verified now
- [x] Still broken / discrepancy
- [ ] Needs guided test
- **User notes:**

---

## 10. Scalloped Orbiting Radial FAB Cluster

- **Current Classification:** Prototype
- **Why:** `highlited_deck_shop.png` shows fluid viewport dimming on long-press with 4 scalloped starburst action buttons orbiting around the highlighted deck. Current prototype has basic circular buttons.
- **Retest Gate:** Long-press a deck card in the shop; confirm screen dimming and emergence of 4 scalloped action buttons (Pin, Search burst, Bookmark, Share).
- [ ] Verified now
- [x] Still broken / discrepancy
- [ ] Needs guided test
- **User notes:**

---

## 11. Tactile Membership Card & Auth Screen

- **Current Classification:** Prototype
- **Why:** `Log_Sign_pages.png` features a prominent background diagonal ribbon/sash and scalloped circular frames for Google, Apple, and native login. Current prototype is missing the decorative sash and scalloped frames.
- **Retest Gate:** Open Screen 5; verify background diagonal sash, embossed card layout, and scalloped social login buttons.
- [ ] Verified now
- [x] Still broken / discrepancy
- [ ] Needs guided test
- **User notes:**

---

## 12. Local FSRS-5 Spaced Repetition Engine

- **Current Classification:** Math Solved; Implementation Scheduled for Version 4.0
- **Why:** DSR equations are thoroughly documented in `research/RES-12.md`, but native Dart engine and SQLite persistence do not exist yet.
- **Retest Gate:** Scheduled for Version 4.0 (Checkpoint 4.4).
- [ ] Verified now
- [ ] Still broken / discrepancy
- [x] Needs guided test
- **User notes:**

---

## 13. Frictionless Card Editor & 1-Tap Import (Anki/CSV)

- **Current Classification:** Planned for Version 4.0
- **Why:** Identified by the audit as the single most critical feature to prevent Day-2 user churn when shipping with 10–20 starter decks.
- **Retest Gate:** Scheduled for Version 4.0 (Checkpoint 4.5).
- [ ] Verified now
- [ ] Still broken / discrepancy
- [x] Needs guided test
- **User notes:**
