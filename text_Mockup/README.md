---
type: architecture
tags:
  - memory-card
  - text-mockup
  - web-design-system
  - interactive-prototype
created: 2026-08-14
updated: 2026-08-14
---

# 🎨 Memory Card — Living Design System & Interactive Mockup (`text_Mockup`)

> **Parent Hub:** [[Ideas]] | [[Ideas/Future]] | [[Main Work Flow]]  
> **Master Specification:** [[Ideas/Future/Memory Card/web_mockup.md|web_mockup.md]] | [[Ideas/Future/Memory Card/MC_Feature_list.md|MC_Feature_list.md]] | [[Ideas/Future/Memory Card/Questions.md|Questions.md]]

---

## 🌟 Overview

The `text_Mockup/` directory contains the complete, self-contained **Web-Based Living Design System & Functional Gesture Laboratory** for the **Memory Card** Flutter project.

It allows you to inspect all design tokens, interact with real-time 3D card swipe physics, test conscious folder emotional tremors, preview mobile screens, and copy 1:1 Flutter Dart code with zero compile or emulator wait time.

---

## 📂 File Structure

```
text_Mockup/
├── index.html       # Master entry point with tabbed navigation and mobile device frames
├── styles.css       # Complete design tokens, 3D card transforms, animations, and dark/light themes
├── app.js           # Procedural Web Audio synthesis, 3D swipe gesture controller, and state machines
└── README.md        # This guide
```

---

## 🚀 How to Launch & Explore

Simply open **`index.html`** in any modern web browser (Chrome, Edge, Safari, Firefox):

```powershell
# Double-click index.html or launch via powershell:
Start-Process "c:\Users\User\Documents\Amir Ob\projects\Ideas\Future\Memory Card\text_Mockup\index.html"
```

---

## 🧭 Interactive Features Included

### 1. 🎨 Design Tokens & Themes
- **Master Palettes**: Dark & Light theme canvases and cards.
- **Z₃ Cyclic Deck Tabs**: Blue (`#5B9DFF`), Yellow (`#FFB85B`), Coral (`#E55B5B`).
- **Inverted Folder Luminance**: Folder 0 (deepest $Z=0$) is brightest; Folder N is darkest.
- **6-Tier Material Profile Shaders**: Bronze, Silver, Gold, Emerald, Diamond, and Obsidian Black.
- **Click-to-Copy**: Click any token card to copy its Flutter `Color(0xFF...)` code to your clipboard.

### 2. 🧱 Living Components
- **Bézier Folder Silhouette**: Interactive asymmetric S-curve folder shelf with peeking cyclic tabs.
- **20 Custom SVG Glyphs**: Interactive matrix of all custom icons.
- **Action Blocks**: Squash and overshoot collision demos (`[✖ Delete]`, `[⬇ Archive]`, `[» Move]`, `[✓ Done]`).

### 3. 🕹️ Gesture & Physics Sandbox
- **Live 6-Layer 3D Card Stack**:
  - Drag the top card to feel simultaneous lateral displacement, rotation ($\pm 45^\circ$), scale reduction ($1.0 \to 0.75$), and downward drift.
  - Cross the $40\%$ threshold to slide in the `[🗃️ Review]` or `[✓ Mastered]` badges.
  - Release past $60\%$ to trigger offscreen exit trajectories and promote the next card.
  - Switch between **3D Flip (180°)**, **Color Transform Reveal**, and **No Flip** modes.
- **Conscious Folder States**:
  - Toggle **"Fear of Deletion"** mode to watch folders tremble with multi-harmonic sinusoidal frequencies ($18\text{Hz}, 29.1\text{Hz}$).
  - Toggle **"Excitement Bounce"** mode.
  - Slide the **OKLCH Luminance Depth** slider to test continuous color interpolation during drag reordering.
- **Procedural Web Audio**: Real-time synthesized mechanical ticks, commit thuds, and victory fanfares without external audio asset downloads.

### 4. 📱 Mobile Screen Walkthroughs (390×844 iPhone Frames)
- **Screen 1**: Conscious Side Drawer with empty state ("Empty Mind ???").
- **Screen 2**: Decks List with swipe-to-reveal action underlays.
- **Screen 3**: 3D Study Session.
- **Screen 4**: Pinterest Deck Shop with long-press reactive floating radial FAB.
- **Screen 5**: Tactile Membership Card with live tier shader preview.

### 5. 📋 Flutter Dart Exporter
- Copy-ready `AppColors.dart` and `FolderSilhouettePath.dart` Dart code ready to paste into the Flutter codebase.
