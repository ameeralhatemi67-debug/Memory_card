import 'dart:math' as math;

import 'days.dart';
import 'fsrs.dart';

/// One review in a card's history, for training.
class TrainReview {
  const TrainReview(this.cardId, this.ts, this.grade);
  final String cardId;
  final int ts;
  final int grade;
}

class TrainResult {
  const TrainResult({
    required this.weights,
    required this.lossBefore,
    required this.lossAfter,
    required this.reviews,
    required this.cards,
    required this.states,
  });

  final List<double> weights;

  /// Mean log loss on your long-gap reviews with the default weights, and with yours.
  final double lossBefore;
  final double lossAfter;
  final int reviews;
  final int cards;

  /// Every card's memory recomputed with the new weights: id → (stability, difficulty, last review ms).
  final Map<String, (double, double, int)> states;

  double get improvement => lossBefore <= 0 ? 0 : (lossBefore - lossAfter) / lossBefore;
}

/// Personalises FSRS-6 on your own review history (RES-47 §5.5: "running the real FSRS optimizer").
///
/// A light, on-device version: it fits the weights that matter most for one person (the four starting
/// stabilities, the growth of recall stability, the stability after a lapse and the forgetting-curve
/// decay) by coordinate search on log loss, with a pull toward the defaults so a small history can't
/// overfit. Only reviews at least a day apart are scored.
class FsrsOptimizer {
  const FsrsOptimizer._();

  static const tuned = [0, 1, 2, 3, 8, 11, 20];
  static const minReviews = 150;
  static const _lo = {0: 0.01, 1: 0.01, 2: 0.01, 3: 0.01, 8: 0.0, 11: 0.001, 20: 0.1};
  static const _hi = {0: 100.0, 1: 100.0, 2: 100.0, 3: 100.0, 8: 4.5, 11: 5.0, 20: 0.8};

  /// How many reviews count for training (long-gap ones).
  static int scorable(List<TrainReview> reviews) {
    final last = <String, int>{};
    var n = 0;
    final sorted = [...reviews]..sort((a, b) => a.ts.compareTo(b.ts));
    for (final r in sorted) {
      final prev = last[r.cardId];
      if (prev != null && elapsedStudyDays(prev, r.ts) >= 1) n++;
      last[r.cardId] = r.ts;
    }
    return n;
  }

  static TrainResult? train(List<TrainReview> reviews, {List<double>? start}) {
    final byCard = <String, List<TrainReview>>{};
    for (final r in reviews) {
      byCard.putIfAbsent(r.cardId, () => []).add(r);
    }
    for (final l in byCard.values) {
      l.sort((a, b) => a.ts.compareTo(b.ts));
    }
    final defaults = Fsrs.defaultWeights;
    var w = [...(start ?? defaults)];

    (double, int) loss(List<double> weights) {
      final f = Fsrs(weights);
      var sum = 0.0;
      var n = 0;
      for (final seq in byCard.values) {
        MemoryState? s;
        int? last;
        for (final r in seq) {
          if (s == null || last == null) {
            s = f.review(null, r.grade);
          } else {
            final el = elapsedStudyDays(last, r.ts);
            if (el >= 1) {
              final p = f.retrievability((r.ts - last) / msPerDay, s.stability).clamp(1e-4, 1 - 1e-4);
              final y = r.grade > 1 ? 1.0 : 0.0;
              sum += -(y * math.log(p) + (1 - y) * math.log(1 - p));
              n++;
            }
            s = f.review(s, r.grade, elapsedDays: el);
          }
          last = r.ts;
        }
      }
      return (n == 0 ? 0 : sum / n, n);
    }

    double penalty(List<double> weights) {
      var p = 0.0;
      for (final i in tuned) {
        final a = math.max(weights[i], 1e-3), b = math.max(defaults[i], 1e-3);
        final d = math.log(a / b);
        p += d * d;
      }
      return 0.015 * p;
    }

    final (before, n) = loss(defaults);
    if (n < minReviews) return null;
    var best = loss(w).$1 + penalty(w);
    var step = 0.3;
    for (var round = 0; round < 40 && step > 0.01; round++) {
      var improved = false;
      for (final i in tuned) {
        for (final dir in const [1.0, -1.0]) {
          final cand = [...w];
          cand[i] = (cand[i] * (1 + dir * step)).clamp(_lo[i]!, _hi[i]!);
          if (i == 8 && cand[i] == 0 && dir > 0) cand[i] = 0.05;
          final l = loss(cand).$1 + penalty(cand);
          if (l < best - 1e-6) {
            best = l;
            w = cand;
            improved = true;
          }
        }
      }
      if (!improved) step /= 2;
    }
    final after = loss(w).$1;

    // Recompute every card's memory with the new weights.
    final f = Fsrs(w);
    final states = <String, (double, double, int)>{};
    byCard.forEach((id, seq) {
      MemoryState? s;
      int? last;
      for (final r in seq) {
        s = s == null || last == null ? f.review(null, r.grade) : f.review(s, r.grade, elapsedDays: elapsedStudyDays(last, r.ts));
        last = r.ts;
      }
      if (s != null && last != null) states[id] = (s.stability, s.difficulty, last);
    });
    return TrainResult(
      weights: w,
      lossBefore: before,
      lossAfter: after,
      reviews: n,
      cards: byCard.length,
      states: states,
    );
  }
}

/// Isolate entry point: (reviews as [cardId, ts, grade] triples) → result.
TrainResult? trainInBackground(List<List<Object>> raw) =>
    FsrsOptimizer.train([for (final r in raw) TrainReview(r[0] as String, r[1] as int, r[2] as int)]);
