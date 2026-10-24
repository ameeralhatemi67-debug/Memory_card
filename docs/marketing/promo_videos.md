---
type: plan
okm_type: reference
project: "[[README|Memory Card]]"
tags:
  - project/memory-card
  - document/marketing
  - motion-design
  - status/draft
created: 2026-10-24
updated: 2026-10-24
status: draft
aliases:
  - Memory Card Promo Videos
  - Promotional Motion Design Plan
related:
  - "[[progress|Memory Card Progress]]"
  - "[[Roadmap|Memory Card Roadmap]]"
---

# Memory Card · Promotional motion videos

Nine video plans (six asked for, three bonus shorts), written as a motion designer's brief: what each video is
for, the beat sheet with timecodes, how things move, what you hear, what to capture from the app, and the
cut-downs. After the videos: decks that would play well on camera, and features that would make the app (and
its videos) more shareable.

> [!summary] The nine videos
> | # | Title | Length | Formats | Job |
> |---|---|---|---|---|
> | 1 | **You will forget this** | 20 s | 9:16 · 1:1 | The short intro: stop the scroll, teach the swipe, show the logo |
> | 2 | **The endless stack** | 55 s | 16:9 · 9:16 | The full introduction: problem → mechanic → intelligence → habit → yours |
> | 3 | **Your home screen remembers too** | 32 s | 9:16 | Widgets showcase |
> | 4 | **We read how you answer** | 45 s | 16:9 · 9:16 | The engine, made visible (the thing no other flashcard app can show) |
> | 5 | **Make it yours** | 35 s | 9:16 · 1:1 | Creating: deck maker, skins, seals, picture cards |
> | 6 | **Guess it in 3 seconds** | 15–25 s, a series | 9:16 | Interactive quiz episodes: the engagement engine |
> | 7 | Bonus · **Satisfying stack** | 15 s loop | 9:16 | Sound-and-motion loop (ASMR) |
> | 8 | Bonus · **Pressed in wax** | 25 s | 9:16 | Seals, streaks and the membership card tiers |
> | 9 | Bonus · **Hiragana in 7 days** | 40 s | 9:16 | A challenge diary: proof it works |

> [!success] Ready for production (2026-10-24)
> The app build with everything below is `release/MemoryCard-1.4.0.apk` (90 decks, 2,507 cards). Thirteen decks
> were added for these videos, each reviewed card by card. Their pictures are in
> `app/assets/content/img/<deck-id>/` (use them directly as stills in the compositions).
>
> | Deck (shop name) | id | Cards | Made for |
> |---|---|---|---|
> | Anime · Whose Eyes? | `anime-eyes` | 25 | Video 6 episodes, the strongest hook: an eyes strip on the front, the full character on the reveal (Naruto, One Piece, HxH, Demon Slayer, JJK, Dragon Ball, AoT) |
> | Demon Slayer · Characters | `demonslayer-characters` | 26 + skin (Infinity Castle) + 2 seals | Video 1/2 montages, Video 5 (skins), Video 8 (seals) |
> | Jujutsu Kaisen · Characters | `jjk-characters` | 26 + skin (Jujutsu High) + 2 seals | as above |
> | Dragon Ball · Characters | `dragonball-characters` | 28 + skin (West City) + 2 seals (four-star ball, turtle school) | as above |
> | Attack on Titan · Characters | `aot-characters` | 27 + skin (the Scouts at the sea) + 2 seals (Wings of Freedom, unicorn) | as above |
> | Countries · Silhouettes | `country-silhouettes` | 41 | Video 6 "who's that?": a black shape, the shape filled with its flag on the reveal |
> | Flags · Look-alikes | `flags-lookalike` | 30 | Video 6 "hard mode" (Chad/Romania, Indonesia/Monaco…) |
> | Paintings · From a Detail | `paintings-details` | 24 | Video 6: a detail on the front, the whole painting on the reveal |
> | Road Signs · World | `road-signs` | 28 | Video 6: kangaroos, moose, tanks, polar bears… |
> | Capitals · Not the Big City | `capitals-surprise` | 27 | Video 6 text episode ("not Sydney, not Melbourne") |
> | Kanji · Pictures | `kanji-pictographs` | 36 | Video 9 companion, Video 6: one big kanji on the card |
> | Mind · Cognitive Biases | `cognitive-biases` | 30 | Relatable "that's me" episodes |
> | NATO Phonetic Alphabet | `nato-alphabet` | 26 | Rhythm/sound episode (each answer carries its Morse code) |
>
> Already in the shop and video-ready: the football decks (crests with a Wembley skin, legends, stadiums, the World
> Cup with its skin and seals), Naruto / One Piece / Hunter x Hunter with skins and seals, flags, languages.
>
> **Capture setup.** Install the APK on a real phone (the emulator records too few frames per second for
> motion), add the decks for the video from the shop (search by name), pick the theme. For perfectly smooth or
> slow-motion card shots, render frames from the app itself: `flutter test test_gallery/new_decks_gallery_test.dart`
> (each new deck's cards, front and revealed) and `test_gallery/looks_gallery_test.dart` (nav, skins, seals,
> deck maker), output in `app/build/gallery/`.
> One small app change came with this: a card whose prompt is one to three characters (a kanji, a letter, a
> kana) now shows it as one big glyph in the middle of the card.

