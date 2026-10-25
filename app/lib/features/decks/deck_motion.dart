import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../ui/motion.dart';
import '../../ui/theme.dart';

/// Motion maths shared by the deck bar's three animated actions (design canvas "Deck swipe actions":
/// Delete A "Cold feet", Archive B "Snap-in", Pin A "Press from above"). The numbers are the canvas's.
abstract final class Mo {
  static double c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
  static double lerp(double a, double b, double t) => a + (b - a) * t;
  static double eo3(double t) => 1 - math.pow(1 - c01(t), 3).toDouble();
  static double ei3(double t) {
    final c = c01(t);
    return c * c * c;
  }

  static double eio(double t) {
    final c = c01(t);
    return c < 0.5 ? 2 * c * c : 1 - math.pow(-2 * c + 2, 2).toDouble() / 2;
  }

  /// Ease out with an overshoot (the canvas's `ebk`).
  static double ebk(double t, [double s = 1.70158]) {
    final c = c01(t) - 1;
    return 1 + (s + 1) * c * c * c + s * c * c;
  }

  /// Unit step response of a damped spring: 0 → 1 with ζ = [z] (< 1 overshoots) and ω = [w].
  static double spr(double t, double z, double w) {
    if (t <= 0) return 0;
    if (z >= 1) return 1 - math.exp(-w * t) * (1 + w * t);
    final wd = w * math.sqrt(1 - z * z);
    return 1 - math.exp(-z * w * t) * (math.cos(wd * t) + (z * w / wd) * math.sin(wd * t));
  }

  /// A repeatable pseudo random number in 0…1.
  static double hash(num n) {
    final v = math.sin(n * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }
}

/// How long the delete chip (or the open bar) has to be held.
const kHoldSeconds = 1.15;

/// The shiver of a deck that is afraid of being deleted: it rocks to either side, slowly at first and
/// faster and wider (up to 4°) as the hold nears its end.
class HoldPose {
  const HoldPose(this.rot, this.p, this.phase);

  /// Radians.
  final double rot;

  /// Hold progress, 0…1.
  final double p;
  final double phase;
}

HoldPose holdPose(double t) {
  const f0 = 1.6, f1 = 12.0, k = 2.2;
  final tt = math.min(t, kHoldSeconds);
  final p = Mo.c01(t / kHoldSeconds);
  final phase = 2 * math.pi * (f0 * tt + (f1 - f0) * kHoldSeconds * math.pow(tt / kHoldSeconds, k + 1) / (k + 1));
  final amp = 4 * (0.45 + 0.55 * Mo.eio(p));
  return HoldPose(amp * math.sin(phase) * math.pi / 180, p, phase);
}

// ---------------------------------------------------------------------------------------------------------------
// The ring that fills round the delete chip while it is held.

class HoldRingPainter extends CustomPainter {
  const HoldRingPainter(this.p, this.color);
  final double p;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color.withValues(alpha: 0.2),
    );
    if (p <= 0.001) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.butt
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(HoldRingPainter old) => old.p != p || old.color != color;
}

/// Cold sweat on the shivering deck: three drops that rise off its top edge, more often the closer the hold is to
/// the end. Painted in the bar's own coordinates.
class SweatPainter extends CustomPainter {
  const SweatPainter(this.p, this.clock);
  final double p;
  final double clock;

  @override
  void paint(Canvas canvas, Size size) {
    if (p < 0.4) return;
    for (var i = 0; i < 3; i++) {
      final ph = (clock * (0.9 + 2.8 * p) + i / 3) % 1;
      final x = size.width - 118 + i * 30 + ph * 10;
      final y = 2 - 26 * ph;
      canvas.save();
      canvas.translate(x + 4.5, y + 6.5);
      canvas.rotate((16 + i * 6) * math.pi / 180);
      final s = 0.7 + 0.5 * ph;
      canvas.scale(s, s);
      final drop = Path()
        ..moveTo(0, -6.5)
        ..cubicTo(0, -6.5, -4.5, 0, -4.5, 2.6)
        ..arcToPoint(const Offset(4.5, 2.6), radius: const Radius.circular(4.5), clockwise: false)
        ..cubicTo(4.5, 0, 0, -6.5, 0, -6.5)
        ..close();
      canvas.drawPath(drop, Paint()..color = Mc.blue.withValues(alpha: math.sin(math.pi * ph) * 0.95));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SweatPainter old) => old.p != p || old.clock != clock;
}

/// The deck bursts into paper: 20 scraps thrown up and out of the bar, falling back as they fade.
class BurstPainter extends CustomPainter {
  const BurstPainter({required this.u, required this.center, required this.barWidth, required this.ink, required this.muted});

