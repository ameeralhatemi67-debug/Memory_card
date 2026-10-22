import 'dart:math' as math;

import '../data/app_data.dart';
import '../data/models.dart';
import 'assessor.dart';
import 'days.dart';
import 'fsrs.dart';
import 'seals.dart';
import 'stack_rules.dart';

/// How the current session is going, for the flow guard.
class SessionMood {
  const SessionMood({this.count = 0, this.last10 = 1, this.last15 = 1});
  final int count;
  final double last10;
  final double last15;

  static SessionMood of(List<bool> results) {
    double rate(int n) {
      final xs = results.length > n ? results.sublist(results.length - n) : results;
      if (xs.isEmpty) return 1;
      return xs.where((x) => x).length / xs.length;
    }

    return SessionMood(count: results.length, last10: rate(10), last15: rate(15));
  }
}

/// What one swipe did.
class SwipeOutcome {
  SwipeOutcome({
    required this.cardId,
    required this.assessment,
    required this.reinsertAt,
    required this.restLength,
    required this.introduced,
    required this.leechNow,
    required this.pausedNew,
    required this.goalNow,
    required this.seals,
    required this.log,
    required this.recallBefore,
    this.deckMastered = false,
  });

  final String cardId;
  final Assessment assessment;

  /// Index in the remaining stack where the card went (== restLength: the very end).
  final int reinsertAt;
  final int restLength;
  final List<String> introduced;
  final bool leechNow;
  final bool pausedNew;
  final bool goalNow;
  final List<String> seals;
  final ReviewLog log;
  final double? recallBefore;

  /// This swipe made every card of the deck strong for the first time.
  final bool deckMastered;

  bool get toEnd => reinsertAt >= restLength;
  int get grade => assessment.grade;
}

/// Deck numbers shown everywhere (all from the shadow FSRS model).
class DeckStats {
  const DeckStats({
    required this.total,
    required this.active,
    required this.waiting,
    required this.fresh,
    required this.slipping,
    required this.strong,
    required this.mastered,
    required this.leeches,
    required this.tomorrow,
    required this.health,
    required this.steps,
  });

  final int total;
  final int active;
  final int waiting;
  final int fresh;
  final int slipping;
  final int strong;
  final int mastered;
  final int leeches;

  /// Strong today, slipping by tomorrow.
  final int tomorrow;

  /// Mean predicted recall of reviewed cards (null if none).
  final double? health;

  /// The stepped fan: 0–5 steps, one per 20 % of cards with predicted recall ≥ 90 %.
  final int steps;
}

/// The Memory Card Repetition Engine (MCRE v2): the endless stack + shadow FSRS-6 + reading how you answer.
/// See docs/research/RES-48_Engine_v2.md.
class StudyEngine {
  StudyEngine(this.data);

  final AppData data;
  final Assessor assessor = const Assessor();
  Fsrs? _fsrs;

  Fsrs get fsrs => _fsrs ??= Fsrs(data.engine.weights);
  void weightsChanged() => _fsrs = null;

  double get _m => data.engine.calibration.multiplier;

  // ---------- predictions ----------

  /// Calibrated probability that you recall [c] at [now]; null for a card never reviewed.
  double? recall(CardItem c, int now) {
    final s = c.s, last = c.last;
    if (s == null || last == null) return null;
    return fsrs.retrievability(math.max(0, now - last) / msPerDay * _m, s);
  }

  /// When predicted recall will fall below [threshold] (ms since epoch).
  int? slipsAt(CardItem c, {double threshold = 0.9}) {
    final s = c.s, last = c.last;
    if (s == null || last == null) return null;
    return last + (fsrs.daysUntil(s, threshold) / _m * msPerDay).round();
  }

  bool isMastered(CardItem c) => (c.s ?? 0) >= 21;

  /// The deck's pace: its own override, else the setting.
  String effectivePace(Deck d) => d.pace ?? data.settings.pace.name;

  /// Mastered cards with very high recall skip their turn (they would gain almost nothing).
  bool isResting(CardItem c, int now) =>
      data.settings.restMastered && !c.leech && (c.s ?? 0) >= 30 && (recall(c, now) ?? 0) >= 0.97;

