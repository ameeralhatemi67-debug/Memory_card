---
type: decision
tags:
  - memory-card
  - questions
  - user-input
  - architecture-decisions
  - project-scope
created: 2026-08-13
updated: 2026-08-14
---































































































































































































































# ❓ Memory Card — Project Questions & Design Alignment

> **Parent Hub:** [[Ideas]] | [[Ideas/Future]] | [[Main Work Flow]]  
> **Master Concept:** [[Ideas/Future/Memory Card/brain_dump.md|brain_dump.md]] | [[Ideas/Future/Memory Card/research.md|research.md]] | [[Ideas/Future/Memory Card/research_check_list.md|research_check_list.md]]

---

## 🎯 Instructions for the User

Below is the structured list of questions spanning **Architecture, UX/UI, Content, Audio, and Business Scope**.  
You can type your answers directly underneath each question in this file, or answer them in chat when you're ready!

---

## 📱 1. Target Platforms & Runtime Environment

### Q1.1 | What is the primary target platform for the initial release?
- [x] **Option A (Mobile-First Native/Hybrid)**: iOS and Android app (leveraging touch gestures, native haptics, tilt sensors).
- [ ] **Option B (Web-First Progressive Web App)**: Accessible on mobile browsers + desktop with mouse/trackpad swipe emulation.
- [ ] **Option C (Universal Cross-Platform)**: Built once for iOS, Android, Web, and Desktop simultaneously.
- **Your Answer / Notes**:  (Mobile-First Native/Hybrid) Android and IOS

### Q1.2 | Do you prefer a specific tech stack or framework for the implementation?
- [x] **Option A**: Flutter (Dart + Impeller Engine) — Outstanding 120fps gesture performance and custom shaders.
- [ ] **Option B**: React Native (TypeScript + React Native Reanimated 3 + Skia) — Great web/mobile code sharing.
- [ ] **Option C**: Modern Web (Vite + React / Svelte 5 + Framer Motion / GSAP + WebGL/Canvas).
- [ ] **Option D**: Antigravity recommendations based on performance benchmarks.
- **Your Answer / Notes**: I pick the Flutter/dart.

---

## 🎴 2. Card Interaction, Flip & Swipe Mechanics

### Q2.1 | How should cards reveal their answers during a study session?
- [ ] **Option A (Instant Front-Only Evaluation)**: The card only displays the question/term, and the user swipes based on whether they knew it, then the next card appears.
- [x] **Option B (Tap to Flip / Reveal Definition first, then Swipe)**: Tapping the top card flips it over or slides open the back definition/answer; the user confirms and then swipes left or right.
- [ ] **Option C (Progressive Bottom-Half Reveal)**: The top card shows the front, and swiping slightly past 40% reveals the back definition on the card before final release at 60%.
- **Your Answer / Notes**: we would have two types to experiment with, the tap to flip and reveal answer, and the tap icon in the card it self to revel the answer, so we build both, and experiment, then pick the best. or offer the user the ability to pick one. 

### Q2.2 | What should happen when a user completes all cards in a deck round?
- [ ] **Option A (Repeat Failed Cards Loop)**: Immediately loop through the cards swiped "Left (Don't Remember)" until all cards are swiped "Right (Mastered)".
- [ ] **Option B (Summary Screen with Stats)**: Show a celebratory victory screen with hesitation stats, accuracy score, and a button to re-study or exit.
- [ ] **Option C (Both)**: Congratulate with a 3D celebration, then offer an immediate *"Review 4 Struggled Cards"* button.
- **Your Answer / Notes**: the card is technically never ending, so that means any card that was swiped right go the very back of the stack, and the cards that get swiped left go back a N number back, this is adaptive as we use the data for that card, to now if we have it it move backward 3 card, or 5 or n, so if the card has a confidence score of 40% then we use memory techniques to now what is the best order back to locate its new order.  

---

## 📂 3. Side Drawer & Folder Behavior Edge Cases

### Q3.1 | In the folder drawer, what exact visual representation do you prefer when a folder contains more than 3 decks?
- [ ] **Option A (3 Main Tabs + "+N" Counter Pill)**: Render 3 colored tabs, plus a clean pill badge indicating additional decks.
- [ ] **Option B (Compressed Mini-Fan)**: Stagger all deck tabs with tighter overlap spacing so up to 6–8 tabs can peek out without overflow.
- [ ] **Option C (Expandable Accordion Sub-Drawer)**: Tapping a folder expands an accordion list showing all child decks directly inside the drawer.
- **Your Answer / Notes**: Currently I don't have an idea on how to show that number of decks in this folder. so we would continue with the current design, and later see how we may in the future add a UI element that could help. update: we have maid [[projects/ideas/memory_card/docs/research/RES-44_Flutter_Conscious_Folder_Drawer_Engine]]

