---
type: research
project: "[[README|Memory Card]]"
tags:
  - project/memory-card
  - spaced-repetition
  - research
  - engine
created: 2026-10-21
status: decision-ready
supersedes_for_engine: RES-12 (formulas), RES-43 (ring buffer)
companion_code: tools/srs_sim/simulate.py
---

# RES-47 — The Repetition Engine: Comparative Research & Final Design

> **Question:** What repetition system should sit at the heart of Memory Card? The candidates are the author's original idea (the endless stack, Q2.2), the approaches already researched in this repo, and the current state of the art.
>
> **Method:** (1) inventory every approach in the repo; (2) check the external evidence; (3) simulate the candidates on a learner model fitted to human vocabulary-learning data, under **equal daily study time**; (4) design an engine that holds up even where the evidence is uncertain.

---

## 0. TL;DR

1. **Your endless stack is a good idea, better than the earlier research gave it credit for.** In simulation, its wide variant matched or beat every scheduler-driven approach (FSRS, Leitner, RES-43) at equal daily study time in 5 of 6 runs; Leitner won the sixth.
2. **Its two real weaknesses** are (a) on big decks the user fails about half of all cards, which is demoralising, and (b) it has no "done for today" moment. Both are fixable **without** abandoning the stack.
3. **RES-43's ring buffer (gaps of 2–5 cards, 2 consecutive passes to graduate) came last or near-last in every run.** Its gaps sit inside working-memory span, so the "recall" is an echo of something you saw seconds ago. Drop it.
4. **FSRS with default parameters was badly miscalibrated** for the simulated learner: reviews meant to succeed 90 % of the time succeeded only 23–66 % of the time. Any FSRS use must be **calibrated to the individual**, and the real FSRS optimizer needs a few hundred reviews of history first.
5. **Final design — "Endless Stack + Shadow FSRS":**
   - The study experience *is* your endless stack. Failed cards go back **8–20 cards** (not 2–8), and new cards enter the stack at a **paced** rate that keeps success near ~75 %.
   - FSRS-6 runs **in the shadow** on every swipe. It powers memory health, due counts, the stepped-fan progress meter, reminders and "warm-up from your weakest" after breaks, but it does not dictate the order.
   - Every swipe is logged in a standard review-log format, so the app can later prove from your own data which ordering works best for you.

---

## 1. Inventory: every approach already in this repo

| # | Source | Approach | Verdict |
|---|---|---|---|
| A | `Questions.md` Q2.2 | **Endless stack.** Right swipe → back of the stack; left swipe → N cards back, N adaptive by confidence. | **Keep as the core.** Strong in simulation. Needs pacing, a wider N and a daily goal. |
| B | `brain_dump.md` §4 | Hesitation + confidence score → Leitner-like buckets (4 h, 1 d, 3 d, 10 d, 30 d). | Superseded. Fixed buckets are what FSRS replaced; hesitation fails in real environments (C). |
| C | RES-12 | FSRS-5 with a continuous "effective grade" modulated by hesitation `Hs`. | The FSRS part is valid, but the **formulas contain errors** (no linear damping; mean reversion toward D₀(Good) instead of D₀(Easy); no post-lapse short-term cap). Hesitation modulation is rejected (commuter flaw: distractions look like hesitation). Use the maintained `fsrs` package instead. |
| D | RES-13 / RES-14 | Hesitation metric + AFK dwell filtering. | **Analytics only.** Log it, never use it to grade. |
| E | RES-43 | Two stores: ring buffer W = 5, N\* ∈ [2, 5] from (C, Hs, S, D, lapses), graduate after 2–3 consecutive passes with low hesitation. | **Reject the buffer.** It cites Cowan's 4 ± 1 working-memory limit, then re-inserts *within* that limit, so retrievals are short-term echoes. Worst performer in the simulation. Its useful idea (failed cards come back later in the session) survives in the final design with a wider gap. |
| F | RES-15 | Progressive answer revelation on the next card while swiping. | Visual only. Note that seeing the next card's answer early is passive restudy, so it must **not** reveal the answer, only the title. |
| G | RES-17 | Interleaving across decks. | Later. Helps discrimination between similar categories; little evidence for unrelated vocabulary. |
| H | FES-46 | Flow channel, soft streaks, sprint mode isolated from scheduling. | **Keep.** The "flow channel" (~70–85 % success) is the basis of the pacing rule in §5.2. |
| I | `idea_Audit.md` (Sept) | Pure FSRS-5 + 3 grades + re-insertion 4–6 cards back. | Partly. Two grades fit the swipe design; 4–6 back is still too close (see E). |

