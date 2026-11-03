import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';

/// A small looping picture of how a reveal works (Settings › Study › Reveal the answer by): a tiny card and a
/// fingertip acting it out, with one line saying what to do. With reduced motion it holds still on the moment
/// the answer shows.
class RevealPreview extends StatefulWidget {
  const RevealPreview({super.key, required this.mode});
  final RevealMode mode;

  static String captionOf(RevealMode m) => switch (m) {
        RevealMode.tap => 'Tap anywhere on the card to show the answer.',
        RevealMode.icon => 'Tap the eye button on the card to show the answer.',
        RevealMode.flip => 'Tap the card and it turns over to the answer.',
        RevealMode.front => 'No answer shown: check yourself, then swipe.',
        RevealMode.scratch => 'Scratch the silver off the answer with your finger.',
      };

  @override
  State<RevealPreview> createState() => _RevealPreviewState();
}

class _RevealPreviewState extends State<RevealPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPrefs.reducedOf(context)) {
      _c
        ..stop()
        ..value = 0.7;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Semantics(
      label: RevealPreview.captionOf(widget.mode),
      child: ExcludeSemantics(
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: mc.well, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            SizedBox(
              width: 92,
              height: 92,
              child: AnimatedBuilder(animation: _c, builder: (context, _) => _stage(mc, _c.value)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(RevealPreview.captionOf(widget.mode), style: T.t(14, w: FontWeight.w600, color: mc.ink, height: 1.3)),
            ),
          ]),
        ),
      ),
    );
  }

  /// 0 → 1 between [a] and [b] of the loop, eased.
  static double _seg(double t, double a, double b) => Curves.easeInOut.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  Widget _stage(Mc mc, double t) {
    const cw = 54.0, ch = 76.0, left = 19.0, top = 8.0;
    final mode = widget.mode;
    // The answer is out from about a third of the way round until near the end, then the loop starts over.
    final out = _seg(t, 0.36, 0.48) * (1 - _seg(t, 0.86, 0.96));
    final press = mode == RevealMode.front ? 0.0 : _seg(t, 0.26, 0.32) * (1 - _seg(t, 0.32, 0.4));

    Widget line(double w, Color c) => Container(width: w, height: 5, margin: const EdgeInsets.only(bottom: 4), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));
    final prompt = Padding(
      padding: const EdgeInsets.fromLTRB(7, 9, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [line(30, mc.onInk.withValues(alpha: 0.7)), line(20, mc.onInk.withValues(alpha: 0.4))]),
    );
    Widget answer(double v) => Opacity(
          opacity: v,
          child: Transform.scale(
            scale: 0.85 + 0.15 * v,
            child: Container(height: 14, decoration: BoxDecoration(color: Mc.peach, borderRadius: BorderRadius.circular(4))),
          ),
        );

    final face = <Widget>[prompt];
    var dx = 0.0, turn = 0.0;
    Offset? finger;
    switch (mode) {
      case RevealMode.tap:
        face.add(Positioned(left: 6, right: 6, bottom: 7, child: answer(out)));
        finger = Offset(left + cw / 2 + 6 * (1 - _seg(t, 0.1, 0.26)), top + ch / 2 + 22 * (1 - _seg(t, 0.1, 0.26)));
      case RevealMode.icon:
        face.add(Positioned(
          left: 6,
          right: 6,
          bottom: 7,
          child: Stack(children: [
            Opacity(
              opacity: 1 - out,
              child: Container(
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: mc.pill, borderRadius: BorderRadius.circular(4)),
                child: Container(width: 8, height: 5, decoration: BoxDecoration(color: Mc.graphite, borderRadius: BorderRadius.circular(3))),
              ),
            ),
            answer(out),
          ]),
        ));
        finger = Offset(left + cw / 2 + 8 * (1 - _seg(t, 0.1, 0.26)), top + ch - 14 + 20 * (1 - _seg(t, 0.1, 0.26)));
      case RevealMode.flip:
        turn = math.pi * (_seg(t, 0.3, 0.48) - _seg(t, 0.86, 0.98));
        finger = Offset(left + cw / 2 + 6 * (1 - _seg(t, 0.1, 0.26)), top + ch / 2 + 22 * (1 - _seg(t, 0.1, 0.26)));
      case RevealMode.front:
        // Never revealed: the card is checked and swiped away right, then the next one is there.
        final s = _seg(t, 0.3, 0.6);
        dx = 40 * s;
      case RevealMode.scratch:
        final clear = _seg(t, 0.24, 0.62) * (1 - _seg(t, 0.88, 0.98));
        face.add(Positioned(
          left: 6,
          right: 6,
          bottom: 7,
          child: SizedBox(
            height: 18,
            child: Stack(children: [
              Positioned.fill(child: Container(decoration: BoxDecoration(color: Mc.peach, borderRadius: BorderRadius.circular(4)))),
              Positioned.fill(
                child: ClipRect(
                  clipper: _FromLeft(clear),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [Color(0xFFA3A3A3), Color(0xFFE4E4E4), Color(0xFFB3B3B3), Color(0xFFEEEEEE)]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ));
        // The fingertip rubs back and forth across the panel.
        final rub = _seg(t, 0.22, 0.62);
        final x = rub > 0 && rub < 1 ? 0.5 + 0.5 * math.sin(rub * math.pi * 5) : 0.5;
        finger = Offset(left + 10 + (cw - 20) * x, top + ch - 16 + 18 * (1 - _seg(t, 0.12, 0.22)) + 14 * _seg(t, 0.64, 0.74));
    }

    Widget card = Container(
      width: cw,
      height: ch,
      decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))]),
      child: Stack(children: face),
    );
    if (mode == RevealMode.flip) {
      final back = turn > math.pi / 2;
      card = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.004)
          ..rotateY(turn),
        child: back
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: Container(
                  width: cw,
                  height: ch,
                  padding: const EdgeInsets.fromLTRB(7, 9, 7, 0),
                  decoration: BoxDecoration(color: Mc.peach, borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [line(24, Mc.graphite.withValues(alpha: 0.5)), line(34, Mc.graphite)]),
                ),
              )
            : card,
      );
    }
    if (mode == RevealMode.front) {
      card = Transform.translate(offset: Offset(dx, 0), child: Transform.rotate(angle: dx / 40 * 0.16, child: Opacity(opacity: 1 - _seg(t, 0.5, 0.62), child: card)));
    }

    return Stack(clipBehavior: Clip.none, children: [
      if (mode == RevealMode.front) ...[
        // The next card waits under it, and a tick shows the swipe counted.
        Positioned(left: left, top: top, child: Container(width: cw, height: ch, decoration: BoxDecoration(color: mc.ink.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8)))),
        Positioned(
          left: left + cw - 6,
          top: top + ch / 2 - 10,
          child: Opacity(
            opacity: _seg(t, 0.4, 0.5) * (1 - _seg(t, 0.75, 0.85)),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Mc.green, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 15, color: Mc.graphite),
            ),
          ),
        ),
      ],
      Positioned(left: left, top: top, child: card),
      if (finger != null)
        Positioned(
          left: finger.dx - 9,
          top: finger.dy - 9,
          child: Opacity(
            opacity: _seg(t, 0.06, 0.16) * (1 - _seg(t, 0.62, 0.74)),
            child: Transform.scale(
              scale: 1 - 0.25 * press,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: Mc.blue.withValues(alpha: 0.4), shape: BoxShape.circle, border: Border.all(color: Mc.blue, width: 2)),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Clips away the left [share] of its child: the scratched part of the foil.
class _FromLeft extends CustomClipper<Rect> {
  const _FromLeft(this.share);
  final double share;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(size.width * share, 0, size.width, size.height);

  @override
  bool shouldReclip(_FromLeft old) => old.share != share;
}