### Q3.2 | Should folders support nested sub-folders (Folder inside a Folder), or strictly 1 level of Folders containing Decks?
- [x] **Option A (Strict 1-Level Hierarchy)**: Folders $\rightarrow$ Decks $\rightarrow$ Cards (Clean, zero clutter).
- [ ] **Option B (Infinite Nested Sub-Folders)**: Folders can hold sub-folders and decks.
- **Your Answer / Notes**: no sub-folders

---

## 🔊 4. Audio Engineering & Tactile Haptic Customization

### Q4.1 | How prominent should sounds and music be in the default user experience?
- [ ] **Option A (Full Soundscape Enabled by Default)**: Tactile mechanical ticks, whooshes, emotional folder wiggles, and victory fanfares.
- [x] **Option B (Subtle Micro-Clicks Only by Default)**: Minimalist subtle paper/wooden clicks on swipe and drag, with celebratory music only on set completion.
- [ ] **Option C (Muted by Default with Prompt to Enable)**: Sound off initially; settings allow choosing between sound themes.
- **Your Answer / Notes**: sounds should be used for effects and celebrations, no full on sound track, yet I would like to see if we can have Haptic feedback.  

### Q4.2 | Would you like switchable "Sound Themes"? (e.g., Mechanical Wooden Clicks vs Modern Synth Pop vs Minimalist Zen)
- [ ] **Option A**: Yes, offer sound packs in settings.
- [x] **Option B**: No, keep one signature sound design unique to Memory Card.
- **Your Answer / Notes**: no sound track. 

---

## 🛍️ 5. Pinterest Shop, Sharing & Community Features

### Q5.1 | How will community decks in the Shop be moderated and populated initially?
- [x] **Option A (Curated Official Starter Decks)**: Ships with 10–20 high-quality pre-built decks (German Basics, Spanish 101, Medical Terminology, World Flags, Coding Syntax).
- [ ] **Option B (Open Community Publishing)**: Anyone can publish and share public decks with tags and descriptions.
- [ ] **Option C (Both)**: Official verified curated decks at the top, followed by browsable community creations.
- **Your Answer / Notes**: I see that we focus on the hipping with high-quality pre-built decks, if we going to add the ability to make decks and card, we would have it in a later update. 

### Q5.2 | Should users be able to import decks from Anki (`.apkg`) or Quizlet?
- [ ] **Option A**: Yes, Anki/Quizlet import is a critical high-priority feature for power users.
- [x] **Option B**: No, keep the focus entirely on Memory Card's native rich format.
- [ ] **Option C**: Add import as a later milestone update.
- **Your Answer / Notes**: no. for now keep the focus entirely on Memory Card's native rich format, and we would have this feature later as a new update

---

## 🤖 6. AI Co-Pilot & Automated Card Creation

### Q6.1 | What level of AI generation would you like integrated into the app?
- [ ] **Option A (Full AI Deck Generator)**: Paste YouTube link, PDF document, or topic prompt $\rightarrow$ AI generates cards, translations, and mnemonics automatically.
- [ ] **Option B (AI Assisted Creation)**: User types the word $\rightarrow$ AI suggests definitions, example sentences, audio phonetics, and icons.
- [x] **Option C (Manual Authoring Only for MVP)**: Keep v1 purely manual/curated, add AI in v2.
- **Your Answer / Notes**: we add the AI integration in a later update 

---

## 🔐 7. Authentication, Data Storage & Offline-First Mode

### Q7.1 | Can users use the application completely offline without creating an account?
- [x] **Option A (100% Guest-First Offline)**: All data stays on the local device (SQLite); account login is optional for cloud backup and shop sharing.
- [ ] **Option B (Mandatory Account Creation)**: Users must sign in with Google, Apple, or Email on first launch to sync data.
- **Your Answer / Notes**: 

---

## 🎨 8. Visual Styling, Themes & Branding Details