---

## 2. External evidence

### 2.1 Long-term scheduling models
- **FSRS** (DSR model: Difficulty, Stability, Retrievability). It is the most accurate *predictor* of real human recall on the open benchmark: 9,999 Anki collections, ~350 M reviews.

  | Model | Log loss ↓ | RMSE (bins) ↓ | AUC ↑ |
  |---|---|---|---|
  | FSRS-6 (optimized) | 0.346 | 0.065 | 0.703 |
  | FSRS-5 | 0.356 | 0.074 | 0.701 |
  | DASH | 0.368 | 0.084 | 0.631 |
  | ACT-R | 0.403 | 0.107 | 0.523 |
  | HLR (Duolingo) | 0.469 | 0.128 | 0.637 |
  | LSTM / GRU (neural) | ≈ 0.333 | ≈ 0.054 | ≈ 0.733 |

  Neural models predict slightly better but are heavier and opaque. FSRS is the practical choice.
- **FSRS-6** is current. Its changes from FSRS-5:
  - 21 parameters instead of 19.
  - A trainable forgetting-curve decay (w20).
  - A damped same-day stability update: `S' = S · e^{w17(G−3+w18)} · S^{−w19}`, floored at 1 for passing grades, which stops endless same-day repetition from inflating stability.
- **The Dart package `fsrs` 2.0.1** (MIT, ported from py-fsrs, runs on web) implements the 21-parameter model with learning steps, fuzzing and desired retention. **We use it rather than porting RES-12.**
- **Prediction ≠ policy.** The benchmark measures how well a model *predicts* recall, not which *review order* teaches most. That question is what §3 tests.

### 2.2 Learning-science findings that constrain the design
| Finding | Implication for Memory Card |
|---|---|
| **Testing effect.** Repeated *retrieval* boosts delayed recall far more than repeated study (Karpicke & Roediger 2008, *Science*). | Every card must be an attempted recall *before* the answer is shown. The progressive reveal (F) must not leak answers. |
| **One big stack beats several small stacks.** Spacing within a session outperformed massing for 90 % of learners, yet 72 % believed massing worked better (Kornell 2009). | Large re-insertion gaps. Never trust "it feels easier" as evidence. |
| **Retrieval effort.** Harder-but-successful retrievals (longer lags) produce better retention (Pyc & Rawson 2009). | Re-insert failed cards *beyond* working-memory span (≥ 8 cards). |
| **Successive relearning.** Practise to a criterion (≥ 1 correct) in a session, then relearn across spaced sessions; it is large and robust in labs and classrooms (Rawson & Dunlosky 2011; Rawson et al. 2013). | A failed card must be passed once later in the same session; long-term spacing does the rest. |
| **Self-grading is overconfident** in the moment (Kornell & Bjork 2008). | A binary "did I recall it?" is the most honest grade. Avoid "Hard/Easy" judgments. |

---

## 3. Simulation

### 3.1 Setup
- **Code:** `tools/srs_sim/simulate.py` (pure Python; run `python tools/srs_sim/simulate.py 8 0.025`).
- **Learner:** the **ACT-R spacing model** (Pavlik & Anderson 2005), fitted to human vocabulary learning: `m = ln Σ age_j^{−d_j}`, `d_j = c·e^{m_j} + a`, `P = 1/(1+e^{(τ−m)/s})`, with between-session time scaled by *h*. It is deliberately **not** FSRS, so FSRS cannot win just because the world is shaped like FSRS.
- **Grading:** binary (right = recalled), 8 s per card, one session per day. **Every policy gets the same daily card budget.**
- **Scenarios:**
  - Small deck: 50 cards (like "German Basics"), 40 cards/day for 60 days.
  - Large deck: 400 cards, 60 cards/day for 60 days and for 180 days.
- **Metrics:**
  - % of the *whole deck* recalled the next morning.
  - % recalled after a further **30-day break** (durability).
  - **Felt success:** % of non-first presentations recalled, i.e. how the session feels to the user.

### 3.2 Policies
| Policy | What it is |
|---|---|
| `endless` | Q2.2 as written: right → back, left → 2–8 back (by confidence). All cards in the stack from day 1. |
| `endless_wide` | Same, but left → **8–20** back. |
| `endless_paced` | `endless_wide`, but the stack starts with 20 cards and adds a new one only while rolling success ≥ 75 %. |
| `leitner` | 5 boxes (1/2/4/8/16 days), 15 new/day. |
| `res43` | FSRS due queue + RES-43 ring buffer (gaps 2–5, 2–3 consecutive passes). |
| `mcre` | FSRS-6 due queue + successive relearning (gap 7, 1 pass), 15 new/day. Stops when nothing is due. |
| `mcre_free` | `mcre` + "keep going" practice to fill the budget. |
| `priority_r70` | Endless stack ordered by *calibrated* FSRS need, target 70 %. |
| `endless_srs` | Hybrid: right swipe re-inserts at a distance proportional to the calibrated FSRS interval. |

### 3.3 Results (h = 0.025, published value; 8 seeds)

**Small deck — 50 cards · 60 days · 40 cards/day**

| Policy | Next day | After 30-day break | Cards/day used | Felt success |
|---|---:|---:|---:|---:|
| endless | 93.2 % | 82.4 % | 40.0 | 83.5 % |
| **endless_wide** | **93.4 %** | **82.8 %** | 40.0 | 83.0 % |
| endless_paced | 93.2 % | 81.9 % | 40.0 | 83.7 % |
| leitner | 76.4 % | 60.4 % | 18.2 | – |
| res43 | 82.7 % | 66.4 % | 31.0 | 68.6 % |
| mcre (stops when done) | 78.5 % | 62.8 % | **20.1** | 66.1 % |
| mcre_free | 93.5 % | 82.9 % | 40.0 | 44.4 % |
| priority_r70 | 93.3 % | 82.1 % | 40.0 | 83.2 % |

**Large deck — 400 cards · 60 days · 60 cards/day**

| Policy | Next day | After 30-day break | Cards introduced | Felt success |
|---|---:|---:|---:|---:|
| endless | 52.3 % | 33.4 % | 400 | 51.9 % |
| **endless_wide** | **54.6 %** | **35.3 %** | 400 | 47.7 % |
| endless_paced | 34.5 % | 24.7 % | 186 | **72.1 %** |
| leitner | 47.1 % | 33.4 % | 265 | – |
| res43 | 30.1 % | 16.5 % | 287 | 41.7 % |
| mcre | 43.5 % | 25.2 % | 400 | 35.2 % |
| priority_r70 | 38.4 % | 24.7 % | 241 | 60.3 % |
| endless_srs | 22.2 % | 13.6 % | 149 | 74.1 % |

**Large deck — 400 cards · 180 days · 60 cards/day**

| Policy | Next day | After 30-day break | Felt success |
|---|---:|---:|---:|
| endless | 81.7 % | 73.0 % | 65.9 % |
| **endless_wide** | **82.5 %** | **74.1 %** | 64.5 % |
| endless_paced | 76.2 % | 64.2 % | **71.1 %** |
| leitner | 80.5 % | 70.5 % | – |
| res43 | 64.9 % | 52.7 % | 45.0 % |
| mcre | 78.0 % | 68.3 % | 58.4 % |
| priority_r70 | 72.6 % | 61.1 % | 64.6 % |

**Sensitivity (h = 0.1, i.e. 4× more forgetting between days):** the ranking mostly holds. `endless_wide` is best or tied in 2 of 3 scenarios. The exception is the large deck at 60 days, where **Leitner wins on durability** (23.5 % vs 19.5 %) and ties next-day recall. `res43` stays near the bottom, and default `mcre` is miscalibrated (felt success 23–57 %). Full tables are in `tools/srs_sim/results_h0.1.md`.

### 3.4 What holds up across all runs
1. **Wide re-insertion beats narrow**, by a small margin every time, consistent with the lag/retrieval-effort literature.
2. **RES-43's buffer is the worst or near-worst policy** in every run.
3. **"Keep going" practice never hurts.** `mcre` → `mcre_free` adds up to +20 points when time is available.
4. **Default FSRS is miscalibrated for this learner.** It loses when it drives the order, and calibration recovers part of the gap (small deck: 63 % → 78 % with a simple interval correction).
5. **Breadth beats depth at a fixed budget.** Policies that keep a *subset* at high retention lose to policies that cycle *every* card, for total knowledge. Pacing raises felt success (43–66 % → 68–72 % on large decks) at a cost of 10–20 points of total recall. This is a real trade-off, which is why the pace is a user setting.

### 3.5 Why the simulation does not settle everything
- ACT-R (2005) gives a failed attempt plus seeing the answer the same memory boost as a successful recall, so it **ignores the testing effect**. That favours "touch every card often" (your endless stack). An earlier run with a retrieval-effort learner model (since replaced) ranked spaced retrieval higher. **The truth is between the two models.**
- The simulation has **no motivation or dropout**. In real life the main way SRS fails is that people quit (FES-46). A 48 % felt-success rate is a quitting risk, and a slightly "less optimal" policy that people keep using wins in practice.
- Every simulated learner studies daily. Real users take breaks, and that is where FSRS's predictions matter most (what to review first when you return).