  DeckStats deckStats(Deck d, int now) {
    var fresh = 0, slipping = 0, strong = 0, mastered = 0, leeches = 0, tomorrow = 0, reviewed = 0;
    var sumR = 0.0;
    var total = 0;
    for (final c in data.cardsOf(d)) {
      if (c.suspended) continue;
      total++;
      if (c.leech) leeches++;
      if (isMastered(c)) mastered++;
      final r = recall(c, now);
      if (r == null) {
        fresh++;
        continue;
      }
      reviewed++;
      sumR += r;
      if (r < 0.9) {
        slipping++;
      } else {
        strong++;
        if ((recall(c, now + msPerDay) ?? 1) < 0.9) tomorrow++;
      }
    }
    return DeckStats(
      total: total,
      active: d.stack.length,
      waiting: d.reservoir.length,
      fresh: fresh,
      slipping: slipping,
      strong: strong,
      mastered: mastered,
      leeches: leeches,
      tomorrow: tomorrow,
      health: reviewed == 0 ? null : sumR / reviewed,
      steps: total == 0 ? 0 : math.min(5, (5 * strong / total + 1e-9).floor()),
    );
  }

  List<String> slippingIds(int now) => [
        for (final d in data.activeDecks)
          for (final c in data.cardsOf(d))
            if (!c.suspended && (recall(c, now) ?? 1) < 0.9) c.id,
      ];

  // ---------- the day, the goal and the streak (RES-47 §5.4, FES-46) ----------

  /// Starts a new study day if the clock passed 04:00. Missed days use grace shields (2 a month) or
  /// break the streak. Returns true when a new day began.
  bool ensureToday(int now) {
    final day = dayNumber(now);
    final t = data.today;
    if (t != null && t.day == day) return false;
    final p = data.profile;
    final month = dayKey(day).substring(0, 7);
    if (p.shieldMonth != month) {
      p.shieldMonth = month;
      p.shields = 2;
    }
    p.lastEvents = [];
    if (p.streak > 0) {
      var last = p.lastGoalDay;
      for (var d = last + 1; d < day; d++) {
        if (p.shields > 0) {
          p.shields--;
          p.lastEvents.add('shield');
          last = d;
        } else {
          p.streak = 0;
          p.lastEvents.add('broken');
          break;
        }
      }
      if (p.streak > 0) p.lastGoalDay = last;
    }
    data.today = Today(day: day, startedAt: now, slipStart: slippingIds(now));
    return true;
  }

  /// The goal: the daily swipe target, or every card that was slipping at 04:00 seen once
  /// (with a floor of min(goal, 10) swipes), whichever comes first.
  bool goalReached() {
    final t = data.today!;
    final goal = data.settings.goal;
    if (t.done >= goal) return true;
    if (t.slipStart.isEmpty) return false;
    if (t.done < math.min(goal, 10)) return false;
    return t.slipStart.every((id) => !data.cards.containsKey(id) || t.seen.contains(id));
  }

  int slipLeft() {
    final t = data.today!;
    return t.slipStart.where((id) => data.cards.containsKey(id) && !t.seen.contains(id)).length;
  }

  int liveStreak() {
    final t = data.today;
    final p = data.profile;
    if (t == null) return p.streak;
    return (t.day - p.lastGoalDay <= 1 || t.goalHit) ? p.streak : 0;
  }

  // ---------- the study loop ----------

  /// Before showing a deck: fill an empty stack from the reservoir and warm up after a break of 2+ days.
  /// Returns how many cards the warm-up moved to the top.
  int prepareDeck(Deck d, int now) {
    _dropMissing(d);
    if (effectivePace(d) == 'intense' && d.reservoir.isNotEmpty) {
      d.stack = [...d.stack, ...d.reservoir];
      d.reservoir = [];
    }
    if (d.stack.isEmpty && d.reservoir.isNotEmpty) {
      final k = math.min(15, d.reservoir.length);
      d.stack = d.reservoir.sublist(0, k);
      d.reservoir = d.reservoir.sublist(k);
    }
    var warm = 0;
    if (d.lastStudied > 0 && elapsedStudyDays(d.lastStudied, now) >= 2) {
      final (stack, moved) = StackRules.warmUp(
        d.stack,
        (id) {
          final c = data.cards[id];
          return c == null ? null : recall(c, now);
        },
        siblingOf: (id) => data.cards[id]?.siblingId,
      );
      d.stack = stack;
      warm = moved;
      d.lastStudied = now;
    }
    return warm;
  }

