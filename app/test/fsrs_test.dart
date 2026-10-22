import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as ref;
import 'package:memory_card/engine/fsrs.dart';

/// Checks Memory Card's FSRS-6 against the reference `fsrs` Dart package (a port of py-fsrs) on the
/// same review sequences: identical stability and difficulty after every review.
void main() {
  final weights = [...ref.defaultParameters];
  final mine = Fsrs(weights);
  final scheduler = ref.Scheduler(
    parameters: weights,
    learningSteps: const [],
    relearningSteps: const [],
    enableFuzzing: false,
  );

  ref.Rating rating(int g) => ref.Rating.values.firstWhere((r) => r.value == g);

  void compare(List<(int grade, Duration after)> sequence) {
    var t = DateTime.utc(2026, 1, 1, 12);
    var card = ref.Card(cardId: 1, due: t);
    MemoryState? state;
    for (final (grade, after) in sequence) {
      final prev = card.lastReview;
      t = t.add(after);
      card = scheduler.reviewCard(card, rating(grade), reviewDateTime: t).card;
      final elapsed = prev == null ? null : t.difference(prev).inDays;
      state = mine.review(state, grade, elapsedDays: elapsed);
      expect(
        state.stability,
        closeTo(card.stability!, 1e-9),
        reason: 'stability after grade $grade',
      );
      expect(
        state.difficulty,
        closeTo(card.difficulty!, 1e-9),
        reason: 'difficulty after grade $grade',
      );
    }
  }

  test('matches the reference on a typical learning path', () {
    compare([
      (3, Duration.zero),
      (3, const Duration(days: 1)),
      (3, const Duration(days: 3)),
      (1, const Duration(days: 9)),
      (3, const Duration(minutes: 10)),
      (3, const Duration(days: 2)),
      (4, const Duration(days: 6)),
    ]);
  });

  test('matches the reference with same-day repeats and every grade', () {
    compare([
      (1, Duration.zero),
      (1, const Duration(minutes: 3)),
      (2, const Duration(minutes: 7)),
      (3, const Duration(hours: 2)),
      (4, const Duration(days: 1)),
      (2, const Duration(days: 12)),
      (1, const Duration(days: 40)),
      (3, const Duration(hours: 5)),
    ]);
  });

  test('matches the reference with the FSRS-6 defaults Memory Card ships', () {
    final ours = Fsrs();
    final s = ref.Scheduler(
      parameters: Fsrs.defaultWeights,
      learningSteps: const [],
      relearningSteps: const [],
      enableFuzzing: false,
    );
    var t = DateTime.utc(2026, 3, 1, 9);
    var card = ref.Card(cardId: 2, due: t);
    MemoryState? state;
    for (final (g, days) in const [
      (3, 0),
      (3, 2),
      (2, 5),
      (1, 11),
      (3, 1),
      (4, 4),
    ]) {
      final prev = card.lastReview;
      t = t.add(Duration(days: days));
      card = s.reviewCard(card, rating(g), reviewDateTime: t).card;
      state = ours.review(
        state,
        g,
        elapsedDays: prev == null ? null : t.difference(prev).inDays,
      );
      expect(state.stability, closeTo(card.stability!, 1e-9));
      expect(state.difficulty, closeTo(card.difficulty!, 1e-9));
    }
  });

  test('retrievability is 0.9 after one stability interval', () {
    final f = Fsrs();
    expect(f.retrievability(10, 10), closeTo(0.9, 1e-9));
    expect(f.daysUntil(10, 0.9), closeTo(10, 1e-9));
    expect(f.retrievability(0, 3), 1.0);
  });

  test('same-day repeats cannot inflate stability much', () {
    final f = Fsrs();
    var s = f.review(null, 3);
    for (var i = 0; i < 20; i++) {
      s = f.review(s, 3, elapsedDays: 0);
    }
    expect(s.stability, lessThan(f.initialStability(3) * 3));
  });
}