### Q8.1 | In the login mockup, there is a decorative curved sweep and embossed card. Should the user's profile card in settings reflect their actual real-time learning rank/tier?
- [x] **Option A**: Yes! The card transforms visually (Bronze $\rightarrow$ Silver $\rightarrow$ Gold $\rightarrow$ Obsidian Black) as the user levels up and masters decks.
- [ ] **Option B**: Keep it as a clean static profile card.
- **Your Answer / Notes**: yes, but maybe the full card, maybe a badge. we experiment with both.

### Q8.2 | Any specific font families or typography styles you envision?
- [ ] **Option A (Modern Geometric Sans)**: Inter, Outfit, Plus Jakarta Sans (Clean, sleek, high-tech).
- [ ] **Option B (Editorial / Serif Title + Sans Body)**: Playfair Display / Fraunces for titles + Inter for card text (Luxury, bookish feel).
- [ ] **Option C (Rounded Friendly Sans)**: Nunito, Quicksand (Fun, playful, approachable).
- **Your Answer / Notes**: the font that I want to start with is: "Bernard MT Condensed" as the user interface font, but for the cards info, we can experiment with more fonts

---

## 🌱 9. Onboarding, First-Launch & Empty States

### Q9.1 | What should the user experience on the very first launch of the app (before any decks exist)?
- [ ] **Option A (Instant Blank Canvas)**: Drop into the home screen with an empty side drawer and a single prominent `[+ Create Folder]` call-to-action.
- [x] **Option B (Interactive Onboarding Tour)**: A 3–4 step animated walkthrough that physically demonstrates the swipe gesture, folder drawer, and shop — using a sample deck the user can actually swipe through.
- [ ] **Option C (Smart Starter Pack Prompt)**: Ask 2 questions ("What do you want to learn?" + "What level are you?") and auto-install a curated starter deck directly into a pre-created folder.
- [ ] **Option D (Direct to Shop)**: Skip onboarding entirely — land directly in the Shop so the user can immediately pick and install a deck before ever seeing the empty home screen.
- **Your Answer / Notes**: the first experience should be Onboarding, yet we have still not finish with the planning of the application, so we plan the Onboarding after we have finish the final application plan where we know all the features and more, there should be 2-3 folders, each with 3-4 decks, say one folder is for Languages include decks for (Spanish, French, Arabic, English), another folder for German Languages, this holds 3-4 decks, each having a set level of German words as you learn you go to the next deck. lastly one more folder for coding, with decks for python, dart, C++.  

### Q9.2 | When a folder is empty (no decks inside yet), what does its state look like in the side drawer?
- [ ] **Option A (Grayed-Out Ghost Tabs)**: Show 3 faint ghost tab shapes as a visual hint of what's coming — no content yet.
- [ ] **Option B (Single "+" Tab)**: Show exactly one colored tab with a `+` icon, indicating "tap me to add a deck."
- [ ] **Option C (Fully Collapsed, No Tabs)**: An empty folder shows no tabs at all — it appears as a flat folder with only the folder name.
- **Your Answer / Notes**: say in it "empty Mind" under it have a "Look for something to remember" use clicks this to go to the shop. also add "Create a deck, coming soon", we should also have a visual, maybe a simple illustration of a brain with "???" 

### Q9.3 | When the entire app is brand new and has no folders or decks, what is the emotional tone of the empty state screen?
- [ ] **Option A (Minimal & Clean)**: Pure empty canvas with a simple headline like *"Your first deck awaits."* and a single button.
- [ ] **Option B (Animated & Inviting)**: A looping Lottie/Rive animation of a tiny floating card stack that pulses gently, inviting the user in.
- [x] **Option C (Shop-Forward)**: The empty state immediately shows a curated "Start Here" mini-row from the shop so users never feel stuck.
- **Your Answer / Notes**: already outlined it in Q9.2

---

## 🏆 10. Gamification, Progression & Rewards

### Q10.1 | Should the app feature a visible daily streak counter (like Duolingo's flame)?
- [x] **Option A (Yes — Prominent flame streak on the home screen)**: A persistent streak indicator visible every session, with milestone celebrations at 7, 30, 100 days.
- [ ] **Option B (Yes — Subtle and integrated)**: Show streak only inside the profile/settings card, not as a home-screen distraction.
- [ ] **Option C (No streaks)**: No streak mechanic — focus purely on retention quality (confidence score) rather than daily consistency pressure.
- **Your Answer / Notes**:

### Q10.2 | The brainstorming doc mentions a "Memory Garden" — living flora that grows or wilts based on memory health. Is this a feature you want in the MVP or a future update?
- [ ] **Option A (MVP — Core feature from day one)**: The Memory Garden is central to the identity and emotional design of the app.
- [ ] **Option B (Future v2 update)**: Implement the core swipe engine first; add the garden as a major v2 feature.
- [ ] **Option C (Never — I prefer a different gamification approach)**: Replace with a different system (describe below).
- **Your Answer / Notes**: this is a later update feature, for now no need to think of it.

### Q10.3 | The profile card in Settings transforms visually (Bronze → Silver → Gold → Obsidian Black) as the user levels up. What metric should control this progression?
- [ ] **Option A (Total cards mastered across all decks)**: Pure mastery count — the more cards you master, the higher your tier.
- [ ] **Option B (Total decks fully completed)**: Completing a full deck cycle earns tier progression.
- [ ] **Option C (Composite score)**: A combined score of mastery + consistency (daily reviews) + deck variety.
- [ ] **Option D (XP / Point system)**: Every swipe, deck completion, and streak earns XP toward the next tier.
- **Your Answer / Notes**: currently I do not know, so we need to make a research on this. a new full research on Gamification 

### Q10.4 | Should the app include the "60-Second Memory Sprint" speed-run mode from the brainstorming doc for MVP?
- [ ] **Option A (Yes — Include in MVP as a second study mode)**: Users can switch between Standard Review and Speed Sprint from the deck page.
- [ ] **Option B (Future update only)**: Too complex for MVP; standard swipe mode is sufficient for launch.
- [ ] **Option C (Replace with a simpler timed mode)**: A simple countdown timer on the standard swipe mode (e.g., a progress ring that fills over 90 seconds).
- **Your Answer / Notes**: no, but this is a gesture Idea, so we have it as a feature for a later update. 

---

## 🎴 11. Card Content, Authoring & Rich Media

### Q11.1 | For MVP, which card content types will be supported when creating a card manually?
- [ ] **Option A (Text only)**: Front and back are plain text fields with basic markdown formatting.
- [ ] **Option B (Text + Image)**: Users can add one image per side (from camera or gallery).
- [x] **Option C (Text + Image + Audio)**: Full rich card: text, one image, and one audio recording per side.
- [ ] **Option D (All types from day one)**: Text, image, audio, and cloze deletion — the full content engine at launch.
- **Your Answer / Notes**: text, image and Audio. in a future update we would add videos, and youtube links.

### Q11.2 | When a user manually creates a card, how should the card editor feel?
- [ ] **Option A (Minimal — Just two text fields labeled "Front" and "Back")**: Simple and fast — no friction.
- [ ] **Option B (Rich inline editor — Tap the front of a visual card preview to type directly onto it)**: The editor looks exactly like the final card, WYSIWYG style.
- [x] **Option C (Bottom sheet fields)**: A bottom sheet slides up with input fields for front content, back content, and optional image/audio attachments.
- **Your Answer / Notes**: I want a full on test editor, where the use can edit: Size, Font, Bold, italic, alignment, and types of lists (pullet, numbered and checklist). the same goes for the images editor, where the user can: import image, edit Size, Crop, Radios, placement type. as for Audio, for this version we have it as a "coming soon feature" but its still used in our premade cards, and we add it to the later update list. and yes should be a bottom sheet visual. 

### Q11.3 | The research covers both "Tap to Flip" and a "Dedicated Reveal Icon" on the card itself. When the card is revealed/flipped, should the back of the card be a continuation of the same card visual, or a completely distinct second card design?
- [ ] **Option A (Same card, flipped — back is a mirror of the front)**: The card physically rotates 180° in 3D, showing the back face of the same card object.
- [ ] **Option B (Slide reveal — the back content slides up or wipes in over the front)**: No 3D flip; the answer content wipes in from below or fades over the question.
- [x] **Option C (Color transform — the card face changes color as it reveals the back)**: The front face smoothly transforms to a different accent color when revealed, signaling the shift from question to answer.
- **Your Answer / Notes**: I guess a 3D flip would be to gimmick, we can set it in the test phase, if we dislike to we move to Card transform Reveal the answer. Note: we should have all 3 as an option, and the user can pick, between card does not flip or hold hiden info, or a card that flips to show answer, or card that just Reveals answer after clicking an icon or simply tapping the card. 

---

