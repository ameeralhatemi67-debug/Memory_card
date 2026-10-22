import 'dart:math' as math;

/// The memory state FSRS tracks for one card.
class MemoryState {
  const MemoryState(this.stability, this.difficulty);

  /// Days until predicted recall falls to 90 %.
  final double stability;

  /// 1 (easy) … 10 (hard).
  final double difficulty;

  @override
  String toString() => 'MemoryState(s: ${stability.toStringAsFixed(3)}, d: ${difficulty.toStringAsFixed(3)})';
}

/// FSRS-6, the 21-weight memory model (open-spaced-repetition).
///
/// In Memory Card it runs in the shadow (RES-47 §5.3): every swipe updates it, and it powers memory
/// health, the stepped fan, slipping counts, warm-up and reminders. The endless stack decides the order.
///
/// Grades: 1 Again · 2 Hard · 3 Good · 4 Easy. The formulas follow py-fsrs 6 and are checked against
/// the `fsrs` Dart package in test/fsrs_test.dart.
class Fsrs {
  Fsrs([List<double>? weights]) : w = List<double>.unmodifiable(weights ?? defaultWeights) {
    if (w.length != 21) throw ArgumentError('FSRS-6 needs 21 weights, got ${w.length}');
    decay = -w[20];
    factor = math.pow(0.9, 1 / decay).toDouble() - 1;
  }

  /// FSRS-6 defaults, as shipped by fsrs-rs (Anki) and the FSRS algorithm wiki.
  static const defaultWeights = <double>[
    0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796, //
    1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542,
  ];

  static const stabilityMin = 0.001;

  final List<double> w;
  late final double decay;
  late final double factor;

  /// Probability of recall after [elapsedDays] for a card of stability [stability].
  double retrievability(double elapsedDays, double stability) =>
      math.pow(1 + factor * math.max(0, elapsedDays) / stability, decay).toDouble();

  /// Days from the last review until recall drops to [target].
  double daysUntil(double stability, double target) =>
      stability / factor * (math.pow(target, 1 / decay).toDouble() - 1);

  double initialStability(int grade) => math.max(w[grade - 1], stabilityMin);

  double initialDifficulty(int grade) => _clampD(w[4] - math.exp(w[5] * (grade - 1)) + 1);

  /// Linear damping toward 10, then mean reversion toward the "Easy" starting difficulty.
  double nextDifficulty(double difficulty, int grade) {
    final delta = -w[6] * (grade - 3);
    final damped = difficulty + (10 - difficulty) * delta / 9;
    return _clampD(w[7] * initialDifficulty(4) + (1 - w[7]) * damped);
  }

  /// Same-day review: damped so repeated swipes in one day can't inflate stability.
  double shortTermStability(double stability, int grade) {
    var inc = math.exp(w[17] * (grade - 3 + w[18])) * math.pow(stability, -w[19]);
    if (grade >= 3) inc = math.max(inc, 1.0);
    return math.max(stability * inc, stabilityMin);
  }

  double recallStability(double difficulty, double stability, double r, int grade) {
    final hard = grade == 2 ? w[15] : 1.0;
    final easy = grade == 4 ? w[16] : 1.0;
    final gain = math.exp(w[8]) *
        (11 - difficulty) *
        math.pow(stability, -w[9]) *
        (math.exp((1 - r) * w[10]) - 1) *
        hard *
        easy;
    return math.max(stability * (1 + gain), stabilityMin);
  }

  double forgetStability(double difficulty, double stability, double r) {
    final longTerm = w[11] *
        math.pow(difficulty, -w[12]) *
        (math.pow(stability + 1, w[13]) - 1) *
        math.exp((1 - r) * w[14]);
    final shortTerm = stability / math.exp(w[17] * w[18]);
    return math.max(math.min(longTerm, shortTerm), stabilityMin);
  }

  /// Applies one review.
  ///
  /// [elapsedDays] is the number of whole days since the previous review (null for the first review).
  /// Less than one day uses the short-term formula, as in py-fsrs.
  MemoryState review(MemoryState? state, int grade, {int? elapsedDays}) {
    if (grade < 1 || grade > 4) throw ArgumentError.value(grade, 'grade');
    if (state == null) return MemoryState(initialStability(grade), initialDifficulty(grade));
    final double s;
    if (elapsedDays == null || elapsedDays < 1) {
      s = shortTermStability(state.stability, grade);
    } else {
      final r = retrievability(elapsedDays.toDouble(), state.stability);
      s = grade == 1
          ? forgetStability(state.difficulty, state.stability, r)
          : recallStability(state.difficulty, state.stability, r, grade);
    }
    return MemoryState(s, nextDifficulty(state.difficulty, grade));
  }

  static double _clampD(double d) => d.clamp(1.0, 10.0).toDouble();
}
