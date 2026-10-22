import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/engine/calibration.dart';
import 'package:memory_card/engine/days.dart';
import 'package:memory_card/engine/fsrs.dart';
import 'package:memory_card/engine/optimizer.dart';

/// The two ways the engine fits itself to one person: the calibration multiplier (from 30 long-gap
/// reviews) and the on-device FSRS training (from 150).
void main() {
  test('calibration finds a learner who forgets twice as fast as the default model', () {
    final fsrs = Fsrs();
    final rnd = math.Random(11);
    final cal = Calibration();
    for (var i = 0; i < 400; i++) {
      final s = 1 + rnd.nextDouble() * 20;
      final days = 0.5 + rnd.nextDouble() * 2 * s;
      final truth = fsrs.retrievability(days * 2, s);
      cal.observe(days, s, rnd.nextDouble() < truth, fsrs);
    }
    cal.refit(fsrs);
    // Shrunk toward 1 by n / (n + 60): 400 points keep ~87 % of the log-distance to the true 2.0.
    expect(cal.multiplier, inInclusiveRange(1.6, 2.3));
  });

  test('calibration stays at 1 while evidence is thin', () {
    final fsrs = Fsrs();
    final cal = Calibration();
    for (var i = 0; i < 20; i++) {
      cal.observe(3, 2, i.isEven, fsrs);
    }
    cal.refit(fsrs);
    expect(cal.multiplier, 1.0);
  });

  test('training on a history lowers the prediction error and stays near the defaults', () {
    // A learner whose memories start weaker and decay faster than FSRS-6's defaults.
    final truth = Fsrs([...Fsrs.defaultWeights]
      ..[0] = 0.1
      ..[1] = 0.6
      ..[2] = 1.1
      ..[3] = 4.0
      ..[20] = 0.3);
    final rnd = math.Random(5);
    final reviews = <TrainReview>[];
    final start = DateTime(2026, 1, 5, 18).millisecondsSinceEpoch;
    for (var c = 0; c < 160; c++) {
      var t = start + rnd.nextInt(10) * msPerDay;
      MemoryState? s;
      int? last;
      for (var k = 0; k < 6; k++) {
        int grade;
        if (s == null) {
          grade = 3;
        } else {
          final p = truth.retrievability((t - last!) / msPerDay, s.stability);
          grade = rnd.nextDouble() < p ? 3 : 1;
        }
        reviews.add(TrainReview('c$c', t, grade));
        s = s == null ? truth.review(null, grade) : truth.review(s, grade, elapsedDays: elapsedStudyDays(last!, t));
        last = t;
        t += (1 + rnd.nextInt(12)) * msPerDay;
      }
    }
    expect(FsrsOptimizer.scorable(reviews), greaterThanOrEqualTo(FsrsOptimizer.minReviews));
    final r = FsrsOptimizer.train(reviews)!;
    expect(r.lossAfter, lessThan(r.lossBefore));
    expect(r.improvement, greaterThan(0.02));
    // Only the personal weights move, and they stay inside their bounds.
    for (var i = 0; i < 21; i++) {
      if (!FsrsOptimizer.tuned.contains(i)) expect(r.weights[i], Fsrs.defaultWeights[i]);
    }
    expect(r.weights[20], inInclusiveRange(0.1, 0.8));
    expect(r.states.length, 160);
  });

  test('training refuses a history without enough reviews a day apart', () {
    final reviews = [
      for (var i = 0; i < 100; i++) TrainReview('c${i % 10}', 1700000000000 + i * 60000, 3),
    ];
    expect(FsrsOptimizer.train(reviews), isNull);
  });
}
