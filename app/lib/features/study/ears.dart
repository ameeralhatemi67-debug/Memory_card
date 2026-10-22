import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';

/// The corner "ears" (canvas Study.dc.html): hidden at rest, they swing in on an arc around a hinge
/// off-screen as the card is dragged, are fully in at 40 % and tip 5° further at the 60 % commit line.
/// They are also buttons (Again / Got it).
class Ear extends StatelessWidget {
  const Ear({
    super.key,
    required this.right,
    required this.amount,
    required this.committed,
    required this.dragging,
    required this.onTap,
    this.suggest = false,
  });

  final bool right;

  /// 0 hidden … 1 fully in.
  final double amount;
  final bool committed;
  final bool dragging;
  final VoidCallback onTap;

  /// A typed answer suggests this side: it peeks a little.
  final bool suggest;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final shown = math.max(amount, suggest ? 0.35 : 0.0);
    final deg = right ? -48 * (1 - shown) + (committed ? 5 : 0) : 48 * (1 - shown) + (committed ? -5 : 0);
    return Semantics(
      button: true,
      label: right ? 'Remembered — show it later' : "Didn't remember — bring it back soon",
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: deg * math.pi / 180),
          duration: dragging ? const Duration(milliseconds: 60) : const Duration(milliseconds: 340),
          curve: dragging ? Curves.linear : McCurves.springy,
          builder: (context, angle, child) => Transform(
            // Hinge off-screen above the outer edge: (-150, -120) for the left ear, (246, -120) for the right.
            alignment: Alignment.topLeft,
            transform: Matrix4.identity()
              ..translateByDouble(right ? 246.0 : -150.0, -120.0, 0, 1)
              ..rotateZ(angle)
              ..translateByDouble(right ? -246.0 : 150.0, 120.0, 0, 1),
            child: child,
          ),
          child: SizedBox(
            width: 96,
            height: 128,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: right ? 42 : -42,
                  top: 14,
                  child: Transform.rotate(
                    angle: (right ? -30 : 30) * math.pi / 180,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(color: mc.earBack, borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                Positioned(
                  left: right ? 48 : -48,
                  top: 16,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 96,
                      height: 96,
                      foregroundDecoration: texDeco(context, 'buttons', BorderRadius.circular(16)),
                      decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(16), boxShadow: mc.e2),
                    ),
                  ),
                ),
                Positioned(
                  left: right ? 52 : 10,
                  top: 47,
                  child: McIcon(right ? McIcons.done : McIcons.again, size: const Size(34, 34), color: mc.onInk),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
