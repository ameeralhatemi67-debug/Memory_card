import 'dart:math' as math;

import 'baselines.dart';

/// Everything the study screen measured while one card was on top.
class ReviewSignals {
  const ReviewSignals({
    required this.thinkMs,
    this.verifyMs,
    this.dragMs = 0,
    this.reversals = 0,
    this.crossings = 0,
    this.hesitation = 0,
    this.velocity = 0,
    this.viaButton = false,
    this.interrupted = false,
    this.promptChars = 10,
    this.typedSimilarity,
  });

  /// From the card settling on top to the reveal (or to the first touch in front-only mode).
  final int thinkMs;

  /// From the reveal to the start of the swipe: time spent checking the answer.
  final int? verifyMs;

  /// Duration of the swipe gesture itself.
  final int dragMs;

  /// Direction changes during the drag.
  final int reversals;

  /// How often the commit line was crossed before letting go (in either direction).
  final int crossings;

  /// Furthest excursion toward the *other* answer, as a fraction of the card width.
  final double hesitation;

  /// Release speed in the chosen direction, px/s (0 for buttons and keys).
  final double velocity;

  /// The answer came from an ear button or a key, so there is no drag to read.
  final bool viaButton;

  /// The app went to the background, or the pause was far beyond your normal.
  final bool interrupted;

  /// Characters on the prompt side, to normalise reading time.
  final int promptChars;

  /// Similarity of a typed answer to the expected one (0…1), when typing mode is on.
  final double? typedSimilarity;

  Map<String, Object?> toJson() => {
        'think': thinkMs,
        'verify': verifyMs,
        'drag': dragMs,
        'rev': reversals,
        'cross': crossings,
        'hes': double.parse(hesitation.toStringAsFixed(3)),
        'vel': velocity.round(),
        'btn': viaButton,
        'int': interrupted,
        'chars': promptChars,
        if (typedSimilarity != null) 'typed': double.parse(typedSimilarity!.toStringAsFixed(3)),
      };
}

enum RecallKind { fluent, solid, effortful, unsure, blank, nearMiss, missed }

/// The engine's reading of one answer: the grade FSRS receives and why.
class Assessment {
  const Assessment({
    required this.recalled,
    required this.grade,
    required this.confidence,
    required this.kind,
    required this.latencyTrusted,
    this.fluency,
    this.decisiveness,
    this.verification,
    this.automatic = true,
  });

  final bool recalled;

  /// 1 Again · 2 Hard · 3 Good · 4 Easy.
  final int grade;

  /// 0…1. For a recalled card: how fluent and sure the recall looked.
  final double confidence;
  final RecallKind kind;
  final bool latencyTrusted;
  final double? fluency;
  final double? decisiveness;
  final double? verification;

  /// False when the user picked the grade themselves.
  final bool automatic;

  String get label => switch (kind) {
        RecallKind.fluent => 'Fast and sure',
        RecallKind.solid => 'Solid',
        RecallKind.effortful => 'Slow recall',
        RecallKind.unsure => 'Second thoughts',
        RecallKind.blank => "Didn't know it",
        RecallKind.nearMiss => 'Almost had it',
        RecallKind.missed => 'Missed',
      };

  static String gradeName(int g) => const ['', 'Again', 'Hard', 'Good', 'Easy'][g];

  Assessment withGrade(int g) => Assessment(
        recalled: g > 1,
        grade: g,
        confidence: confidence,
        kind: g == 4
            ? RecallKind.fluent
            : g == 3
                ? RecallKind.solid
                : g == 2
                    ? RecallKind.effortful
                    : RecallKind.missed,
        latencyTrusted: latencyTrusted,
        fluency: fluency,
        decisiveness: decisiveness,
        verification: verification,
        automatic: false,
      );
}

/// Turns a swipe into a grade using *how* you answered, not only which way you swiped.
///
/// - The swipe direction is the honest outcome: recalled or not (RES-47 keeps binary self-grading).
/// - For a recalled card, fluency (think time vs. your personal normal), decisiveness (a clean, quick swipe
///   vs. back-and-forth) and verification (how long you studied the answer) decide Hard / Good / Easy.
/// - Interruptions are detected and ignored, so a phone call never counts as hesitation.
/// - The thresholds tune themselves: see [GradeTuner].
class Assessor {
  const Assessor();

  static const wFluency = 0.55;
  static const wDecisive = 0.25;
  static const wVerify = 0.20;