---

## 0 · The motion system (applies to every video)

Every video should feel like the app: **paper, not glass.** Things are cards, folders and wax. They have weight,
they arrive with a small overshoot and leave faster than they came, and nothing ever pops out of nothing.

**Colour** (from the app's tokens)

| Role | Light | Dark |
|---|---|---|
| Canvas | paper `#F1F1F1` | `#151515` |
| Ink surfaces (inverse ink) | `#333333` | `#F1F1F1` |
| Accents | blue `#80AEFF` · peach `#FFC680` · red `#D35F5F` · green `#8BD3A0` · tier tan `#D9A273` |
| Category tabs | football `#79C267` · anime `#B59CFF` · cars `#F0D060` · geography `#6FD0C8` |

Use one accent per scene; red is reserved for the moment of success (the DONE seal) and for "forgot".

**Type.** Display: Bernard MT Condensed, set tight and big (headline words fill 60–80 % of the frame width).
Text: Barlow Semi Condensed 600. The Bernard file is in `app/assets/fonts/` (copy it into the video project).

**Motion vocabulary** (lift these straight from the app so the videos and the product feel like one thing)

| Move | Spec | Use |
|---|---|---|
| Paper ease | `cubic-bezier(.2,.8,.2,1)`, 380 ms in / 260 ms out | Every entrance and exit |
| Springy settle | `cubic-bezier(.34,1.35,.5,1)` | Cards landing, tabs drawn up |
| Card flip | rotateY 0 → 180° with perspective, 480 ms, the face swaps at 90° | Every reveal |
| Swipe | card follows a slight arc, rotates up to 12°, flies off with motion blur | Right = remembered (green glow), left = not yet (red edge) |
| Wax stamp | drops from 150 % at −22°, hits 92 %, bounces to 104 %, settles at 100 % (700 ms) + 2-frame camera shake | Goal met, seals |
| Deck riffle | the five fan cards lift and lean back-to-front, 90 ms apart | Transitions between scenes, idle loops |
| Hand of cards | tabs fanned about a point far below frame; the chosen card rises and floats | Nav bar shots, "menu" transitions |
| Swap | out-card slides left −24 %, −11°, 86 %, fades; in-card arrives from the right with overshoot | Before/after, side switches |
| Deal | two cards leave a card back face down, flip in the air, land | Revealing two options or a pair of facts |

Transitions between scenes are physical: a card wipes the frame (a full-bleed card slides over and becomes the
next background), a folder opens, the stack riffles. No cross-dissolves, no glitch effects, no light leaks.

**Texture.** Felt wall in light mode, concrete in dark, kraft folders, wax on seals, a faint paper grain over the
whole frame (2–3 %). Window light falling from the top left. All of it exists in the app's texture assets.

**Sound.** Use the app's own sound palette (`app/assets/sounds/`, synthesized, so it is ours): `tick` (lock-in),
`flip` (reveal), `good` (two marimba notes up), `easy` (three), `again` (soft low thup), `pop`, `stamp`,
`whoosh`, `undo`, `fanfare` (C-E-G-C and a bell chord), `seal` (two bells a fifth apart), `card` (the nav snap),
`deal`. Music bed: warm, light, acoustic-electronic (marimba, pizzicato, soft kick) at 96–110 BPM so swipes land
on beats. Every hard cut lands on a beat; every swipe is a percussion hit. Leave room: the app sounds sit on top
of the music, not under it.

**Formats and safe areas**

| Format | Size | Notes |
|---|---|---|
| Reels / TikTok / Shorts | 1080 × 1920, 9:16 | Keep text out of the top 250 px, the bottom 420 px and the right 140 px (platform buttons) |
| Feed square | 1080 × 1080 | Phone mockup centred, captions under it |
| YouTube / website | 3840 × 2160 or 1920 × 1080 | Room for the phone plus big type side by side |
| Google Play promo video | a YouTube link, 30 s – 2 min, landscape preferred | Video 2 is the candidate |
| App Store app preview (when iOS exists) | 15–30 s, device resolution, mostly real app footage | A trimmed Video 1 |

Burn in captions on every social cut (most people watch muted). The phone is a neutral, unbranded frame with
thin bezels; never a real manufacturer's design.

**End card (all videos).** The three-card logo deals itself out (the logo's three cards land one by one with the
`card` sound), "Memory Card" in Bernard underneath, the line of the video, and the store badge (placeholder
until the app is published). 2.5 s, held still for the last 1 s.

**Decks to feature.** The anime and football decks carry the most views: open the big moments (the hook, the
speed montage, the skins) on them. Languages, flags and paintings show the app is for learning too.

---

## 1 · You will forget this (short introduction, 20 s)

**Job.** First contact on Reels/TikTok/Shorts. In 20 seconds: a problem everyone feels, the one gesture, the
promise, the name. **Formats:** 9:16 master, 1:1 cut. **Music:** 104 BPM, builds from a single marimba.

**Hook (0–2 s).** Black text on paper, centred, huge: **"YOU WILL FORGET THIS."** While you read it, the letters
lose ink one by one, the way a memory fades, until only "THIS" is left. A card slides up under it and catches it.

| Time | Picture | Motion | Sound | On screen |
|---|---|---|---|---|
| 0.0–2.0 | Headline on paper | Letters fade out left to right, 40 ms apart | One low marimba note, room tone | YOU WILL FORGET THIS. |
| 2.0–3.5 | "THIS" drops onto a card that rises into a phone screen | Springy settle; camera pulls back to reveal the phone | `whoosh`, then `pop` | — |
| 3.5–6.0 | The study screen: a Spanish card "el gato". A finger taps, the card flips: "the cat" | Card flip at 480 ms | `flip` | Think. Tap. |
| 6.0–8.0 | Swipe right: the card flies off right with a green glow, the next card is underneath | Arc + 12° tilt + motion blur | `good` on the beat | Knew it? → |
| 8.0–10.0 | Next card. Swipe left: red edge, card tucks into the stack, and a small counter "back in 12 cards" ticks | The card slides *into* the stack, visible as a thin edge 12 cards down | `again` | Not yet? ← It comes back. |
| 10.0–14.0 | Speed montage: 8 swipes in 4 s across 4 decks (flags, French, periodic table, world capitals), each on a beat | Hard cuts on every beat; the deck's category tab colour flashes on each | marimba arpeggio climbing | — |
| 14.0–16.5 | The daily goal bar fills; the red **DONE** wax seal stamps down over the screen | Wax stamp keyframes + 2-frame shake | `stamp`, then `fanfare` tail | Goal met. |
| 16.5–17.5 | The streak flame at the top flickers, "4" ticks to "5" | Digit flips like a split-flap | `tick` | 5-day streak |
| 17.5–20.0 | End card | Logo deals itself | `card` ×3 | **Memory Card** · Remember it for good. |

**Cut-downs.** 15 s (drop the speed montage to 2 s); 6 s bumper (hook → DONE seal → logo).
**Capture.** Study screen with a clean language deck, a goal one card from done, a 4-day streak, light theme.

---

## 2 · The endless stack (full introduction, 55 s)

**Job.** The long introduction for YouTube, the website and the Play Store promo slot: why spaced repetition
works, how Memory Card makes it effortless, and why it feels different. **Formats:** 16:9 master (phone on the
right, big type on the left), 9:16 cut (type above the phone). **Voice-over:** optional; written below so it also
works as on-screen text only. **Music:** 100 BPM, four sections, swells at 0:38.

| Time | Section | Picture and motion | VO / on-screen text | Sound |
|---|---|---|---|---|
| 0:00–0:05 | Hook | A tall stack of paper cards. One by one they go blank from the bottom up, a memory evaporating. | "You learn something today. By next week, most of it is gone." | Pages riffling, getting quieter |
| 0:05–0:10 | The idea | The stack rebuilds itself card by card as a curve draws across the frame: a forgetting curve that is *caught* and pushed back up each time a card returns. | "Unless it comes back at exactly the right moment." | `tick` on each catch |
| 0:10–0:18 | The gesture | Phone in. Card flips (reveal first). Right swipe, left swipe, with the two arrows labelled. | "One stack. Swipe right if you knew it. Left if you didn't." | `flip`, `good`, `again` |
| 0:18–0:24 | The stack | Cut to a diagram view: the stack seen from the side as a row of cards; the missed card visibly slides back 12 places; the remembered card goes to the end. Numbers "8–20" bracket the gap. | "Miss one and it comes back a few cards later, close enough to meet again today, far enough to really recall it." | Soft whoosh |
| 0:24–0:32 | It reads you | A finger hesitates over the card; a thin timing ring fills; a "confidence" needle wavers; the grade chip lands: **Hard**. Next card: a fast, sure swipe; the chip lands **Easy**. | "And it notices how you answered. Fast and sure? It rests longer. Hesitant? It comes back sooner." | `tick` for the chip, two different pitches |
| 0:32–0:38 | Your library | Pull back out of the phone into the folder drawer: kraft folders slide in, deck bars fan out with their skins (French, world capitals, your own deck with a photo skin). | "Decks for languages, science, geography, history, code. Or make your own." | Paper slides, `pop` per folder |
| 0:38–0:45 | The habit (music swells) | The daily goal fills → DONE seal stamps → streak flame → a seal ("One week") stamps into the membership card, which swaps to its back to show five weeks of activity. | "Hit your goal and stamp the day. Build a streak, with two grace shields a month for real life." | `stamp`, `seal`, `fanfare` |
| 0:45–0:50 | Everywhere | The phone's home screen: widgets dealt onto it, the Quick card answered without opening the app. | "Even from your home screen." | `deal` |
| 0:50–0:55 | End card | Logo deals, line, badge. | "Memory Card. Remember it for good." | `card` ×3, final chord |

**Notes.** The 0:05–0:10 curve is the visual signature of the whole campaign: reuse it in Videos 4 and 9.
Show "Offline · no account needed" as a small line under the end card (true today).
**Cut-downs.** 30 s (sections hook, gesture, it reads you, habit, end); 9:16 version keeps every section but
drops the side diagram for a top-down stack.

---

## 3 · Your home screen remembers too (widgets, 32 s)

**Job.** Show that Memory Card lives outside the app: review a card, keep a streak, see tomorrow, without opening
anything. Widgets are a rare thing for a flashcard app and they look great moving. **Format:** 9:16 only (it
is a phone thing). **Music:** 108 BPM, plucky, each widget lands on a beat.

**Hook (0–2 s).** An empty home screen. A hand of cards (the app's nav bar, scaled up) fans up from the bottom
edge, and with a flick each card *flies onto the wallpaper and becomes a widget.*

| Time | Picture | Motion | Sound | Text |
|---|---|---|---|---|
| 0.0–2.0 | Empty home screen, the hand rises from the bottom | Hand of cards, springy | `whoosh` | — |
| 2.0–6.0 | Cards fly onto the grid one per beat and unfold into widgets: Daily goal seal 2×2, Streak flame 4×1, Today 4×2, Next two weeks 4×2 | Each card flips mid-air and snaps to its grid cell; the widget's own motion starts the moment it lands (seal turns, flame flickers) | `card` per landing | Widgets that keep you going |
| 6.0–12.0 | Close-up: the **Quick card**. Finger taps *Reveal*, the card turns, taps *Got it*, the next card slides in | The widget's own turn | `flip`, `good` | Review without opening the app |
| 12.0–15.0 | The goal seal fills to the goal and turns red: DONE | Seal ring sweeps, then the stamp | `stamp` | Your goal, at a glance |
| 15.0–19.0 | The **Membership card** widget: tap, it swaps to its back (five weeks of activity), tap, swaps back | The real swap (slide left / arrive from the right) | `card` | Your card. Both sides. |
| 19.0–24.0 | *Settings › Widgets* in a split screen: the accent goes red → blue → green and **every widget on the home screen changes colour with it**, a wave across the grid; then light ↔ dark | Colour wave, 60 ms stagger by grid position | rising `tick`s | Make them yours |
| 24.0–28.0 | Fast montage of the rest: Activity heat map, Card of the day, Seals, Continue a deck, Quick actions, the tall Streak flame, the Quick Settings tile "20 to go" | Each 0.5 s, hard cuts on beats | percussion | 13 widgets · a Quick Settings tile |
| 28.0–32.0 | End card | | | Memory Card · on your home screen |

**Capture.** Real widgets on a clean wallpaper (a calm gradient), both themes. The emulator records at a low
frame rate: record on a real phone, or render the widget frames with the debug widget dump and animate them in
the composition. (Android only today; say "Android" in the caption, not "your phone".)

---

## 4 · We read how you answer (the engine, 45 s)

**Job.** The differentiator. Every flashcard app says "spaced repetition"; this one *reads how you answer* and
runs an open memory model in the shadow. This video makes that intelligence visible without a single equation.
**Formats:** 16:9 master for YouTube and the website, 9:16 cut. **Style:** data visualisation in the paper
language: lines drawn in ink, charts that are cards, numbers on split-flap digits.

| Time | Picture | Motion | Text / VO |
|---|---|---|---|
| 0:00–0:04 | Two identical green "right" swipes, side by side | Mirror split-screen | "Two right swipes." |
| 0:04–0:10 | Replay both slowed down with their data traced on top: left one, the finger moves straight, 1.2 s; right one, it stops, drifts back, goes, 4.8 s | A pen line traces each finger path; a timing ring fills beside each | "Same answer. Not the same memory." |
| 0:10–0:16 | The two grade chips land: **Easy** (left), **Hard** (right). Each card's "next time" slides out: *in 9 days* vs *tomorrow* | Chips stamp like seals | "Memory Card reads the hesitation, the speed, the second-guessing." |
| 0:16–0:26 | A forgetting curve draws for one card; each review catches it and the next curve is flatter (memory getting stronger). A dotted line at 90 % marks "slipping". | Line drawing, each review is a `tick` and a small card icon | "Every swipe updates a memory model, FSRS-6, that predicts how likely you are to remember each card, right now." |
| 0:26–0:32 | The deck bar's five-card fan fills step by step as cards pass 90 % | The app's own fan, riffling | "That's the fan on every deck: how much of it is safely remembered." |
| 0:32–0:40 | Memory Lab: *The next two weeks* bars grow; *Is the model right about you?* dots settle near the line; the *Train on my reviews* button presses and the line bends to fit | Bars grow with springy settle | "And it learns you: your normal speed, your own forgetting rate. Train it on your history, on your phone." |
| 0:40–0:45 | End card | | "Memory Card. It knows what you're about to forget." |

**Care with claims.** Say what the app does, not superlatives about other apps. "On your phone, offline" is
true and strong. Don't promise exam results.
**Cut-downs.** A 15 s teaser of 0:00–0:16 only ("Same answer. Not the same memory.") is the strongest hook in
the whole campaign.

---

## 5 · Make it yours (creation, 35 s)

**Job.** Show the creative side: anyone can make a deck that looks like theirs in a minute. Targets students,
teachers and hobbyists. **Formats:** 9:16, 1:1. **Music:** 104 BPM, playful.

| Time | Picture | Motion | Sound | Text |
|---|---|---|---|---|
| 0.0–2.0 | The nav's **+ card** is tapped; it deals two cards face down; they flip: *New deck*, *New card* | The real deal animation, full screen | `deal` | Make a deck |
| 2.0–7.0 | Deck maker: type a name ("Kitchen Spanish"), the live bar updates letter by letter; tap *Picture*, a photo of your kitchen drops in; drag it to place it; the shade slider; light text | The real preview bar; the drag shown with a touch dot | keyboard taps, `pop` | Give it a look |
| 7.0–13.0 | Seal maker: square → wide, wax colours tapped (red, gold, teal), "OLÉ" typed, a PNG cut-out pressed in; the seal re-stamps on every change | The real stamp animation, sped up 1.5× | `stamp` per change | Design its seal |
| 13.0–19.0 | Card editor: "la sartén" / "the frying pan"; add a picture; *Arrange* opens the free canvas, the picture is pinched and moved, a PNG cut-out keeps its transparent edges | Canvas editor | soft ticks | Pictures on any side |
| 19.0–24.0 | CSV import: paste a list, 40 cards **shower** into the deck as a waterfall of little cards | Particle shower of cards into the stack | rising `pop`s | Or import 40 at once |
| 24.0–30.0 | Back home: the new deck bar with its photo skin among the others; study a card; the custom seal stamps when a milestone is reached | Seal dialog | `seal` | Earn your own seals |
| 30.0–35.0 | End card | | | Memory Card · your decks, your way |

**Capture.** A real kitchen photo you own; a PNG cut-out you made (no stock art). Light theme reads best.

---

## 6 · Guess it in 3 seconds (interactive quiz series, 15–25 s each)

**Job.** The one that grows the audience. Short, repeatable episodes where viewers play along and comment their
answers; every episode is also an ad for a specific deck. Post 2–3 a week. **Format:** 9:16.

**Episode formula** (≈ 20 s, 4 cards)

| Time | Beat |
|---|---|
| 0.0–1.5 | Title card in Bernard: "**Guess the flag** · hard mode" + the category tab colour. A countdown sound starts. |
| 1.5–5.5 | Card 1: the front fills the screen. A circular timer (3 s) burns around it like a fuse. |
| 5.5–6.5 | Flip to the answer + the hook line ("Chad · nearly identical to Romania"). `good`. |
| 6.5–17.0 | Cards 2–4, each a little faster (3 s → 2.5 s → 2 s). The last one is the hardest. |
| 17.0–20.0 | "How many did you get? Comment your score." + the deck in the shop: "Flags · Africa, 54 cards, free". |

**Episode ideas**

1. Flags that look alike (Chad/Romania, Indonesia/Monaco, Ireland/Côte d'Ivoire, Australia/New Zealand)
2. Capitals that aren't the biggest city (Canberra, Ottawa, Ankara, Brasília, Abuja)
3. Name the painting from a detail (a crop on the front, the whole painting on the reveal)
4. Kanji that look like what they mean (山 mountain, 川 river, 木 tree, 人 person)
5. Element or not? (made-up names mixed with real ones: "Moscovium" is real)
6. Which country, from its silhouette (needs the silhouette feature, below)
7. Football: whose crest is this, which stadium, who won the 1966 World Cup
8. False friends: "embarazada" doesn't mean embarrassed
9. Anime: whose eyes are these? (a strip of the eyes, the full character on the reveal)
10. Who's that? A country (or a character) as a black silhouette, the colours on the reveal

**Motion.** The fuse timer is the series' signature: a thin ink line burning around the card edge with a tiny
spark at its head. Reveal = the app's flip. Every episode ends on the same branded "score" card.

---

## 7 · Bonus · Satisfying stack (15 s loop)

**Job.** Pure sound and motion: the kind of loop people watch three times. No text except the logo at the end.
**Format:** 9:16, made to loop seamlessly (last frame = first frame).

Top-down macro view of the stack on felt. A rhythm of swipes on a 120 BPM grid: right, right, left, right; each
with its own sound (`good`, `good`, `again`, `easy`). Between phrases the deck riffles. At 10 s the DONE seal
stamps dead centre (bass hit), the camera pushes into the wax texture and comes out on the first frame.
Shot in dark mode for contrast. **Capture:** render from the app's test harness at 60 fps so it is perfectly
smooth and repeatable.

---

## 8 · Bonus · Pressed in wax (seals and tiers, 25 s)

**Job.** The collection hook: seals, custom deck seals, and the membership card climbing tiers.

0–6 s: the twenty round seals stamp one after another in a grid, faster and faster (`stamp` turning into a
drum roll). 6–12 s: square and wide deck seals stamp in, in their nine wax colours. 12–20 s: the membership card
swaps through its tiers, Bronze → Silver → Gold → Platinum, the tier pill changing colour and the numbers
rolling up on split-flap digits. 20–25 s: end card, "Every day leaves a mark."

---

## 9 · Bonus · Hiragana in 7 days (challenge diary, 40 s)

**Job.** Proof that it works, told as a real person's week. Film it for real: someone who can't read hiragana
studies the deck 10 minutes a day for 7 days; record the phone each day.

Each day is a 4 s chapter: a big split-flap "DAY 3", the deck bar's fan filling a little more, the Memory Lab
retention number, one card they now know. The forgetting curve from Video 2 draws across the week, caught
every day. Day 7: they read a sign (あ い う え お) out loud, on camera. End: "7 days. 10 minutes a day."
**Only publish what really happened**: real numbers from the real week.

---

## Decks that would grab attention (for videos and for the shop)

The best decks on video are **visual, guessable in 3 seconds, and a little surprising**. Ranked by how well they
would work, with whether we can show them publicly.

| Deck | Why it works on camera | Card format |
|---|---|---|
| **Flags that look alike** | Instant "wait, what?"; comments argue | Picture front (flag), answer + the look-alike in the hook |
| **Countries by silhouette** | Shapes are a game everyone plays | Black shape front, the shape filled with its flag on the reveal |
| **Capitals that aren't the biggest city** | Surprises people who think they know | Text, with the "biggest city" as the trap |
| **Paintings: name it from a detail** | Zoom-out reveal is beautiful motion | A crop on the front, the full painting on the back |
| **Kanji that look like their meaning** | Visual, satisfying, teaches in 2 s | Big kanji, picture-mnemonic hook |
| **Road signs of the world** | Practical (driving tests) and odd ones are funny | Sign front, meaning back |
| **Phonetic alphabet & Morse** | Rhythm and sound | Letter front, "Bravo" / dot-dash back |
| **Cognitive biases** | Relatable, shareable "that's me" moments | Scenario front, bias name back |
| **Anime: whose eyes?** | Fans recognise a character from a glance; huge comment bait | Eyes strip front, the full character back |
| **More anime series** (Demon Slayer, Jujutsu Kaisen, Dragon Ball, Attack on Titan) | The biggest fan bases on short-video platforms | Character front, name back |
| **Football** (crests, legends, stadiums, World Cup) | Huge audience, debate in comments | Already in the shop |

---

## Features that would make the app (and its videos) better

Ordered by impact on growth versus effort.

| # | Feature | Why it helps | Effort |
|---|---|---|---|
| 1 | **Share a card / a result as a vertical image or clip** | Every user becomes a promo: a branded 9:16 card flip, a score, a goal stamp, ready for Stories. The single biggest growth loop. | Medium (render the card widget to video frames, share sheet) |
| 2 | **Silhouette reveal** for PNG cut-out pictures | The shape is shown in solid ink, the full colour appears on reveal: "Who's that?" is the most watchable card format there is. Easy with the alpha channel we already keep. | Small |
| 3 | **Detail-zoom reveal** | The front shows a crop, the reveal pulls back to the whole picture. Reuses the canvas editor's crop data. | Small–medium |
| 4 | **Speed round** (60 s, timer, score card at the end) | A game mode that films itself; pairs with Video 6 and with sharing. | Medium |
| 5 | **Film mode** (debug / hidden) | Seeds a perfect demo library, fixes the clock at 9:41, sets the streak and goal, shows touch dots, optionally slows animations. Makes every capture clean and repeatable. | Small |
| 6 | **Audio on cards** | Bird songs, anthems, real pronunciation recordings; great for Phonetic/Morse and languages. | Medium |
| 7 | **Monthly recap ("Your month in memory")** | An auto-generated animated summary in the app (cards learned, best streak, seals), itself shareable: our own "Wrapped". | Medium |
| 8 | **Seasonal seals** (e.g., a World Cup month seal) | A recurring reason to post and to come back. | Small (deck seals already exist) |
| 9 | **Challenge a friend** with a deck link | Social pull; needs accounts and a backend later. | Large |

---

## Production pipeline

1. **Capture**: real-phone screen recordings for touch footage (the emulator records too few frames per second);
   for perfect motion (loops, slow-motion, the widget swap), render frames from the app's own test harness
   (`test_gallery/`) at 60 fps, which gives clean, repeatable frames at any size.
2. **Compose**: the motion graphics (type, curves, phone frame, transitions) in an HTML-to-video tool such as
   HyperFrames, or After Effects; the app's sounds and tokens are the shared kit.
3. **Order**: produce Video 1 and Video 6 (two episodes) first: they test the hook and the format cheapest.
   Then Video 3 (widgets), Video 2 (needs the most polish), then 4 and 5.

> [!question] Open before publishing
> - The store, the date and the platforms (Android only today): the end card needs real badges.
> - Who is filmed for Video 9.