## 🧭 12. Navigation Shell, Settings & User Profile

### Q12.1 | The 3-dot burger menu in the top right opens a dropdown. What items should live there vs. in a dedicated full Settings screen?
- [x] **Option A (Minimal dropdown: Theme toggle + Account + "Send Feedback" only)**: Keep the dropdown paper-thin; everything else goes in a full Settings screen accessed from the Profile card.
- [ ] **Option B (Rich dropdown: Theme, Account, Notification preferences, App version, Rate app)**: A fully featured quick-access dropdown panel.
- [ ] **Option C (No dropdown — hamburger opens a full side panel/sheet)**: Replace the dot menu with a full bottom sheet settings panel.
- **Your Answer / Notes**: in this dropdown we need to include: dark/light mode toggle, settings, feedback. the settings is the only that holds the account, notification settings, and the on/off features, and preferences.

### Q12.2 | Should the app support **Light Mode**, **Dark Mode**, and **System-Adaptive** mode from launch?
- [ ] **Option A (Dark Mode only for MVP)**: Ship with only the dark tactile theme; light mode is a future update.
- [x] **Option B (Light + Dark + System-Adaptive from day one)**: Full theming support at launch — the `[☀️ Sun]` toggle switches between all three.
- [ ] **Option C (Custom "Warm" and "Cool" variants instead of strict Light/Dark)**: e.g., a warm parchment mode and a cold slate mode rather than standard light/dark.
- **Your Answer / Notes**: **Light Mode**, **Dark Mode**, and **System-Adaptive** mode from launch.

### Q12.3 | The center `[⬡ + Create]` bottom bar button opens a creation flow. Should it always create at the most granular level (a Card), or should it ask what to create?
- [x] **Option A (Context-Aware — smart default based on where you are)**: On the home screen → creates a Folder. Inside a folder → creates a Deck. Inside a deck → creates a Card. No dialog needed.
- [ ] **Option B (Always prompt — shows a choice sheet)**: Always shows a small sheet: `[+ Folder]` / `[+ Deck]` / `[+ Card]` regardless of location.
- [ ] **Option C (Fixed — always creates a Card)**: The center button always opens the card creator; Folder and Deck creation lives elsewhere (e.g., a dedicated `+` button in each respective view).
- **Your Answer / Notes**: note: is cant create a folder, but yes we can let the user create decks and cards.

---

## 🚀 13. MVP Scope, Launch Strategy & Monetization

### Q13.1 | What is your definition of the MVP (Minimum Viable Product) — the absolute minimum feature set to ship a first version to the app stores?
- [ ] **Option A (Ultra-Lean Prototype)**: Side Drawer + Decks List + Card Swipe Session only. No shop, no gamification, no account system.
- [x] **Option B (Core Product)**: Side Drawer + Decks + Swipe Session + Shop (read-only, pre-installed decks) + basic user profile. No AI, no multiplayer.
- [ ] **Option C (Full Phase 1–3 from roadmap)**: Everything in the phased roadmap through Phase 3 (Shop + Marketplace), leaving only gamification + AI for v2.
- **Your Answer / Notes**: all the core and basic features, but no future "later updates" features.

### Q13.2 | What is the intended monetization model for Memory Card?
- [x] **Option A (Free forever — no monetization)**: Purely a passion project; all features free.
- [ ] **Option B (Freemium — Free core, paid premium features)**: The core swipe engine is free; advanced features (gamification, cloud sync, AI co-pilot, extra card types) unlock via a subscription or one-time purchase.
- [ ] **Option C (Paid upfront — one-time purchase app)**: Premium app priced at $2.99–$9.99 with no in-app purchases.
- [ ] **Option D (Deck marketplace revenue share)**: Free app, but creators earn a % of revenue when users purchase their premium decks.
- **Your Answer / Notes**: for now its free, in a later update we will open the option to sell them for a price. 

### Q13.3 | Should the app have push notifications for spaced repetition review reminders?
- [x] **Option A (Yes — Smart daily review reminders based on what's due today)**: FSRS calculates what's due, and a notification fires at a user-set time (e.g., 7 PM) summarizing "You have 24 cards due in German Basics."
- [ ] **Option B (Yes — but only simple daily reminders with no personalization)**: A single daily ping at a set time: *"Time to review your cards!"*
- [ ] **Option C (No notifications for MVP)**: No push notifications at launch — users open the app at their own discretion.
- **Your Answer / Notes**:
