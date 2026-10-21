"""
Memory Card — repetition-policy simulator (RES-47 companion).

Compares study policies on a simulated learner whose memory model is
deliberately NOT FSRS (to avoid a circular "FSRS wins because the world is FSRS"
result). The learner is the ACT-R spacing model of Pavlik & Anderson (2005),
fitted to human paired-associate (vocabulary) learning data:

  activation   m(t) = ln( sum_j age_j ** -d_j ) + beta_item
  decay        d_j  = c * exp(m at presentation j) + a      (spacing effect)
  recall       P    = 1 / (1 + exp((tau - m) / s))
  time between sessions is scaled by h (psychological time).

It reproduces fast within-minutes forgetting of new items, the spacing and lag
effects, and slower forgetting of well-spaced items.

Policies (all graded binary: swipe right = recalled, left = not):
  endless   - Q2.2: never-ending stack, right -> back, left -> N back (2..8, by confidence)
  leitner   - 5 boxes (1,2,4,8,16 days), fail -> box 1, in-session repeat at end
  res43     - FSRS-6 due queue + RES-43 ring buffer (gap 2..5, 2 consecutive passes)
  mcre      - FSRS-6 due queue + successive relearning (gap >= 7, 1 pass after fail)
  mcre_free - mcre, then fills the remaining time budget with "Keep going" practice

Run:  python tools/srs_sim/simulate.py
"""
import math
import random
import statistics
import sys

# ---------------------------------------------------------------- learner model
SEC_PER_CARD = 8.0      # average seconds per presentation
ACT_A, ACT_C = 0.177, 0.217          # decay intercept / scale  (Pavlik & Anderson 2005)
ACT_TAU, ACT_S = -0.704, 0.255       # retrieval threshold / noise
ACT_H = 0.025                        # between-session time scaling
BETA_SD = 0.25                       # item difficulty spread


def psych_seconds(t):
    """Real time t (days; sessions start at day + 0.8) -> psychological seconds."""
    day = math.floor(t)
    return day * 86400.0 * ACT_H + max(0.0, t - day - 0.8) * 86400.0


class Item:
    __slots__ = ("beta", "traces")

    def __init__(self, rng):
        self.beta = rng.gauss(0.0, BETA_SD)
        self.traces = []  # (psych_time, decay)

    def _m(self, now):
        total = 0.0
        for t, d in self.traces:
            total += max(now - t, 1.0) ** -d
        return math.log(total) if total > 0 else -math.inf

    def p_recall(self, now):
        m = self._m(now)
        if m == -math.inf:
            return 0.0
        return 1.0 / (1.0 + math.exp((ACT_TAU - (m + self.beta)) / ACT_S))

    def r_lt(self, t):
        return self.p_recall(psych_seconds(t))

    def present(self, t, rng):
        """Show the card at real time t (days); answer is always seen afterwards."""
        now = psych_seconds(t)
        ok = rng.random() < self.p_recall(now)
        m = self._m(now)
        d = ACT_A if m == -math.inf else ACT_C * math.exp(m) + ACT_A
        self.traces.append((now, d))
        return ok


# ---------------------------------------------------------------- FSRS-6 (py-fsrs formulas)
W = [0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666,
     0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542]
DECAY = -W[20]
FACTOR = 0.9 ** (1.0 / DECAY) - 1.0
AGAIN, GOOD = 1, 3


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def d0(g):
    return clamp(W[4] - math.exp(W[5] * (g - 1)) + 1.0, 1.0, 10.0)


class Fsrs:
    __slots__ = ("S", "D", "last", "due")

    def __init__(self):
        self.S = None
        self.D = None
        self.last = None
        self.due = None

    def retrievability(self, t):
        if self.S is None:
            return 0.0
        return (1.0 + FACTOR * (t - self.last) / self.S) ** DECAY

    def review(self, g, t, retention=0.9, mult=1.0):
        if self.S is None:
            self.S = max(W[g - 1], 0.001)
            self.D = d0(g)
        else:
            elapsed = t - self.last
            r = self.retrievability(t)
            # difficulty: linear damping + mean reversion to D0(Easy)
            delta = -W[6] * (g - 3)
            dd = self.D + delta * (10.0 - self.D) / 9.0
            self.D = clamp(W[7] * d0(4) + (1.0 - W[7]) * dd, 1.0, 10.0)
            if elapsed < 1.0:  # same-day
                inc = math.exp(W[17] * (g - 3 + W[18])) * self.S ** -W[19]
                if g >= 2:
                    inc = max(inc, 1.0)
                self.S = self.S * inc
            elif g == AGAIN:
                long_term = (W[11] * self.D ** -W[12] * ((self.S + 1) ** W[13] - 1)
                             * math.exp((1 - r) * W[14]))
                short_term = self.S / math.exp(W[17] * W[18])
                self.S = min(long_term, short_term)
            else:
                self.S = self.S * (1 + math.exp(W[8]) * (11 - self.D) * self.S ** -W[9]
                                   * (math.exp((1 - r) * W[10]) - 1))
        self.S = clamp(self.S, 0.001, 36500.0)
        self.last = t
        ivl = self.S / FACTOR * (retention ** (1.0 / DECAY) - 1.0)
        self.due = t + (max(1, round(ivl * mult)) if g == GOOD else 1)


# ---------------------------------------------------------------- policies
def run_session_queue(queue, items, t, budget, rng, gap_fn, passes_needed, on_first, on_extra):
    """Generic in-session loop with re-insertion. queue: list of card ids."""
    used = 0
    state = {}  # id -> [consecutive_passes, lapses_this_session, answered_today]
    q = list(queue)
    while q and used < budget:
        cid = q.pop(0)
        ok = items[cid].present(t, rng)
        used += 1
        t += SEC_PER_CARD / 86400.0
        st = state.setdefault(cid, [0, 0, False])
        if not st[2]:
            on_first(cid, ok, t)
            st[2] = True
        else:
            on_extra(cid, ok, t)
        if ok:
            st[0] += 1
            if st[0] >= passes_needed(st[1]):
                continue  # leaves the session
            q.insert(min(len(q), gap_fn(st, cid)), cid)
        else:
            st[0] = 0
            st[1] += 1
            q.insert(min(len(q), gap_fn(st, cid)), cid)
    return used, t, state


def policy_endless(items, days, budget, rng, lo=2, hi=8, paced=False, target=0.75):
    """Q2.2 endless stack. paced=True starts with 20 cards and adds a new card to
    the stack only while the rolling success rate is >= target (flow channel)."""
    n = len(items)
    stack = list(range(20 if paced else n))
    nxt = len(stack)
    stats = {i: [0, 0] for i in range(n)}  # successes, attempts
    ema = target
    DIAG.setdefault("rev", [0, 0])
    for day in range(days):
        t = day + 0.8
        for _ in range(budget):
            cid = stack.pop(0)
            ok = items[cid].present(t, rng)
            t += SEC_PER_CARD / 86400.0
            s = stats[cid]
            if s[1] > 0:  # success rate the user feels (excludes first sight)
                DIAG["rev"][0] += ok
                DIAG["rev"][1] += 1
                ema += 0.05 * (ok - ema)
            s[1] += 1
            s[0] += ok
            if ok:
                stack.append(cid)
            else:
                conf = s[0] / s[1]
                stack.insert(min(len(stack), int(round(lo + (hi - lo) * conf))), cid)
            if paced and nxt < n and ema >= target:
                stack.insert(min(len(stack), 3), nxt)
                nxt += 1
                ema -= 0.05


def policy_leitner(items, days, budget, rng, new_per_day=15):
    box = {}
    due = {}
    ivl = [1, 2, 4, 8, 16]
    unseen = list(range(len(items)))
    for day in range(days):
        t = day + 0.8
        q = [c for c in box if due[c] <= day]
        q.sort(key=lambda c: due[c])
        n_new = 0
        while unseen and n_new < new_per_day and len(q) < budget:
            c = unseen.pop(0)
            box[c] = 0
            due[c] = day
            q.append(c)
            n_new += 1

        def first(c, ok, _t):
            box[c] = min(box[c] + 1, 4) if ok else 0
            due[c] = day + ivl[box[c]]

        run_session_queue(q, items, t, budget, rng,
                          gap_fn=lambda st, c: 10 ** 6,   # end of queue
                          passes_needed=lambda lapses: 1,
                          on_first=first, on_extra=lambda c, ok, _t: None)


DIAG = {}


def fsrs_policy(items, days, budget, rng, gap_fn, passes_needed, free_practice,
                new_per_day=15, retention=0.9, calibrate=False, adaptive_new=False,
                salvage_first=False):
    cards = {}
    backlog_yesterday = False
    cal = {"ema": retention, "n": 0, "mult": 1.0}
    DIAG.setdefault("rev", [0, 0])
    unseen = list(range(len(items)))
    for day in range(days):
        t0 = day + 0.8
        due = [c for c, f in cards.items() if f.due <= t0]
        due.sort(key=lambda c: cards[c].retrievability(t0), reverse=salvage_first)
        if adaptive_new:  # flow-channel intake: no new cards while behind or struggling
            health = clamp((cal["ema"] - 0.65) / 0.2, 0.0, 1.0)
            new_limit = 0 if backlog_yesterday else round(new_per_day * health)
            if cal["n"] < 30:
                new_limit = new_per_day
        else:
            new_limit = new_per_day
        # interleave up to new_per_day new cards: 1 new after every 3 reviews
        q, n_new, i = [], 0, 0
        while i < len(due) or (unseen and n_new < new_limit):
            for _ in range(3):
                if i < len(due):
                    q.append(due[i])
                    i += 1
            if unseen and n_new < new_limit and len(q) < budget:
                c = unseen.pop(0)
                cards[c] = Fsrs()
                q.append(c)
                n_new += 1
            elif i >= len(due):
                break

        def first(c, ok, t):
            if cards[c].S is not None:
                DIAG["rev"][0] += ok
                DIAG["rev"][1] += 1
                cal["ema"] += 0.03 * (ok - cal["ema"])
                cal["n"] += 1
            cards[c].review(GOOD if ok else AGAIN, t, retention, cal["mult"])

        def extra(c, ok, t):  # same-day learning steps -> FSRS short-term update
            cards[c].review(GOOD if ok else AGAIN, t, retention, cal["mult"])

        used, t, state = run_session_queue(q, items, t0, budget, rng, gap_fn, passes_needed,
                                           first, extra)
        backlog_yesterday = any(cards[c].due <= t0 for c in due if c not in state)
        if calibrate and cal["n"] >= 30:  # Anki-style interval correction, damped
            obs = clamp(cal["ema"], 0.3, 0.98)
            step = (math.log(retention) / math.log(obs)) ** 0.3
            cal["mult"] = clamp(cal["mult"] * step, 0.05, 3.0)
        for c in [c for c, f in cards.items() if f.S is None]:  # queued but never shown
            del cards[c]
            unseen.insert(0, c)
        if free_practice and used < budget:
            reviewed = set(state)
            pool = [c for c in cards if c not in reviewed and cards[c].S is not None]
            pool.sort(key=lambda c: cards[c].retrievability(t))
            for c in pool[: budget - used]:
                ok = items[c].present(t, rng)
                t += SEC_PER_CARD / 86400.0
                cards[c].review(GOOD if ok else AGAIN, t, retention, cal["mult"])  # early review


def policy_endless_srs(items, days, budget, rng, gap=7, retention=0.9):
    """Hybrid: the Q2.2 endless stack, but a right swipe re-inserts the card at a
    distance (in swipes) proportional to its calibrated FSRS interval, capped at
    the end of the stack. Small decks -> identical to the endless loop; large
    decks -> weak cards return sooner, strong cards later."""
    stack = list(range(len(items)))
    cards = {}
    mult = 1.0
    DIAG.setdefault("rev", [0, 0])
    for day in range(days):
        t = day + 0.8
        pred_sum = obs_sum = 0.0
        n = 0
        for _ in range(budget):
            c = stack.pop(0)
            f = cards.setdefault(c, Fsrs())
            if f.S is not None and t - f.last >= 0.5:
                pred = (1.0 + FACTOR * (t - f.last) / (f.S * mult)) ** DECAY
            else:
                pred = None
            ok = items[c].present(t, rng)
            if pred is not None:
                pred_sum += pred
                obs_sum += ok
                n += 1
                DIAG["rev"][0] += ok
                DIAG["rev"][1] += 1
            f.review(GOOD if ok else AGAIN, t, retention)
            if ok:
                ivl = f.S * mult / FACTOR * (retention ** (1.0 / DECAY) - 1.0)
                pos = max(gap, int(ivl * budget))
            else:
                pos = gap
            stack.insert(min(len(stack), pos), c)
            t += SEC_PER_CARD / 86400.0
        if n >= 10:
            p_hat = clamp(pred_sum / n, 0.3, 0.99)
            o_hat = clamp(obs_sum / n, 0.3, 0.99)
            mult = clamp(mult * (math.log(p_hat) / math.log(o_hat)) ** 0.3, 0.05, 3.0)


def policy_priority(items, days, budget, rng, retention=0.9, gap=7):
    """Synthesis: endless stack ordered by calibrated FSRS need.

    Every swipe pulls the next card from one stack:
      1. a relearning card whose re-insertion gap has elapsed, else
      2. the learned card with the lowest calibrated predicted recall, if it is
         below the target (it "needs" review), else
      3. a brand-new card (intake is paced by capacity, not a fixed daily cap), else
      4. the weakest learned card anyway ("keep going" / learn-ahead).
    At most one scheduling review per card per day; relearning repeats use the
    FSRS same-day update. Calibration scales FSRS time so predicted ~ observed.
    """
    cards = {}
    unseen = list(range(len(items)))
    mult = 1.0
    DIAG.setdefault("rev", [0, 0])
    for day in range(days):
        t = day + 0.8
        reviewed_today = set()
        relearn = []  # [cards_until_due, cid]
        pred_sum = obs_sum = 0.0
        n_sched = 0

        def r_cal(c, now):
            f = cards[c]
            return (1.0 + FACTOR * (now - f.last) / (f.S * mult)) ** DECAY

        for _ in range(budget):
            for r in relearn:
                r[0] -= 1
            ready = [r for r in relearn if r[0] <= 0]
            if ready:
                relearn.remove(ready[0])
                c = ready[0][1]
                ok = items[c].present(t, rng)
                cards[c].review(GOOD if ok else AGAIN, t, retention)
                if not ok:
                    relearn.append([gap, c])
            else:
                pool = [c for c in cards if c not in reviewed_today]
                c = min(pool, key=lambda k: r_cal(k, t)) if pool else None
                if c is not None and r_cal(c, t) < retention:
                    pass
                elif unseen:
                    c = unseen.pop(0)
                    cards[c] = Fsrs()
                if c is None:
                    break
                is_sched = cards[c].S is not None
                if is_sched:
                    pred = r_cal(c, t)
                ok = items[c].present(t, rng)
                if is_sched:
                    pred_sum += pred
                    obs_sum += ok
                    n_sched += 1
                    DIAG["rev"][0] += ok
                    DIAG["rev"][1] += 1
                cards[c].review(GOOD if ok else AGAIN, t, retention)
                reviewed_today.add(c)
                if not ok:
                    relearn.append([gap, c])
            t += SEC_PER_CARD / 86400.0
        if n_sched >= 10:  # calibrate FSRS time scale toward observed recall
            p_hat = clamp(pred_sum / n_sched, 0.3, 0.99)
            o_hat = clamp(obs_sum / n_sched, 0.3, 0.99)
            mult = clamp(mult * (math.log(p_hat) / math.log(o_hat)) ** 0.3, 0.05, 3.0)


def gap_res43(st, cid):
    return 4 if st[0] > 0 else max(2, min(5, round(3 / (1 + 0.5 * (st[1] - 1)))))


def gap_mcre(st, cid):
    return 7 if st[1] <= 1 else 5


