import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/motion.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';

/// The launch moment: three cards fan out into the logo, the name arrives, and the app takes over.
class Splash extends StatefulWidget {
  const Splash({super.key, required this.ready, required this.onDone, this.error});

  final bool ready;
  final VoidCallback onDone;
  final Object? error;

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();
  late final AnimationController _out = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed) _maybeLeave();
    });
  }

  @override
  void didUpdateWidget(Splash oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLeave();
  }

  void _maybeLeave() {
    if (_leaving || !widget.ready || !_intro.isCompleted) return;
    _leaving = true;
    _out.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _intro.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final mc = dark ? Mc.darkTheme : Mc.light;
    return Scaffold(
      backgroundColor: mc.canvas,
      body: Wall(child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _out]),
        builder: (context, _) {
          final t = _intro.value;
          final fan = McCurves.springy.transform((t / 0.62).clamp(0.0, 1.0));
          final word = McCurves.out.transform(((t - 0.38) / 0.5).clamp(0.0, 1.0));
          final tag = McCurves.out.transform(((t - 0.6) / 0.4).clamp(0.0, 1.0));
          final out = Curves.easeIn.transform(_out.value);
          return Opacity(
            opacity: 1 - out,
            child: Transform.scale(
              scale: 1 + 0.04 * out,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 128,
                      child: CustomPaint(painter: _LogoFan(fan, mc.ink)),
                    ),
                    const SizedBox(height: 26),
                    Opacity(
                      opacity: word,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - word)),
                        child: Text('Memory Card', style: T.d(44, color: mc.ink)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: tag,
                      child: Text(
                        widget.error == null ? 'One swipe at a time.' : 'Could not open your library.',
                        style: T.t(17, w: FontWeight.w600, color: mc.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      )),
    );
  }
}

/// The logo: three rounded cards fanned 0°, 15°, 30° around a corner, at 55 %, 78 % and full ink.
class _LogoFan extends CustomPainter {
  _LogoFan(this.t, this.ink);
  final double t;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 62.0, h = 100.0;
    final pivot = Offset(size.width * 0.3, size.height * 0.92);
    const opac = [0.55, 0.78, 1.0];
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(i * 15 * math.pi / 180 * t);
      final r = RRect.fromRectAndRadius(const Rect.fromLTWH(0, -h, w, h), const Radius.circular(5));
      if (i == 2) {
        canvas.drawRRect(r.shift(const Offset(0, 4)), Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      canvas.drawRRect(r, Paint()..color = ink.withValues(alpha: opac[i] * (0.6 + 0.4 * t)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LogoFan old) => old.t != t || old.ink != ink;
}
