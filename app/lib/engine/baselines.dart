import 'dart:math' as math;

/// A fixed-size window of recent values with robust statistics (median and median absolute deviation).
/// Robust statistics matter here: one coffee break must not move the baseline.
class RobustWindow {
  RobustWindow({this.capacity = 160, List<double>? values}) : _values = values ?? <double>[];

  final int capacity;
  final List<double> _values;
  int _next = 0;
  double? _median;
  double? _mad;

  int get count => _values.length;
  List<double> get values => List.unmodifiable(_values);

  void add(double v) {
    if (!v.isFinite) return;
    if (_values.length < capacity) {
      _values.add(v);
    } else {
      _values[_next] = v;
      _next = (_next + 1) % capacity;
    }
    _median = null;
    _mad = null;
  }

  double? get median {
    if (_values.isEmpty) return null;
    return _median ??= medianOf(_values);
  }

  /// Median absolute deviation (unscaled).
  double? get mad {
    final m = median;
    if (m == null) return null;
    return _mad ??= medianOf(_values.map((v) => (v - m).abs()).toList());
  }

  Map<String, Object?> toJson() => {'cap': capacity, 'v': _values, 'n': _next};

  factory RobustWindow.fromJson(Map? j, {int capacity = 160}) {
    if (j == null) return RobustWindow(capacity: capacity);
    final w = RobustWindow(
      capacity: (j['cap'] as num?)?.toInt() ?? capacity,
      values: ((j['v'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
    );
    w._next = (j['n'] as num?)?.toInt() ?? 0;
    return w;
  }

  static double medianOf(List<double> xs) {
    final s = [...xs]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }
}

/// How fast *you* usually answer. Latency only means something relative to your own normal, the length
/// of the prompt and the deck you are in, so every reading is turned into a personal z-score.
class PersonalBaselines {
  PersonalBaselines({
    RobustWindow? think,
    RobustWindow? verify,
    Map<String, double>? deckOffsets,
  })  : think = think ?? RobustWindow(),
        verify = verify ?? RobustWindow(),
        deckOffsets = deckOffsets ?? <String, double>{};

  /// Residual log think-time of correct answers (prompt length removed).
  final RobustWindow think;

  /// Log time spent checking the answer after the reveal, on correct answers.
  final RobustWindow verify;

  /// Per-deck drift of the think residual (a code deck is slower than a vocabulary deck).
  final Map<String, double> deckOffsets;

  // Population priors used until enough of your own answers exist (shrinkage weight [_priorWeight]).
  static const _thinkPrior = 7.9; // ≈ e^7.9 ≈ 2.7 s for a short prompt
  static const _thinkMadPrior = 0.42;
  static const _verifyPrior = 7.0; // ≈ 1.1 s
  static const _verifyMadPrior = 0.5;
  static const _priorWeight = 10.0;

  /// Reading time grows sub-linearly with prompt length.
  static const lengthSlope = 0.32;

  static double lengthTerm(int chars) => lengthSlope * math.log(1 + chars / 12);

  double _shrunk(double? value, int n, double prior) =>
      value == null ? prior : (value * n + prior * _priorWeight) / (n + _priorWeight);

  double get thinkCenter => _shrunk(think.median, think.count, _thinkPrior);
  double get thinkSpread => math.max(0.18, 1.4826 * _shrunk(think.mad, think.count, _thinkMadPrior));
  double get verifyCenter => _shrunk(verify.median, verify.count, _verifyPrior);
  double get verifySpread => math.max(0.2, 1.4826 * _shrunk(verify.mad, verify.count, _verifyMadPrior));

  /// Typical think time for a prompt of [chars] characters in [deckId], in milliseconds.
  double expectedThinkMs(int chars, String deckId) =>
      math.exp(thinkCenter + lengthTerm(chars) + (deckOffsets[deckId] ?? 0));

  /// Positive = slower than your normal.
  double thinkZ(int thinkMs, int chars, String deckId) {
    final residual = math.log(math.max(thinkMs, 120)) - lengthTerm(chars) - (deckOffsets[deckId] ?? 0);
    return ((residual - thinkCenter) / thinkSpread).clamp(-3.0, 3.0).toDouble();
  }

  double verifyZ(int verifyMs) =>
      ((math.log(math.max(verifyMs, 80)) - verifyCenter) / verifySpread).clamp(-3.0, 3.0).toDouble();

  /// An answer that took far longer than you ever take is an interruption, not hesitation.
  bool looksInterrupted(int thinkMs, int chars, String deckId) {
    final limit = math.max(25000.0, math.exp(thinkCenter + lengthTerm(chars) + (deckOffsets[deckId] ?? 0) + 4.5 * thinkSpread));
    return thinkMs > limit;
  }

  /// Learn from a correct answer.
  void observeCorrect({required int thinkMs, required int chars, required String deckId, int? verifyMs}) {
    final residual = math.log(math.max(thinkMs, 120)) - lengthTerm(chars);
    final offset = deckOffsets[deckId] ?? 0;
    think.add(residual - offset);
    // The deck offset follows that deck's own residuals slowly.
    deckOffsets[deckId] = offset + 0.04 * ((residual - thinkCenter) - offset);
    if (verifyMs != null && verifyMs > 0) verify.add(math.log(math.max(verifyMs, 80)));
  }

  Map<String, Object?> toJson() => {
        'think': think.toJson(),
        'verify': verify.toJson(),
        'decks': deckOffsets,
      };

  factory PersonalBaselines.fromJson(Map? j) {
    if (j == null) return PersonalBaselines();
    return PersonalBaselines(
      think: RobustWindow.fromJson(j['think'] as Map?),
      verify: RobustWindow.fromJson(j['verify'] as Map?),
      deckOffsets: ((j['decks'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    );
  }
}
