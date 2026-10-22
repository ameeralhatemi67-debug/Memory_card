---
type: research
project: "[[README|Memory Card]]"
tags:
  - project/memory-card
  - spaced-repetition
  - engine
  - implementation
created: 2026-10-22
status: implemented
builds_on: RES-47 (Endless Stack + Shadow FSRS)
companion_code: app/lib/engine/
---

# RES-48 — Memory Card Repetition Engine v2 (as built)

> **What this is:** the engine that ships in the Flutter app (`app/lib/engine/`), written down rule by rule with its numbers. RES-47 chose the design ("Endless Stack + Shadow FSRS"); this document records how it was implemented and what was added on top: grading from *how* you answer (speed, hesitation, confidence), self-tuning thresholds, personal calibration, an on-device optimizer, and the day/goal/streak model.

---

## 0. In one paragraph

Every deck is one endless stack you swipe through. Right means you remembered, left means you didn't; the swipe direction is the honest outcome and is never second-guessed. *How* you swiped decides the grade: a fast, clean answer compared with your own normal pace is **Easy**, a slow or wavering one is **Hard**, anything in between is **Good**. A missed card goes back **8–20 cards** (far enough that the next try is a real recall). Underneath, a shadow **FSRS-6** model tracks every card's stability and difficulty, calibrated to you, and drives everything you *see*: the slipping counts, the deck fans, memory health, the warm-up after a break, the reminder text and the forecast.

---

## 1. Signals captured per answer (`ReviewSignals`)

| Signal | Meaning |
|---|---|
| `thinkMs` | Card settled on top → reveal (front-only mode: → first touch). |
| `verifyMs` | Reveal → start of the swipe (time spent checking the answer). |
| `dragMs`, `velocity` | Duration of the swipe, release speed in the chosen direction (px/s). |
| `reversals` | Direction changes during the drag. |
| `crossings` | Times the commit line was crossed before letting go. |
| `hesitation` | Furthest excursion toward the *other* answer, as a fraction of card width. |
| `viaButton` | Answered with an ear button or a key: no drag to read. |
| `interrupted` | The app went to the background during the card. |
| `promptChars` | Length of the prompt, to normalise reading time. |
| `typedSimilarity` | Typing mode: similarity of the typed answer to the expected one (0–1). |

All of it is stored in the review log (`ReviewLog.signals`), so future versions can re-fit the model on real behaviour.

## 2. Personal baselines (`baselines.dart`)

Latency only means something relative to *your* normal, for prompts of *this* length.

- Think time is modelled in log-ms with a length term: `residual = ln(thinkMs) − 0.32 · ln(1 + chars/12) − deckOffset`.
- A robust window (median and MAD of the last 160 values) per user, plus a per-deck offset, so one deck being harder doesn't read as hesitation everywhere.
- Priors before data: think center 7.9 (≈ 2.7 s), MAD 0.42; verify center 7.0, MAD 0.5; shrink weight 10 observations.
- Only **correct, trusted, swiped** answers update the baseline.
- **Interruption filter:** a think time above max(25 s, center + 4.5 σ) — or the app being backgrounded — marks the answer untrusted: latency is ignored (fluency and verification fall back to 0.5), so a phone call never counts as hesitation and never becomes **Easy**.

## 3. The assessor (`assessor.dart`)

For each answer three scores in 0–1:

- **Fluency** = logistic(−1.25 · z_think): much faster than your normal → near 1, much slower → near 0.
- **Decisiveness** = 0.8 · clean + 0.2 · min(1, velocity / 1400), where clean = 1 − 0.22 · reversals − 0.18 · max(0, crossings − 1) − 0.9 · hesitation. Buttons and keys get 0.6.
- **Verification** = logistic(−1.0 · z_verify): a long stare at the answer lowers it.

**Confidence = 0.55 · fluency + 0.25 · decisiveness + 0.20 · verification.** In typing mode it is blended 50/50 with the typed-answer similarity (hard evidence).

Grades for a **recalled** card:

| Condition | Grade | Chip label |
|---|---|---|
| confidence ≥ easyAt (+0.05 on a card's first exposure) and latency trusted | 4 Easy | "Fast and sure" |
| confidence < hardBelow | 2 Hard | "Slow recall" or, if decisiveness < 0.5, "Second thoughts" |
| otherwise | 3 Good | "Solid" |

A **missed** card is always grade 1, but the engine distinguishes a *near miss* (a reversal, hesitation > 0.12, ≥ 2 commit crossings, or a slow trusted think time) from a *blank* (fast, decisive "no idea"). That changes where it goes back in (§5).

With **Smart grading** off (Settings), every recalled card is Good: plain binary self-grading. With it on, a chip under the card shows the grade it read ("Easy · to the back"; this can be hidden in Settings), and tapping the chip lets you change it to Again, Hard, Good or Easy.

## 4. Self-tuning thresholds (`GradeTuner`)

Start: **easyAt 0.74, hardBelow 0.34.** On each review at least a day after a graded one, the outcome is compared with what FSRS predicted. Every 40 such reviews per grade:

- If cards called **Easy** later succeed > 5 points *less* often than predicted, Easy was too generous: easyAt +0.02 (max 0.92). If they do > 4 points better, easyAt −0.01 (min 0.66).
- If **Hard** cards do > 5 points *better* than predicted, Hard was too harsh: hardBelow −0.02 (min 0.20); if worse, +0.01 (max 0.45).

Small steps, bounded, only from long-gap evidence: the thresholds converge on what your swipes actually mean.

## 5. The endless stack (`stack_rules.dart`, `study_engine.dart`)

| Outcome | Where the card goes |
|---|---|
| Good / Easy | The back of the stack. |
| Hard | After ~40 % of the stack (min 12 cards). |
| Missed | Position round(8 + 12 × card success rate), then +3 if it used to be strong (S ≥ 7 days), −2 after 3+ lapses, +2 for a near miss, −2 for a blank; clamped to **8–20** and to the stack length. |
| Missed for the 8th time | Marked a **leech**, sent to the back, and the chip offers to rewrite it. |

- **Reverse siblings** (front→back and back→front of the same card) never sit within 10 cards of each other.
- **Resting:** with "Let mastered cards rest" on, a card with S ≥ 30 days and predicted recall ≥ 97 % skips its turn (moved to the back without counting). If everything is resting, cards are shown anyway.
- **Warm-up:** opening a deck after 2+ days moves its 20 weakest cards (lowest predicted recall) to the top, keeping siblings apart.

## 6. Pacing new cards (flow guard)

New cards wait in a per-deck **reservoir** and join the stack only while you're succeeding:

- An exponential moving average of success (α = 0.05) per deck.
- **Relaxed:** a new card joins while the average is ≥ 80 %. **Balanced (default):** ≥ 75 %. **Intense:** the whole deck is in the stack from day one.
- **Struggling** (≥ 10 answers this session and < 50 % of the last 10 right): new cards pause, and the chip says so.
- **Flying** (≥ 15 answers, ≥ 93 % of the last 15 right, average ≥ target + 8 points): two new cards join instead of one.
- New cards enter 3 places from the top (staggered by one each), so they arrive soon but not instantly.
- An empty stack is seeded with up to 15 cards from the reservoir.

## 7. Shadow FSRS-6 (`fsrs.dart`)

- FSRS-6 with the 21 published default weights. Verified against the reference `fsrs` Dart package (a port of py-fsrs) to 1e-9 on stability and difficulty across mixed sequences, including same-day repeats (`test/fsrs_test.dart`).
- Elapsed time is counted in **study days** (the day turns at 04:00, so a late-night session belongs to the evening before).
- The model never decides *when* you see a card (the stack does). It provides predictions: recall now, when a card will slip below 90 %, stability, difficulty, and everything built on them.

## 8. Calibration to you (`calibration.dart`)

RES-47 found default FSRS predicting 90 % where a learner actually recalled 23–66 %. So predictions are calibrated:

- Every review at least half a day after the previous one is kept (days elapsed, stability before, success), up to 400.
- From 30 points on, a single **time multiplier m** is fitted by bisection on log m ∈ [0.25, 4] so the mean predicted recall R(t·m) equals your observed recall, then shrunk toward 1 with weight n/(n + 60).
- m > 1 means you forget faster than the default model. Every prediction in the app uses it. The Memory Lab shows m and a predicted-vs-remembered chart.

## 9. Personal model training (`optimizer.dart`)

Once **150 reviews at least a day apart** exist, Memory Lab offers **Train on my reviews**:

- Coordinate search on log loss over the weights that matter most for one person: the four initial stabilities (w0–w3), recall-stability growth (w8), post-lapse stability (w11) and the forgetting-curve decay (w20), each within bounds.
- An L2 pull toward the defaults so a small history can't overfit; only long-gap reviews are scored.
- Runs in a background isolate. The search only accepts changes that lower the (penalised) loss; the new weights are saved, every card's memory state is recomputed from its history and calibration is re-fitted on top. The Lab reports how much the prediction error dropped and can switch back to the defaults.

## 10. Day, goal, streak

- **Daily goal** (default 20): the goal is met at the target number of swipes **or** when every card that was slipping at 04:00 has been seen once (with a floor of min(goal, 10) swipes), whichever comes first. The stack keeps going after the goal.
- **Streak:** days with the goal met. Missed days use **grace shields** (2 per calendar month) before the streak breaks.
- **Comeback:** reaching the goal after 8+ days away (with 50+ total reviews) earns a seal instead of a guilt trip.
- **Daily mix:** the slipping cards of every deck, most urgent first, interleaved so the same deck rarely comes twice in a row (RES-17); answers count for each card's own deck.

## 11. Deck mastered

The first time every card of a deck (5 or more cards) stands above 90 % predicted recall — all five steps of its fan — the swipe that did it reports `deckMastered`, the deck records `masteredAt`, and the study screen stamps a green **MASTERED** wax seal. Once per deck; resetting the deck clears it.

## 12. Seals (`seals.dart`)

20 wax-seal achievements, each earned once: first swipe, first goal, streaks (3, 7, 14, 30, 100, 365), swipes (100, 1 000, 5 000), mastered (10, 100), 25 in a row, night owl, early bird, comeback, author (25 cards written), polyglot (three language decks in a day), tuned (trained the model).

## 13. What the screens read from the engine

| Screen | From the engine |
|---|---|
| Deck bar fan | 0–5 steps, one per 20 % of cards with predicted recall ≥ 90 %. |
| "N slipping" / reminder text | Cards below 90 % now (or by tomorrow, for the reminder). |
| Memory health | Mean predicted recall of reviewed cards. |
| Card detail | Recall now, stability, difficulty, the forgetting curve with your calibration, every past answer with its think time. |
| Memory Lab | Forecast of the next 14 days, calibration chart, answering style (grades and thresholds), recall by time of day, a year heatmap, trickiest cards. |

## 14. Verification

- `test/fsrs_test.dart`: FSRS-6 equals the reference implementation to 1e-9.
- `test/engine_test.dart` (21 tests): re-insertion distances, near miss vs blank, siblings, warm-up, assessor grading, adaptive baseline, interruption filter, Easy-threshold tuning, binary mode, pacing and the flow guard, leeches, resting, goal/streak/shields, deck mastery, the review log.
- `test/model_fit_test.dart`: calibration recovers a learner who forgets 2× faster (fitted m within 1.6–2.3 after shrinkage) and stays at 1 on thin evidence; training on a synthetic learner's history lowers log loss, moves only the personal weights, and refuses histories without 150 long-gap reviews.
- `test_gallery/sim_test.dart`: two simulated weeks (820 swipes) through the real store in 1.4 s.
- UI tests drive onboarding, swipes, undo, grade changes and every screen.