  /// The card on top, after letting mastered cards rest (moved to the back, not counted).
  String? topCard(Deck d, int now) {
    _dropMissing(d);
    if (d.stack.isEmpty) return null;
    var guard = d.stack.length;
    while (guard-- > 0) {
      final id = d.stack.first;
      final c = data.cards[id];
      if (c == null || c.suspended) {
        d.stack = d.stack.sublist(1);
        if (d.stack.isEmpty) return null;
        continue;
      }
      if (!isResting(c, now)) return id;
      d.stack = [...d.stack.sublist(1), id];
    }
    // Everything is resting: show them anyway.
    return d.stack.first;
  }

  /// The card that will come after the top one (for the card peeking out underneath).
  String? peekNext(Deck d, int now) {
    for (var i = 1; i < d.stack.length; i++) {
      final c = data.cards[d.stack[i]];
      if (c == null || c.suspended) continue;
      if (!isResting(c, now)) return c.id;
    }
    return null;
  }

  void _dropMissing(Deck d) {
    if (d.stack.any((id) => data.cards[id] == null)) d.stack = d.stack.where((id) => data.cards[id] != null).toList();
    if (d.reservoir.any((id) => data.cards[id] == null)) {
      d.reservoir = d.reservoir.where((id) => data.cards[id] != null).toList();
    }
  }