  /// Seconds since the burst.
  final double u;
  final Offset center;
  final double barWidth;
  final Color ink;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final k = barWidth / 350;
    for (var i = 0; i < 20; i++) {
      final r1 = Mo.hash(i * 7 + 1), r2 = Mo.hash(i * 13 + 5), r3 = Mo.hash(i * 17 + 9);
      final ang = (-175 + r1 * 170) * math.pi / 180, spd = 240 + r2 * 360;
      final x = center.dx + (-150 + r3 * 300) * k + math.cos(ang) * spd * u * 0.5;
      final y = center.dy + math.sin(ang) * spd * u + 0.5 * 1700 * u * u;
      final sz = 7 + r2 * 8;
      final color = i % 3 == 0 ? Mc.delete : (i % 3 == 1 ? ink : muted);
      final alpha = 1 - Mo.c01((u - 0.45) / 0.3);
      if (alpha <= 0) continue;
      canvas.save();
      canvas.translate(x + sz / 2, y + sz * 0.65);
      canvas.rotate((r1 - 0.5) * 1500 * u * math.pi / 180);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: sz, height: sz * 1.3), const Radius.circular(2)),
        Paint()..color = color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(BurstPainter old) => old.u != u || old.center != center;
}

/// Two kinds of rings that spread from a pin going in (clipped to the bar by the caller).
class RipplePainter extends CustomPainter {
  const RipplePainter(this.rings, this.center, this.color);
  final List<(double, double)> rings; // (radius, opacity)
  final Offset center;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (r, op) in rings) {
      if (op <= 0.001) continue;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: op),
      );
    }
  }

  @override
  bool shouldRepaint(RipplePainter old) => true;
}

// ---------------------------------------------------------------------------------------------------------------
// FlipSlot: the other decks reorganise.

/// How a row of the list moves when another deck leaves or is pinned: it springs from where it was to where
/// the layout now puts it, [delay] seconds after the change, with damping [z] and frequency [w].
class FlipSpec {
  const FlipSpec({this.delay = 0, this.z = 0.7, this.w = 17});
  final double delay;
  final double z;
  final double w;
}

/// Wraps a list row. When [epoch] changes the row remembers where it was painted before and where the layout now
/// puts it, and springs between the two (a "FLIP" move). It watches paints, not builds, so the first frame after
/// the change is already drawn at the old place: no jump. Rows that were not moved by the change (their position
/// differs by under a pixel) do nothing, and so do rows without a [spec].
class FlipSlot extends StatefulWidget {
  const FlipSlot({super.key, required this.epoch, this.spec, this.skip = false, required this.child});

  final int epoch;
  final FlipSpec? spec;

  /// The row that is flying by itself (it is drawn by an overlay while the others move).
  final bool skip;
  final Widget child;

  @override
  State<FlipSlot> createState() => _FlipSlotState();
}

class _FlipSlotState extends State<FlipSlot> {
  final _ctl = _FlipCtl();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctl.position = Scrollable.maybeOf(context)?.position;
  }

  @override
  void didUpdateWidget(FlipSlot old) {
    super.didUpdateWidget(old);
    if (old.epoch != widget.epoch && !widget.skip && widget.spec != null && !MotionPrefs.reducedOf(context)) {
      _ctl.armed = widget.spec;
    }
  }

  @override
  Widget build(BuildContext context) => _FlipBox(ctl: _ctl, child: widget.child);
}

class _FlipCtl {
  ScrollPosition? position;
  double? lastY;
  double lastOffset = 0;
  FlipSpec? armed;
  FlipSpec? spec;
  double delta = 0;
  Duration t0 = Duration.zero;

  double offsetAt(Duration now) {
    final s = spec;
    if (s == null) return 0;
    final t = (now - t0).inMicroseconds / 1e6 - s.delay;
    if (t > 1.6) {
      spec = null;
      return 0;
    }
    return delta * (1 - Mo.spr(t, s.z, s.w));
  }
}

class _FlipBox extends SingleChildRenderObjectWidget {
  const _FlipBox({required this.ctl, super.child});
  final _FlipCtl ctl;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFlip(ctl);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderFlip renderObject) {
    renderObject.ctl = ctl;
    if (ctl.armed != null) renderObject.markNeedsPaint();
  }
}

class _RenderFlip extends RenderProxyBox {
  _RenderFlip(this.ctl);
  _FlipCtl ctl;
  double _o = 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    final y = localToGlobal(Offset.zero).dy + (ctl.position?.pixels ?? 0);
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final armed = ctl.armed;
    if (armed != null) {
      ctl.armed = null;
      final from = ctl.lastY;
      if (from != null) {
        final d = from + ctl.lastOffset - y;
        if (d.abs() > 1) {
          ctl.spec = armed;
          ctl.delta = d;
          ctl.t0 = now;
        }
      }
    }
    _o = ctl.spec == null ? 0 : ctl.offsetAt(now);
    ctl.lastY = y;
    ctl.lastOffset = _o;
    if (ctl.spec != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) markNeedsPaint();
      });
    }
    context.paintChild(c, offset + Offset(0, _o));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintOffset(
      offset: Offset(0, _o),
      position: position,
      hitTest: (r, p) => child?.hitTest(r, position: p) ?? false,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0.0, _o, 0.0, 1.0);
  }
}