POLICIES = {
    "endless": lambda it, d, b, r: policy_endless(it, d, b, r),
    "endless_wide": lambda it, d, b, r: policy_endless(it, d, b, r, lo=8, hi=20),
    "endless_paced": lambda it, d, b, r: policy_endless(it, d, b, r, lo=8, hi=20, paced=True),
    "leitner": lambda it, d, b, r: policy_leitner(it, d, b, r),
    "res43": lambda it, d, b, r: fsrs_policy(it, d, b, r, gap_res43,
                                             lambda lapses: 2 if lapses <= 1 else 3, False),
    "mcre": lambda it, d, b, r: fsrs_policy(it, d, b, r, gap_mcre, lambda lapses: 1, False),
    "mcre_free": lambda it, d, b, r: fsrs_policy(it, d, b, r, gap_mcre, lambda lapses: 1, True),
    "endless_srs": lambda it, d, b, r: policy_endless_srs(it, d, b, r),
    "endless_srs_r70": lambda it, d, b, r: policy_endless_srs(it, d, b, r, retention=0.7),
    "priority": lambda it, d, b, r: policy_priority(it, d, b, r),
    "priority_r80": lambda it, d, b, r: policy_priority(it, d, b, r, retention=0.8),
    "priority_r70": lambda it, d, b, r: policy_priority(it, d, b, r, retention=0.7),
    "priority_r60": lambda it, d, b, r: policy_priority(it, d, b, r, retention=0.6),
    "mcre_core": lambda it, d, b, r: fsrs_policy(it, d, b, r, gap_mcre, lambda lapses: 1, False,
                                                 calibrate=True, adaptive_new=True,
                                                 salvage_first=True),
    "mcre_full": lambda it, d, b, r: fsrs_policy(it, d, b, r, gap_mcre, lambda lapses: 1, True,
                                                 calibrate=True, adaptive_new=True,
                                                 salvage_first=True),
}


class Counter:
    """Wraps Item.present to count presentations."""

    def __init__(self):
        self.n = 0


def evaluate(policy, n_items, days, budget, seed):
    rng = random.Random(seed)
    items = [Item(rng) for _ in range(n_items)]
    counter = Counter()
    orig = Item.present

    def counted(self, t, r):
        counter.n += 1
        return orig(self, t, r)

    Item.present = counted
    try:
        POLICIES[policy](items, days, budget, rng)
    finally:
        Item.present = orig
    seen = sum(1 for it in items if it.traces)
    exam_now = statistics.mean(it.r_lt(days + 0.5) for it in items)        # next morning
    exam_later = statistics.mean(it.r_lt(days + 30.5) for it in items)     # 30 days, no study
    return exam_now, exam_later, counter.n / days, seen


def main():
    global ACT_H
    seeds = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    if len(sys.argv) > 2:
        ACT_H = float(sys.argv[2])
    scenarios = [
        ("Small deck (50 cards, like 'German Basics')", 50, 60, 40),
        ("Large deck (400 cards)", 400, 60, 60),
        ("Large deck, long horizon (400 cards)", 400, 180, 60),
    ]
    only = sys.argv[3] if len(sys.argv) > 3 else None
    if only:
        scenarios = [sc for sc in scenarios if only in sc[0]]
    print(f"seeds={seeds}  learner=ACT-R spacing model (Pavlik & Anderson 2005)\n")
    for title, n, days, budget in scenarios:
        print(f"### {title} - {days} days, budget {budget} cards/day\n")
        print("| Policy | Recall next day | Recall after 30-day break | Cards/day used | Cards introduced | Scheduled-review success |")
        print("|---|---:|---:|---:|---:|---:|")
        for p in POLICIES:
            DIAG.clear()
            res = [evaluate(p, n, days, budget, s) for s in range(seeds)]
            rv = DIAG.get("rev")
            succ = f"{rv[0] / rv[1]:.1%}" if rv and rv[1] else "-"
            now = statistics.mean(r[0] for r in res)
            later = statistics.mean(r[1] for r in res)
            per_day = statistics.mean(r[2] for r in res)
            seen = statistics.mean(r[3] for r in res)
            print(f"| {p} | {now:.1%} | {later:.1%} | {per_day:.1f} | {seen:.0f} | {succ} |")
        print()


if __name__ == "__main__":
    main()