  /// Applies one swipe: reads the answer, updates FSRS, moves the card in the stack, paces new cards,
  /// counts the goal and the streak, and writes the review log.
  SwipeOutcome swipe(
    Deck d,
    String cardId, {
    required bool recalled,
    required ReviewSignals signals,
    required int now,
    String mode = 'flow',
    int? forcedGrade,
    SessionMood mood = const SessionMood(),
  }) {
    ensureToday(now);
    final c = data.cards[cardId]!;
    final eng = data.engine;
    final firstExposure = c.reps == 0;
    final rBefore = recall(c, now);
    final sBefore = c.s, dBefore = c.d;
    final elapsed = c.last == null ? null : elapsedStudyDays(c.last!, now);

    var a = assessor.assess(
      recalled: recalled,
      s: signals,
      baselines: eng.baselines,
      tuner: eng.tuner,
      deckId: d.id,
      firstExposure: firstExposure,
      smartGrading: data.settings.smartGrading,
    );
    if (forcedGrade != null && forcedGrade != a.grade) a = a.withGrade(forcedGrade);
    final grade = a.grade;
    final ok = grade > 1;

    // Learn about you from reviews at least a day apart.
    if (elapsed != null && elapsed >= 1 && sBefore != null) {
      final days = (now - c.last!) / msPerDay;
      eng.calibration.observe(days, sBefore, ok, fsrs);
      final prev = c.lastGrade;
      if (prev != null && prev >= 2 && rBefore != null) eng.tuner.observe(prev, ok, rBefore);
    }
    if (ok && a.latencyTrusted && !signals.viaButton) {
      eng.baselines.observeCorrect(
        thinkMs: signals.thinkMs,
        chars: signals.promptChars,
        deckId: d.id,
        verifyMs: signals.verifyMs,
      );
    }

    // FSRS-6 shadow update.
    final next = fsrs.review(sBefore == null ? null : MemoryState(sBefore, dBefore ?? 5), grade, elapsedDays: elapsed);
    c
      ..s = next.stability
      ..d = next.difficulty
      ..last = now
      ..reps = c.reps + 1
      ..lastGrade = grade
      ..lastConfidence = a.confidence
      ..firstSeen = c.firstSeen ?? now;
    if (ok) {
      c.succ++;
    } else {
      c.lapses++;
    }
    c.pushEvent(now, grade, signals.thinkMs);

    // Stack placement.
    final rest = d.stack.where((id) => id != cardId).toList();
    var leechNow = false;
    int pos;
    if (ok) {
      pos = grade == 2 ? StackRules.hardGap(rest.length) : rest.length;
    } else if (c.lapses >= 8 && !c.leech) {
      c.leech = true;
      leechNow = true;
      pos = rest.length;
    } else {
      pos = StackRules.failGap(
        successRate: c.successRate,
        stabilityBefore: sBefore,
        lapses: c.lapses,
        kind: a.kind,
        restLength: rest.length,
      );
    }
    pos = StackRules.awayFromSibling(rest, pos, c.siblingId);
    d.stack = StackRules.insertAt(rest, cardId, pos);

    // Pacing with a flow guard (RES-47 §5.2 + FES-46 flow channel).
    d.ema = d.ema + 0.05 * ((ok ? 1 : 0) - d.ema);
    final introduced = <String>[];
    var pausedNew = false;
    final paceName = effectivePace(d);
    if (d.reservoir.isNotEmpty) {
      final target = switch (paceName) { 'relaxed' => 0.80, 'intense' => 0.0, _ => 0.75 };
      final struggling = mood.count >= 10 && mood.last10 < 0.5;
      if (paceName == 'intense') {
        introduced.addAll(d.reservoir);
        d.reservoir = [];
      } else if (struggling) {
        pausedNew = true;
      } else if (d.ema >= target) {
        final flying = mood.count >= 15 && mood.last15 >= 0.93 && d.ema >= target + 0.08;
        final k = math.min(flying ? 2 : 1, d.reservoir.length);
        introduced.addAll(d.reservoir.sublist(0, k));
        d.reservoir = d.reservoir.sublist(k);
      }
      if (introduced.isNotEmpty) {
        final stack = [...d.stack];
        var at = math.min(3, stack.length);
        for (final id in introduced) {
          stack.insert(math.min(at, stack.length), id);
          at += paceName == 'intense' ? 0 : 1;
        }
        d.stack = stack;
      }
    }
    d.lastStudied = now;
    d.reviews++;

    // The day.
    final t = data.today!;
    final spent = math.min(60000, signals.thinkMs + (signals.verifyMs ?? 0) + signals.dragMs);
    t.done++;
    if (ok) {
      t.ok++;
      t.run++;
      t.bestRun = math.max(t.bestRun, t.run);
    } else {
      t.fail++;
      t.run = 0;
    }
    if (grade == 4) t.easy++;
    if (grade == 2) t.hard++;
    if (firstExposure) t.newSeen++;
    t.seen.add(cardId);
    t.decks[d.id] = (t.decks[d.id] ?? 0) + 1;
    t.ms += spent;
    t.lastDeck = d.id;
    final p = data.profile;
    p.totalReviews++;
    p.totalMs += spent;
    final rec = p.history.putIfAbsent(t.day, DayRecord.new);
    rec.swipes++;
    if (ok) rec.ok++;
    rec.ms += spent;

    var goalNow = false;
    var comeback = false;
    if (!t.goalHit && goalReached()) {
      t.goalHit = true;
      goalNow = true;
      final gap = t.day - p.lastGoalDay;
      comeback = gap >= 8 && p.totalReviews > 50;
      p.streak = gap == 1 ? p.streak + 1 : (gap == 0 ? p.streak : 1);
      p.bestStreak = math.max(p.bestStreak, p.streak);
      p.lastGoalDay = t.day;
      rec.goal = true;
    }

    final seals = Seals.check(data, this, now, goalNow: goalNow, comeback: comeback);

    // A deck is mastered the first time every card stands above 90 % recall (all five fan steps).
    var deckMastered = false;
    if (ok && d.masteredAt == null && d.cardIds.length >= 5) {
      final st = deckStats(d, now);
      if (st.total >= 5 && st.steps == 5) {
        d.masteredAt = now;
        deckMastered = true;
      }
    }

    final log = ReviewLog(
      ts: now,
      cardId: cardId,
      deckId: d.id,
      grade: grade,
      mode: mode,
      elapsedDays: elapsed ?? -1,
      rPred: rBefore,
      sBefore: sBefore,
      dBefore: dBefore,
      sAfter: next.stability,
      dAfter: next.difficulty,
      signals: signals.toJson(),
      confidence: a.confidence,
      automatic: a.automatic,
      reinsertAt: pos >= rest.length ? null : pos,
    );

    return SwipeOutcome(
      cardId: cardId,
      assessment: a,
      reinsertAt: pos,
      restLength: rest.length,
      introduced: introduced,
      leechNow: leechNow,
      pausedNew: pausedNew,
      goalNow: goalNow,
      seals: seals,
      log: log,
      recallBefore: rBefore,
      deckMastered: deckMastered,
    );
  }
}