  Assessment assess({
    required bool recalled,
    required ReviewSignals s,
    required PersonalBaselines baselines,
    required GradeTuner tuner,
    required String deckId,
    required bool firstExposure,
    bool smartGrading = true,
  }) {
    final interrupted = s.interrupted || baselines.looksInterrupted(s.thinkMs, s.promptChars, deckId);
    final trusted = !interrupted;

    final zThink = baselines.thinkZ(s.thinkMs, s.promptChars, deckId);
    final fluency = trusted ? _logistic(-1.25 * zThink) : 0.5;

    double decisive;
    if (s.viaButton) {
      decisive = 0.6;
    } else {
      final clean = (1 - 0.22 * s.reversals - 0.18 * math.max(0, s.crossings - 1) - 0.9 * s.hesitation).clamp(0.0, 1.0);
      decisive = (0.8 * clean + 0.2 * math.min(1.0, s.velocity / 1400)).clamp(0.0, 1.0);
    }

    final verification = trusted && s.verifyMs != null ? _logistic(-1.0 * baselines.verifyZ(s.verifyMs!)) : 0.5;

    var confidence = wFluency * fluency + wDecisive * decisive + wVerify * verification;
    if (s.typedSimilarity != null) {
      // A typed answer is hard evidence: blend it in strongly.
      confidence = 0.5 * confidence + 0.5 * s.typedSimilarity!;
    }

    if (!recalled) {
      final nearMiss = s.reversals >= 1 || s.hesitation > 0.12 || s.crossings >= 2 || (trusted && zThink > 0.6);
      final blank = !nearMiss && trusted && zThink < -0.3 && decisive > 0.6;
      return Assessment(
        recalled: false,
        grade: 1,
        confidence: confidence,
        kind: blank ? RecallKind.blank : (nearMiss ? RecallKind.nearMiss : RecallKind.missed),
        latencyTrusted: trusted,
        fluency: fluency,
        decisiveness: decisive,
        verification: verification,
      );
    }

    if (!smartGrading) {
      return Assessment(
        recalled: true,
        grade: 3,
        confidence: confidence,
        kind: RecallKind.solid,
        latencyTrusted: trusted,
        fluency: fluency,
        decisiveness: decisive,
        verification: verification,
      );
    }

    // A brand-new card needs stronger evidence before it is called Easy.
    final easyAt = tuner.easyAt + (firstExposure ? 0.05 : 0);
    final int grade;
    final RecallKind kind;
    if (confidence >= easyAt && trusted) {
      grade = 4;
      kind = RecallKind.fluent;
    } else if (confidence < tuner.hardBelow) {
      grade = 2;
      kind = decisive < 0.5 ? RecallKind.unsure : RecallKind.effortful;
    } else {
      grade = 3;
      kind = RecallKind.solid;
    }
    return Assessment(
      recalled: true,
      grade: grade,
      confidence: confidence,
      kind: kind,
      latencyTrusted: trusted,
      fluency: fluency,
      decisiveness: decisive,
      verification: verification,
    );
  }

  static double _logistic(double x) => 1 / (1 + math.exp(-x));
}

/// Self-tuning grade thresholds.
///
/// If cards the engine called "Easy" later fail more often than FSRS expected, "Easy" was too generous:
/// the bar rises. If "Hard" cards do better than expected, "Hard" was too harsh: the bar drops.
/// Only reviews at least a day apart count, and each step is small.
class GradeTuner {
  GradeTuner({this.easyAt = 0.74, this.hardBelow = 0.34, Map<int, GradeTally>? tallies})
      : tallies = tallies ?? {2: GradeTally(), 3: GradeTally(), 4: GradeTally()};

  double easyAt;
  double hardBelow;
  final Map<int, GradeTally> tallies;

  static const minEasy = 0.66, maxEasy = 0.92, minHard = 0.2, maxHard = 0.45;
  static const window = 40;

  /// Record what happened on the next long-gap review of a card whose previous grade was [prevGrade].
  void observe(int prevGrade, bool success, double predicted) {
    final t = tallies[prevGrade];
    if (t == null) return;
    t.n++;
    if (success) t.success++;
    t.predicted += predicted;
    if (t.n >= window) _retune(prevGrade, t);
  }

  void _retune(int grade, GradeTally t) {
    final observed = t.success / t.n;
    final expected = t.predicted / t.n;
    final gap = observed - expected;
    if (grade == 4) {
      if (gap < -0.05) easyAt = math.min(maxEasy, easyAt + 0.02);
      if (gap > 0.04) easyAt = math.max(minEasy, easyAt - 0.01);
    } else if (grade == 2) {
      if (gap > 0.05) hardBelow = math.max(minHard, hardBelow - 0.02);
      if (gap < -0.05) hardBelow = math.min(maxHard, hardBelow + 0.01);
    }
    t
      ..lastObserved = observed
      ..lastExpected = expected
      ..n = 0
      ..success = 0
      ..predicted = 0;
  }

  Map<String, Object?> toJson() => {
        'easy': easyAt,
        'hard': hardBelow,
        't': tallies.map((k, v) => MapEntry('$k', v.toJson())),
      };

  factory GradeTuner.fromJson(Map? j) {
    if (j == null) return GradeTuner();
    final raw = (j['t'] as Map?) ?? const {};
    return GradeTuner(
      easyAt: (j['easy'] as num?)?.toDouble() ?? 0.74,
      hardBelow: (j['hard'] as num?)?.toDouble() ?? 0.34,
      tallies: {
        for (final g in const [2, 3, 4]) g: GradeTally.fromJson(raw['$g'] as Map?),
      },
    );
  }
}

class GradeTally {
  int n = 0;
  int success = 0;
  double predicted = 0;
  double? lastObserved;
  double? lastExpected;

  Map<String, Object?> toJson() => {'n': n, 's': success, 'p': predicted, 'lo': lastObserved, 'le': lastExpected};

  factory GradeTally.fromJson(Map? j) {
    final t = GradeTally();
    if (j == null) return t;
    t.n = (j['n'] as num?)?.toInt() ?? 0;
    t.success = (j['s'] as num?)?.toInt() ?? 0;
    t.predicted = (j['p'] as num?)?.toDouble() ?? 0;
    t.lastObserved = (j['lo'] as num?)?.toDouble();
    t.lastExpected = (j['le'] as num?)?.toDouble();
    return t;
  }

  GradeTally();
}
