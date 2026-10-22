import 'dart:math' as math;

import 'fsrs.dart';

/// One long-gap review kept for calibration: how long since the previous review, the stability the
/// model had at that point, and whether you remembered.
class CalibPoint {
  const CalibPoint(this.days, this.stability, this.ok);
  final double days;
  final double stability;
  final bool ok;

  List<num> toJson() => [double.parse(days.toStringAsFixed(3)), double.parse(stability.toStringAsFixed(4)), ok ? 1 : 0];
  static CalibPoint fromJson(List j) => CalibPoint((j[0] as num).toDouble(), (j[1] as num).toDouble(), j[2] == 1);
}

/// One row of the calibration chart.
class CalibBin {
  const CalibBin(this.lo, this.hi, this.n, this.predicted, this.observed);
  final double lo;
  final double hi;
  final int n;
  final double predicted;
  final double observed;
}

/// Personal calibration of the prediction layer (RES-47 §5.3).
///
/// FSRS with default weights can be badly off for one person (RES-47 found 23–66 % actual recall where it
/// predicted 90 %). Until there is enough history to train weights, a single "time multiplier" m is fitted
/// so that predicted recall R(t · m) matches what you actually remember. m > 1 means you forget faster than
/// the default model assumes. It is shrunk toward 1 while evidence is thin.
class Calibration {
  Calibration({this.multiplier = 1.0, List<CalibPoint>? points}) : points = points ?? <CalibPoint>[];

  double multiplier;
  final List<CalibPoint> points;
  int _sinceFit = 0;

  static const capacity = 400;
  static const minPoints = 30;
  static const shrinkN = 60.0;

  void observe(double elapsedDays, double stability, bool ok, Fsrs fsrs) {
    if (elapsedDays < 0.5 || stability <= 0) return;
    points.add(CalibPoint(elapsedDays, stability, ok));
    if (points.length > capacity) points.removeAt(0);
    if (++_sinceFit >= 8 && points.length >= minPoints) refit(fsrs);
  }

  void refit(Fsrs fsrs) {
    _sinceFit = 0;
    if (points.length < minPoints) {
      multiplier = 1.0;
      return;
    }
    final observed = points.where((p) => p.ok).length / points.length;
    double meanPred(double m) =>
        points.fold<double>(0, (a, p) => a + fsrs.retrievability(p.days * m, p.stability)) / points.length;
    // Mean predicted recall falls as m grows; bisect on log m.
    var lo = math.log(0.25), hi = math.log(4.0);
    if (meanPred(math.exp(lo)) <= observed) {
      hi = lo;
    } else if (meanPred(math.exp(hi)) >= observed) {
      lo = hi;
    } else {
      for (var i = 0; i < 40; i++) {
        final mid = (lo + hi) / 2;
        if (meanPred(math.exp(mid)) > observed) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
    }
    final fitted = (lo + hi) / 2;
    final n = points.length.toDouble();
    multiplier = math.exp(fitted * n / (n + shrinkN));
  }

  /// Predicted vs observed recall in five bins, for the Memory Lab.
  List<CalibBin> bins(Fsrs fsrs) {
    const edges = [0.0, 0.7, 0.8, 0.88, 0.94, 1.01];
    final out = <CalibBin>[];
    for (var i = 0; i < edges.length - 1; i++) {
      var n = 0, ok = 0;
      var pred = 0.0;
      for (final p in points) {
        final r = fsrs.retrievability(p.days * multiplier, p.stability);
        if (r >= edges[i] && r < edges[i + 1]) {
          n++;
          pred += r;
          if (p.ok) ok++;
        }
      }
      if (n > 0) out.add(CalibBin(edges[i], math.min(1, edges[i + 1]), n, pred / n, ok / n));
    }
    return out;
  }

  Map<String, Object?> toJson() => {'m': multiplier, 'p': points.map((e) => e.toJson()).toList()};

  factory Calibration.fromJson(Map? j) {
    if (j == null) return Calibration();
    return Calibration(
      multiplier: (j['m'] as num?)?.toDouble() ?? 1.0,
      points: ((j['p'] as List?) ?? const []).map((e) => CalibPoint.fromJson(e as List)).toList(),
    );
  }
}