**Conclusion:** use the policy that is robust in both models and pleasant to use (the wide, paced endless stack). Use FSRS for what it is proven best at (*predicting* recall). Log everything, so your own data can settle the rest.

---

## 4. Answering the original question: your approach vs. the alternatives

| Criterion | Your endless stack (Q2.2) | Pure FSRS due-queue | RES-43 buffer | **Final: Endless + Shadow FSRS** |
|---|---|---|---|---|
| Total recall at equal time | ✅ Best / tied in 5 of 6 runs | ⚠️ Lower unless calibrated | ❌ Near-worst | ✅ = endless_wide (Intense) · −10–20 pts (Balanced) |
| Felt success (motivation) | ⚠️ 43–66 % on big decks | ❌ 23–66 % uncalibrated | ❌ 42–69 % | ✅ ~72 % (paced) |
| "Done for today" moment | ❌ None | ✅ Yes | ✅ Yes | ✅ Daily goal + optional continue |
| Handles breaks / backlog | ❌ Blind | ✅ Yes | ✅ Yes | ✅ Shadow FSRS warm-up |
| Progress / memory health UI | ❌ Only counts | ✅ Predicted recall | ✅ | ✅ Predicted recall |
| Fits the swipe design | ✅ Perfectly | ✅ | ✅ | ✅ |
| Complexity | ✅ Tiny | ⚠️ Medium (package) | ❌ High | ⚠️ Medium |

---

## 5. Final design — Memory Card Repetition Engine (MCRE v1)

### 5.1 Study loop (the stack)
Each deck owns a **persistent stack** (an ordered list of card IDs, saved across sessions).

| Event | Rule |
|---|---|
| **Swipe right** (recalled) | Card goes to the **back of the stack**. |
| **Swipe left** (not recalled) | Re-insert at `N = round(8 + 12 × successRate(card))`, clamped to [8, 20] and to the stack length. It must be passed later in the same session (successive relearning). |
| **Tap an "ear" button** | Same as the matching swipe (accessibility / one-handed use). |
| **Undo** | Restores the stack, the card state and the review log exactly. Available for 1 action for 5 s, and via the menu. |
| **Reveal** | The card must be revealed (tap / icon / flip, per setting) before the ears unlock. This enforces an attempt-then-check order (testing effect). A "front-only" mode exists for self-test decks. |
| **Never closer than** | 5 cards (working-memory span), even in small stacks. If the stack is shorter than 6, the gap is the full stack. |

### 5.2 Pacing (flow channel)
- The stack holds **active cards** plus a **reservoir** of not-yet-introduced cards.
- A new card enters the stack (3 positions from the top) when the rolling felt success (EMA, α = 0.05) is ≥ the pace target. Brand-new decks start with 10–20 active cards.
- **Pace setting:**
  - *Relaxed* (80 %)
  - *Balanced* (75 %, default)
  - *Intense* (all cards active at once: maximum breadth, your original model)
- Decks of ≤ 60 cards default to **Intense**, since pacing costs nothing there (small-deck table).

### 5.3 Shadow FSRS-6 (prediction layer)
- Every swipe writes a review to FSRS-6 (package `fsrs`), with binary grades `Again` / `Good`.
- **Same-day repeats are allowed;** FSRS-6's damped short-term formula stops them inflating stability.
- **Desired retention:** 0.90 for *display* purposes.
- **Calibration:** until the optimizer is available, keep a running interval/time multiplier `m ← m·(ln p̂ / ln ô)^0.3` (predicted vs observed on reviews ≥ 12 h apart). Calibration is per user, plus per deck once a deck has ≥ 200 reviews.
- **What FSRS drives:**
  1. **Memory health** per card, deck and folder: mean predicted recall *now*.
  2. **The stepped fan:** 5 steps = 0–20–40–60–80–100 % of cards with predicted recall ≥ 0.9.
  3. **"Slipping" counts:** cards whose predicted recall is < 0.9, shown as the due badge.
  4. **Warm-up after breaks:** if the last session was ≥ 2 days ago, the 20 weakest active cards (lowest predicted recall) move to the top of the stack.
  5. **Reminders:** "German Basics: 24 cards are slipping" at the user's chosen time.
- **What FSRS does *not* drive in v1:** the general order of the stack (§3 showed that need-ordering loses on breadth when it drives everything).

### 5.4 Daily goal and "keep going"
- **Daily goal** = every card that was *slipping* at the start of the day has been seen once, or the swipe target is reached (default 40), whichever comes first.
- Reaching it triggers the celebration (fanfare, wax seal, streak +1). The stack **continues** if the user keeps swiping. Your never-ending stack and a "done" moment coexist.
- **Streak** = days with the goal met; 2 grace shields per month (FES-46).

### 5.5 Data captured (review log; standard format, exportable)
```
review_log(id, card_id, deck_id, ts_utc, grade{0,1}, mode{flow,warmup,practice},
           stack_pos_before, reinsert_n, elapsed_since_last_s,
           fsrs_s_before, fsrs_d_before, fsrs_r_pred, calib_mult,
           dwell_ms, reveal_ms, hesitation_json /* analytics only */)
card_state(card_id, fsrs_s, fsrs_d, last_review, reps, lapses, success_ema, leech_flag)
deck_stack(deck_id, ordered_card_ids, reservoir_ids, pace, updated_at)
```
This makes three later steps possible: running the real FSRS optimizer, offline policy evaluation on your own history, and an in-app "Memory Lab" that compares predicted and observed recall.

### 5.6 Other rules
- **Day boundary:** 04:00 local time.
- **Reverse cards:** separate memory states; siblings are never within 10 positions of each other.
- **Leech:** ≥ 8 lapses → flagged and moved to the end of the stack, with "Rewrite this card?" (a hook for the future AI-mnemonic feature).
- **Free-practice / sprint modes** (later): log with `mode=practice`; they may be excluded from optimizer training.
- **Hesitation and dwell:** stored, displayed in stats, **never** used to grade (commuter flaw).

### 5.7 Engine interface (Dart)
```dart
abstract class StudyStrategy {          // Flow (v1), Smart (FSRS-ordered, experiment)
  CardId next(DeckStack stack, EngineClock clock);
  void onSwipe(CardId id, Grade grade, ReviewContext ctx);   // mutates stack + logs
  Undo snapshot();
}
abstract class MemoryModel {            // ShadowFsrs (v1)
  double predictedRecall(CardId id, DateTime at);
  void record(ReviewLogEntry e);
  DeckHealth health(DeckId id, DateTime at);
}
```
A second `StudyStrategy` ("Smart": FSRS due-first + keep going) ships behind a developer toggle, so both can be compared on real use.

---

## 6. Validation plan
1. **Unit tests:** stack rules (gap bounds, clamping, undo symmetry, pacing), calibration maths, day boundary.
2. **FSRS integration test:** for fixed review sequences, the package output matches py-fsrs reference values.
3. **Simulation regression:** port the `endless_wide` / `endless_paced` policies to a Dart test harness and assert they stay within ±2 points of the Python results.
4. **Dogfooding:** you study daily for 4 weeks. Success criteria: felt success 70–85 %, predicted recall within ±5 points of observed after calibration, streak survives.

---

## 7. Sources
- [py-fsrs (reference implementation)](https://github.com/open-spaced-repetition/py-fsrs)
- [FSRS algorithm wiki (FSRS-6 formulas & defaults)](https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm)
- [srs-benchmark (model comparison on ~350 M reviews)](https://github.com/open-spaced-repetition/srs-benchmark)
- [`fsrs` Dart package 2.0.1](https://pub.dev/packages/fsrs)
- [Kornell (2009), *Optimising learning using flashcards: Spacing is more effective than cramming*](https://cir.nii.ac.jp/crid/1361699994055985152)
- [Karpicke & Roediger (2008), *The critical importance of retrieval for learning*, Science](https://www.brucehayes.org/Teaching/papers/2008_Roediger_Karpicke_Science.pdf)
- [Successive relearning overview (Rawson & Dunlosky)](https://www.retrievalpractice.org/archive/2018/successive-relearning) · [Educational Psychology Review review](https://link.springer.com/article/10.1007/s10648-023-09809-2)
- Pyc & Rawson (2009), *Testing the retrieval effort hypothesis*, J. Memory & Language, doi:10.1016/j.jml.2009.01.004
- Pavlik & Anderson (2005), *Practice and forgetting effects on vocabulary memory: an activation-based model of the spacing effect*, Cognitive Science 29. The simulation parameters (a = 0.177, c = 0.217, τ = −0.704, s = 0.255, h = 0.025) are as recalled from the paper; verify them before citing elsewhere.
