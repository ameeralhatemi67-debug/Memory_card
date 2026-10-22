import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Shapes drawn from polar functions, like the canvas `polar()` helper. Coordinates are in a viewBox of
/// [-half, half] and scaled to the paint size.
class PolarShape {
  const PolarShape(this.radius, {this.points = 108, this.half = 40});

  final double Function(double a) radius;
  final int points;
  final double half;

  Path path(Size size) {
    final s = size.shortestSide / (2 * half);
    final c = Offset(size.width / 2, size.height / 2);
    final p = Path();
    for (var i = 0; i <= points; i++) {
      final a = i / points * math.pi * 2;
      final r = radius(a) * s;
      final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  // Profile sign-in badges.
  static final badgeScallop = PolarShape((a) => 34 + 3.4 * math.cos(9 * a));
  static final badgeBurst = PolarShape((a) => 33.5 + 4.5 * math.cos(12 * a), points: 144);
  static final badgeSquircle = PolarShape((a) => 34 * _squircle(a) + 2.4 * math.sin(4 * a + 0.8));

  // Shop quick actions.
  static final actScallop = PolarShape((a) => 31 + 3.2 * math.cos(8 * a), points: 96);
  static final actSquircle = PolarShape((a) => 31 * _squircle(a) + 2.2 * math.sin(4 * a + 0.8), points: 96);
  static final actBurst = PolarShape((a) => 29 + 5 * math.cos(12 * a), points: 120);
  static final actBlob = PolarShape((a) => 31 + 3.5 * math.sin(3 * a) + 2 * math.cos(5 * a + 1), points: 96);

  /// The wax seal: 48 alternating points (canvas sealPath), in a 100 × 100 box.
  static final seal = PolarShape((a) {
    final i = (a / (math.pi * 2) * 48).round();
    return i.isEven ? 46 : 41;
  }, points: 48, half: 50);

  static double _squircle(double a) =>
      math.pow(math.pow(math.cos(a).abs(), 4) + math.pow(math.sin(a).abs(), 4), -0.25).toDouble();
}

class PolarPainter extends CustomPainter {
  PolarPainter(this.shape, this.color, {this.rotation = 0, this.shadow});

  final PolarShape shape;
  final Color color;
  final double rotation;
  final List<BoxShadow>? shadow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (rotation != 0) {
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(rotation);
      canvas.translate(-size.width / 2, -size.height / 2);
    }
    final path = shape.path(size);
    for (final s in shadow ?? const <BoxShadow>[]) {
      canvas.drawPath(path.shift(s.offset), s.toPaint());
    }
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PolarPainter old) => old.color != color || old.rotation != rotation || old.shape != shape;
}

/// The red wax seal with its two embossed rings; [spin] turns the scalloped rim (radians).
class WaxSeal extends StatelessWidget {
  const WaxSeal({super.key, required this.size, this.spin = 0, this.color = Mc.red, this.check = false, this.child});

  final double size;
  final double spin;
  final Color color;
  final bool check;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _SealPainter(color, spin, check)),
          ?child,
        ],
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter(this.color, this.spin, this.check);
  final Color color;
  final double spin;
  final bool check;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    canvas.translate(-c.dx, -c.dy);
    final path = PolarShape.seal.path(size);
    canvas.drawPath(path.shift(Offset(0, 4 * s)), Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * s));
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFF1F1F1).withValues(alpha: 0.5)
      ..strokeWidth = 1.6 * s;
    canvas.drawCircle(c, 33 * s, ring);
    canvas.drawCircle(c, 28 * s, ring..color = const Color(0xFFF1F1F1).withValues(alpha: 0.35)..strokeWidth = 1 * s);
    if (check) {
      final p = Path()
        ..moveTo(c.dx - 14 * s, c.dy + 1 * s)
        ..lineTo(c.dx - 4 * s, c.dy + 11 * s)
        ..lineTo(c.dx + 15 * s, c.dy - 10 * s);
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFFF1F1F1)
            ..strokeWidth = 6 * s
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.spin != spin || old.color != color || old.check != check;
}

/// The folder silhouette from text_Mockup §2: a tab head sized to the name, an S-curve shoulder
/// (alpha 0.45), 28px corners.
class FolderShape {
  const FolderShape._();

