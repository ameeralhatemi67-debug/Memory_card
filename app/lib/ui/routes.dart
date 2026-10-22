import 'package:flutter/material.dart';

import 'motion.dart';

/// Full pages slide in a short distance and fade (paper on paper), leave faster than they arrive, and
/// keep the system back-swipe on iOS.
class McPageRoute<T> extends PageRouteBuilder<T> {
  McPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (context, a, b) => builder(context),
          transitionsBuilder: (context, a, b, child) {
            final reduced = MotionPrefs.reducedOf(context);
            final c = CurvedAnimation(parent: a, curve: McCurves.out, reverseCurve: Curves.easeInCubic);
            final behind = CurvedAnimation(parent: b, curve: McCurves.out);
            if (reduced) return FadeTransition(opacity: c, child: child);
            return SlideTransition(
              position: Tween(begin: Offset.zero, end: const Offset(-0.08, 0)).animate(behind),
              child: FadeTransition(
                opacity: c,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.12, 0), end: Offset.zero).animate(c),
                  child: child,
                ),
              ),
            );
          },
        );
}
