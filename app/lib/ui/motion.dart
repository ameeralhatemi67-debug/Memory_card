import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Memory Card's motion language: paper. Cards and sheets move with a small overshoot, arrive faster
/// than they leave, and never pop out of nothing.
class McCurves {
  const McCurves._();

  /// The signature ease used for most transitions (canvas: cubic-bezier(.2,.8,.2,1)).
  static const paper = Cubic(0.2, 0.8, 0.2, 1.0);

  /// Springy settle with a little overshoot (canvas ears: cubic-bezier(.34,1.35,.5,1)).
  static const springy = Cubic(0.34, 1.35, 0.5, 1.0);

  /// Strong ease-out for things entering.
  static const out = Cubic(0.23, 1.0, 0.32, 1.0);

  /// iOS-like sheet / drawer curve.
  static const drawer = Cubic(0.32, 0.72, 0.0, 1.0);

  static const inOut = Cubic(0.77, 0.0, 0.175, 1.0);
}

class McDurations {
  const McDurations._();
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 450);
}

/// Keyframe tracks replayed by a clock, exactly like the canvas: each row is [t 0…1, values…], and
/// segments are eased with smoothstep.
class Keyframes {
  const Keyframes(this.ms, this.rows);

  final double ms;
  final List<List<double>> rows;

  List<double> sample(double elapsed) {
    final u = elapsed / ms;
    if (u <= 0) return rows.first.sublist(1);
    if (u >= 1) return rows.last.sublist(1);
    var i = 1;
    while (rows[i][0] < u) {
      i++;
    }
    final a = rows[i - 1], b = rows[i];
    var k = (u - a[0]) / (b[0] - a[0]);
    k = k * k * (3 - 2 * k);
    return [for (var j = 1; j < a.length; j++) a[j] + (b[j] - a[j]) * k];
  }

  bool done(double elapsed) => elapsed >= ms;
}

/// Whether motion should be reduced (setting or OS), available anywhere below the app root.
class MotionPrefs extends InheritedWidget {
  const MotionPrefs({super.key, required this.reduced, required super.child});

  final bool reduced;

  static bool reducedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionPrefs>()?.reduced ?? false;

  @override
  bool updateShouldNotify(MotionPrefs old) => old.reduced != reduced;
}

/// Rebuilds every frame with the milliseconds since it appeared. Used for the calm ambient motion
/// (folder pills peeking, the wax seal breathing, the flame flickering). Frozen when motion is reduced.
class AmbientClock extends StatefulWidget {
  const AmbientClock({super.key, required this.builder, this.enabled = true});

  final Widget Function(BuildContext context, double ms) builder;
  final bool enabled;

  @override
  State<AmbientClock> createState() => _AmbientClockState();
}

class _AmbientClockState extends State<AmbientClock> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _ms = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => setState(() => _ms = d.inMicroseconds / 1000));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AmbientClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = widget.enabled && !MotionPrefs.reducedOf(context);
    if (run && !_ticker.isActive) _ticker.start();
    if (!run && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ms);
}

/// Small helpers for periodic ambient motion.
double wave(double ms, double periodMs, [double phase = 0]) => math.sin(ms / periodMs * math.pi * 2 + phase);

/// Eases `t` (0…1) out with a cubic.
double easeOutCubic(double t) => 1 - math.pow(1 - t.clamp(0.0, 1.0), 3).toDouble();

/// Plays a short motion now and then: after [delayMs] (stagger many of them), then every [periodMs].
/// [builder] gets the pass's progress t in 0…1 (0 between passes). Still when motion is reduced.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.builder, this.delayMs = 0, this.periodMs = 7000, this.durationMs = 1500});

  final Widget Function(BuildContext context, double t) builder;
  final int delayMs;
  final int periodMs;
  final int durationMs;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.durationMs),
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || MotionPrefs.reducedOf(context)) return;
    _started = true;
    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      _c.forward(from: 0);
      _timer = Timer.periodic(Duration(milliseconds: widget.periodMs), (_) {
        if (mounted) _c.forward(from: 0);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, builder: (context, _) => widget.builder(context, _c.isAnimating ? _c.value : 0));
}

/// A card that now and then rocks, like the two cards fanned under a deck: right, then left, then back
/// to rest (both swings ease in). [builder] gets v in −1…1; the card beneath mirrors it with −v.
class Sway extends StatelessWidget {
  const Sway({super.key, required this.builder, this.delayMs = 0, this.periodMs = 7000});

  final Widget Function(BuildContext context, double v) builder;
  final int delayMs;
  final int periodMs;

  /// The swing over one pass, t in 0…1.
  static double at(double t) {
    const a = 0.3, b = 0.7;
    if (t <= 0 || t >= 1) return 0;
    if (t < a) return Curves.easeIn.transform(t / a);
    if (t < b) return 1 - 2 * Curves.easeIn.transform((t - a) / (b - a));
    return -1 + Curves.easeOut.transform((t - b) / (1 - b));
  }

  @override
  Widget build(BuildContext context) =>
      Pulse(delayMs: delayMs, periodMs: periodMs, builder: (context, t) => builder(context, at(t)));
}