  static const head = 45.0;
  static const span = 36.0;
  static const r = 28.0;
  static const alpha = 0.45;

  static double tabWidth(String name) => math.min(230, math.max(92, name.length * 11.5 + 44));

  static Path path(double w, double h, double tw) {
    final p1 = tw + alpha * span, p2 = tw + (1 - alpha) * span, p3 = tw + span;
    return Path()
      ..moveTo(r, 0)
      ..lineTo(tw, 0)
      ..cubicTo(p1, 0, p2, head, p3, head)
      ..lineTo(w - r, head)
      ..arcToPoint(Offset(w, head + r), radius: const Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..close();
  }
}

class FolderPainter extends CustomPainter {
  FolderPainter({required this.tabWidth, required this.c1, required this.c2, required this.shadowAlpha, this.lifted = false});

  final double tabWidth;
  final Color c1;
  final Color c2;
  final double shadowAlpha;
  final bool lifted;

  @override
  void paint(Canvas canvas, Size size) {
    final path = FolderShape.path(size.width, size.height, tabWidth);
    canvas.drawPath(
      path.shift(Offset(0, lifted ? 22 : 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: lifted ? 0.45 : shadowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, lifted ? 17 : 6),
    );
    final shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c1, c2])
        .createShader(Offset.zero & size);
    canvas.drawPath(path, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(FolderPainter old) =>
      old.tabWidth != tabWidth || old.c1 != c1 || old.c2 != c2 || old.lifted != lifted || old.shadowAlpha != shadowAlpha;
}

/// Inverted luminance per folder: light mode climbs 5 % lighter per folder, dark mode 5 % darker.
({Color c1, Color c2, Color text, Color meta}) folderShade(int i, bool dark) {
  Color gray(double l) {
    final v = (l.clamp(0, 100) * 2.55).round();
    return Color.fromARGB(255, v, v, v);
  }

  final start = dark ? math.max(10.0, 95.0 - i * 5) : math.min(90.0, 20.0 + i * 5);
  final end = dark ? math.max(5.0, start - 5) : math.max(10.0, start - 5);
  final white = dark ? start < 65 : start < 45;
  final text = white ? const Color(0xFFFFFFFF) : const Color(0xFF1E1E1E);
  return (
    c1: gray(start),
    c2: gray(end),
    text: text,
    meta: white ? const Color(0xB8FFFFFF) : const Color(0xB81E1E1E),
  );
}

/// The flame of the streak counter.
class FlamePainter extends CustomPainter {
  const FlamePainter({this.color = Mc.red});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24, sy = size.height / 24;
    final p = Path()
      ..moveTo(12 * sx, 2 * sy)
      ..cubicTo(13.2 * sx, 6 * sy, 18 * sx, 8.2 * sy, 18 * sx, 13.5 * sy)
      ..arcToPoint(Offset(6 * sx, 13.5 * sy), radius: Radius.elliptical(6 * sx, 6 * sy))
      ..cubicTo(6 * sx, 10.9 * sy, 7.2 * sx, 9.2 * sy, 8.6 * sx, 7.9 * sy)
      ..cubicTo(8.9 * sx, 9.8 * sy, 10 * sx, 10.9 * sy, 11.2 * sx, 11.2 * sy)
      ..cubicTo(11 * sx, 8.6 * sy, 10.6 * sx, 5.4 * sy, 12 * sx, 2 * sy)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(FlamePainter old) => old.color != color;
}

/// A grace shield; hollow once used.
class ShieldPainter extends CustomPainter {
  const ShieldPainter({this.used = false, this.color = Mc.blue});
  final bool used;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24, sy = size.height / 28;
    final p = Path()
      ..moveTo(12 * sx, 1 * sy)
      ..lineTo(22 * sx, 5 * sy)
      ..lineTo(22 * sx, 13 * sy)
      ..cubicTo(22 * sx, 19.5 * sy, 17.7 * sx, 24.3 * sy, 12 * sx, 27 * sy)
      ..cubicTo(6.3 * sx, 24.3 * sy, 2 * sx, 19.5 * sy, 2 * sx, 13 * sy)
      ..lineTo(2 * sx, 5 * sy)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = used ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 2 * sx,
    );
  }

  @override
  bool shouldRepaint(ShieldPainter old) => old.used != used || old.color != color;
}
