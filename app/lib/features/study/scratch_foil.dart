import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../services/haptics.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';

/// Coverage is counted on a 6 px grid; what is left of the foil at the end breaks into 12 px flakes.
const double _cell = 6;
const double _flake = 12;
const double _brush = 30;

const _silver = [Color(0xFFA3A3A3), Color(0xFFE4E4E4), Color(0xFFB3B3B3), Color(0xFFEEEEEE), Color(0xFF9E9E9E)];
const _silverStops = [0.0, 0.28, 0.5, 0.72, 1.0];

Shader _silverShader(Rect r) =>
    const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _silver, stops: _silverStops).createShader(r);

double _hash(double n) {
  final v = math.sin(n * 12.9898) * 43758.5453;
  return v - v.floorToDouble();
}

double _c01(double v) => v.clamp(0.0, 1.0);
double _eo3(double t) => 1 - math.pow(1 - _c01(t), 3).toDouble();

/// Scratch to reveal (canvas "Scratch · A — Silver foil"): silver foil over the answer. Scratching clears it
/// with ragged edges and flicks shavings off ahead of the finger, and the phone buzzes while the finger is on
/// fresh foil (smooth where it is already clear). Once [need] of the panel is clear the answer counts as
/// revealed, and the rest of the foil breaks into flakes that lift and drop away, rippling out from the
/// finger. With reduced motion there are no shavings or flakes: the foil fades.
class ScratchFoil extends StatefulWidget {
  const ScratchFoil({
    super.key,
    required this.child,
    required this.revealed,
    required this.onReveal,
    this.buzz = 0.6,
    this.minHeight = 112,
    this.need = 0.5,
  });

  /// The answer under the foil.
  final Widget child;

  /// Revealed already (scratched, or by the keyboard): a foil still on flakes off at once.
  final bool revealed;
  final VoidCallback onReveal;

  /// How hard the phone buzzes, 0 … 1 (Settings › Study › Scratch vibration).
  final double buzz;
  final double minHeight;

  /// The share of the panel that has to be clear.
  final double need;

  @override
  State<ScratchFoil> createState() => _ScratchFoilState();
}

class _ScratchFoilState extends State<ScratchFoil> with TickerProviderStateMixin {
  final List<Path> _paths = [];
  final List<(Offset, double)> _dabs = [];
  final _repaint = ValueNotifier<int>(0);
  Uint8List _grid = Uint8List(0);
  int _gx = 0, _gy = 0, _covN = 0, _seq = 0;
  Size _size = Size.zero;
  int? _pointer;
  Offset? _last;
  bool _done = false;
  bool _reduced = false;
  ui.Picture? _foil;
  Size _foilSize = Size.zero;
  TextPainter? _print;

  late final AnimationController _sheen = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  double get _cov => _grid.isEmpty ? 0 : _covN / _grid.length;

  @override
  void initState() {
    super.initState();
    if (widget.revealed) {
      // Already revealed when built (the same card again after a rebuild): no foil.
      _done = true;
      _fade.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MotionPrefs.reducedOf(context);
    _print?.dispose();
    _print = TextPainter(
      text: TextSpan(text: 'Scratch to reveal', style: T.t(15, w: FontWeight.w700, color: const Color(0xFF5E5E5E))),
      textDirection: TextDirection.ltr,
    )..layout();
    _syncSheen();
  }

  @override
  void didUpdateWidget(ScratchFoil old) {
    super.didUpdateWidget(old);
    if (widget.revealed && !_done) {
      // Revealed another way (the keyboard): the foil flakes off after this frame, since the flakes join the
      // overlay, which cannot change while it is being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _done) return;
        _complete(all: true, notify: false);
        setState(() {});
      });
    } else if (!widget.revealed && old.revealed && _done) {
      _reset();
    }
  }

  @override
  void dispose() {
    _sheen.dispose();
    _fade.dispose();
    _pop.dispose();
    _repaint.dispose();
    _foil?.dispose();
    _print?.dispose();
    super.dispose();
  }

  /// The glint runs across untouched foil only, and never with reduced motion.
  void _syncSheen() {
    final run = !_done && _paths.isEmpty && !_reduced;
    if (run && !_sheen.isAnimating) _sheen.repeat();
    if (!run && _sheen.isAnimating) _sheen.stop();
  }

  void _reset() {
    _paths.clear();
    _dabs.clear();
    _grid = Uint8List(0);
    _covN = 0;
    _done = false;
    _pointer = null;
    _last = null;
    _fade.value = 0;
    _pop.value = 0;
    _syncSheen();
    _repaint.value++;
  }

  // ---------------------------------------------------------------- scratching

  RenderBox? get _box => context.findRenderObject() as RenderBox?;

  void _ensureGrid() {
    final size = _box?.size ?? Size.zero;
    if (size == _size && _grid.isNotEmpty) return;
    _size = size;
    _gx = math.max(1, (size.width / _cell).ceil());
    _gy = math.max(1, (size.height / _cell).ceil());
    _grid = Uint8List(_gx * _gy);
    _covN = 0;
  }

  /// Marks the cells under a brush at [p]; returns how many were still foil.
  int _stamp(Offset p) {
    const r = _brush / 2 - 1;
    var fresh = 0;
    final x0 = math.max(0, ((p.dx - r) / _cell).floor()), x1 = math.min(_gx - 1, ((p.dx + r) / _cell).floor());
    final y0 = math.max(0, ((p.dy - r) / _cell).floor()), y1 = math.min(_gy - 1, ((p.dy + r) / _cell).floor());
    for (var gy = y0; gy <= y1; gy++) {
      for (var gx = x0; gx <= x1; gx++) {
        final k = gy * _gx + gx;
        if (_grid[k] == 1) continue;
        final cx = (gx + 0.5) * _cell, cy = (gy + 0.5) * _cell;
        if ((cx - p.dx) * (cx - p.dx) + (cy - p.dy) * (cy - p.dy) <= r * r) {
          _grid[k] = 1;
          _covN++;
          fresh++;
        }
      }
    }
    return fresh;
  }

  void _down(PointerDownEvent e) {
    if (_done || _pointer != null) return;
    _ensureGrid();
    _pointer = e.pointer;
    final p = e.localPosition;
    _paths.add(Path()..moveTo(p.dx, p.dy)..lineTo(p.dx + 0.1, p.dy));
    _last = p;
    final fresh = _stamp(p);
    _syncSheen();
    _scratched(p, const Offset(1, 0), fresh);
  }

  void _move(PointerMoveEvent e) {
    final last = _last;
    if (_done || e.pointer != _pointer || last == null) return;
    final p = e.localPosition;
    final d = p - last;
    final len = d.distance;
    if (len < 1.5) return;
    _paths.last.lineTo(p.dx, p.dy);
    var fresh = 0;
    final n = math.max(1, (len / 4).ceil());
    for (var k = 1; k <= n; k++) {
      fresh += _stamp(Offset.lerp(last, p, k / n)!);
    }
    _last = p;
    _scratched(p, d / len, fresh);
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _last = null;
  }

  /// After each bit of scratching: ragged edges, shavings, the buzz, and the reveal once enough is clear.
  void _scratched(Offset p, Offset dir, int fresh) {
    _seq++;
    final nrm = Offset(-dir.dy, dir.dx);
    // Ragged edges: small bites just past the brush on either side.
    for (var j = 0; j < 2; j++) {
      final h1 = _hash(_seq * 3.1 + j), h2 = _hash(_seq * 5.7 + j * 2.3);
      final side = j == 0 ? 1.0 : -1.0;
      _dabs.add((p + nrm * side * (_brush / 2 - 1 + 3 * h1), 1.6 + 2.6 * h2));
    }
    if (fresh > 0) {
      Haptics.i.pulse(widget.buzz * (0.44 + 0.22 * _hash(_seq * 0.37)), ms: 12, gapMs: 22);
      if (!_reduced) _shed(p, dir, fresh > 10 ? 2 : 1);
    }
    _repaint.value++;
    if (_cov >= widget.need) _complete(at: p);
  }

  /// Shavings flicked off ahead of the scratch.
  void _shed(Offset p, Offset dir, int count) {
    final host = _host();
    final box = _box;
    if (host == null || box == null) return;
    for (var j = 0; j < count; j++) {
      double h(int k) => _hash(_seq * 7.13 + j * 31.7 + k * 3.31);
      final sp = 70 + 170 * h(1), side = (h(2) - 0.5) * 210;
      final v = Offset(dir.dx * sp - dir.dy * side, dir.dy * sp + dir.dx * side - 110 * h(3));
      final at = p + dir * 10 + Offset(-dir.dy, dir.dx) * ((h(9) - 0.5) * 16);
      final g = (150 + 95 * h(6)).round();
      host.addShaving(_Shaving(
        p0: host.toLocal(box, at),
        v: v,
        w: 2.5 + 4 * h(4),
        h: 1.4 + 1.8 * h(5),
        rot0: h(7) * math.pi * 2,
        spin: (h(8) - 0.5) * 26,
        color: Color.fromARGB(255, g, g, g),
      ));
    }
  }

  // ---------------------------------------------------------------- revealing

  void _complete({Offset? at, bool all = false, bool notify = true}) {
    if (_done) return;
    if (_grid.isEmpty) _ensureGrid();
    _done = true;
    _pointer = null;
    _last = null;
    _syncSheen();
    final origin = at ?? _size.center(Offset.zero);
    if (_reduced) {
      _fade.forward();
    } else {
      _breakUp(origin, all);
      _fade.value = 1;
      _pop.forward(from: 0);
    }
    // The rest of the foil crumbling: five quick buzzes, fading.
    const at0 = [0, 50, 100, 160, 230];
    for (var i = 0; i < at0.length; i++) {
      final s = widget.buzz * (1 - i * 0.17);
      if (at0[i] == 0) {
        Haptics.i.pulse(s, ms: 16);
      } else {
        Timer(Duration(milliseconds: at0[i]), () => Haptics.i.pulse(s, ms: 16));
      }
    }
    _repaint.value++;
    if (notify) {
      setState(() {});
      if (!widget.revealed) widget.onReveal();
    }
  }

  /// What is left of the foil lifts off in flakes, the nearest to the finger first.
  void _breakUp(Offset origin, bool all) {
    final host = _host();
    final box = _box;
    if (host == null || box == null || _size.isEmpty) return;
    final fx = (_size.width / _flake).ceil(), fy = (_size.height / _flake).ceil();
    final panel = host.toLocal(box, Offset.zero) & _size;
    final o = host.toLocal(box, origin);
    for (var y = 0; y < fy; y++) {
      for (var x = 0; x < fx; x++) {
        var n = 0, on = 0;
        for (var gy = y * 2; gy < math.min(_gy, y * 2 + 2); gy++) {
          for (var gx = x * 2; gx < math.min(_gx, x * 2 + 2); gx++) {
            n++;
            on += _grid[gy * _gx + gx];
          }
        }
        if (!all && n > 0 && on / n >= 0.5) continue;
        final left = x * _flake, top = y * _flake;
        final w = math.min(_flake + 1, _size.width - left), hh = math.min(_flake + 1, _size.height - top);
        if (w <= 0 || hh <= 0) continue;
        final cell = Rect.fromLTWH(panel.left + left, panel.top + top, w, hh);
        final k = (y * fx + x).toDouble();
        host.addFlake(_Flake(
          cell: cell,
          panel: panel,
          origin: o,
          delay: (cell.center - o).distance / 1800 + _hash(k + 50) * 0.03,
          seed: k,
        ));
      }
    }
  }

  _Debris? _host() {
    final overlay = Overlay.maybeOf(context);
    return overlay == null ? null : _Debris.of(overlay);
  }

  // ---------------------------------------------------------------- drawing

  /// The foil itself (silver, a fine hatch and a faint rim), drawn once per size.
  ui.Picture _foilAt(Size size) {
    if (_foil != null && _foilSize == size) return _foil!;
    _foil?.dispose();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    c.drawRRect(rr, Paint()..shader = _silverShader(rect));
    c.save();
    c.clipRRect(rr);
    const a = 35 * math.pi / 180;
    final d = Offset(math.cos(a), math.sin(a)), n = Offset(-d.dy, d.dx);
    final reach = size.width + size.height;
    final hatch = Paint()
      ..color = const Color(0x12000000)
      ..strokeWidth = 1.2;
    for (var k = -reach; k < reach; k += 4) {
      final o = rect.center + n * k;
      c.drawLine(o - d * reach, o + d * reach, hatch);
    }
    c.restore();
    c.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x1F000000),
    );
    _foil = rec.endRecording();
    _foilSize = size;
    return _foil!;
  }

  @override
  Widget build(BuildContext context) {
    Widget answer = ExcludeSemantics(excluding: !_done && !widget.revealed, child: widget.child);
    if (!_reduced) {
      answer = AnimatedBuilder(
        animation: _pop,
        builder: (context, child) {
          final t = const Interval(0.28, 1).transform(_pop.value);
          return Transform.scale(scale: 1 + 0.05 * math.sin(math.pi * t), child: child);
        },
        child: answer,
      );
    }
    final paint = CustomPaint(
      painter: _FoilPainter(
        foil: _foilAt,
        paths: _paths,
        dabs: _dabs,
        cov: () => _cov,
        fade: _fade,
        sheen: _sheen,
        sheenOn: () => _sheen.isAnimating,
        print: _print,
        repaint: Listenable.merge([_repaint, _fade, _sheen]),
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: widget.minHeight),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          answer,
          Positioned.fill(
            child: _done
                ? IgnorePointer(child: paint)
                : Semantics(
                    button: true,
                    label: 'Scratch to reveal the answer',
                    onTap: () => _complete(all: true),
                    child: Listener(
                      onPointerDown: _down,
                      onPointerMove: _move,
                      onPointerUp: _up,
                      onPointerCancel: _up,
                      // Claims the drag, so the card stays put while you scratch.
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) {},
                        onPanUpdate: (_) {},
                        onPanEnd: (_) {},
                        child: paint,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FoilPainter extends CustomPainter {
  _FoilPainter({
    required this.foil,
    required this.paths,
    required this.dabs,
    required this.cov,
    required this.fade,
    required this.sheen,
    required this.sheenOn,
    required this.print,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final ui.Picture Function(Size) foil;
  final List<Path> paths;
  final List<(Offset, double)> dabs;
  final double Function() cov;
  final Animation<double> fade;
  final Animation<double> sheen;
  final bool Function() sheenOn;
  final TextPainter? print;

  @override
  void paint(Canvas canvas, Size size) {
    final op = 1 - fade.value;
    if (op <= 0 || size.isEmpty) return;
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.saveLayer(rect.inflate(2), Paint()..color = Color.fromRGBO(0, 0, 0, op));
    canvas.drawPicture(foil(size));

    // The print, fading as the panel clears: a coin and "Scratch to reveal".
    final pOp = _c01(1 - cov() * 4);
    final tp = print;
    if (pOp > 0 && tp != null) {
      final total = 16 + 8 + tp.width;
      final x = (size.width - total) / 2, cy = size.height / 2;
      canvas.saveLayer(rect, Paint()..color = Color.fromRGBO(0, 0, 0, pOp));
      final coin = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF6B6B6B);
      canvas.drawCircle(Offset(x + 8, cy), 8, coin..strokeWidth = 2);
      canvas.drawCircle(Offset(x + 8, cy), 4, coin..strokeWidth = 1.2);
      tp.paint(canvas, Offset(x + 24, cy - tp.height / 2));
      canvas.restore();
    }

    // A glint now and then across untouched foil.
    if (sheenOn() && sheen.value > 0.48) {
      final t = Curves.easeInOut.transform((sheen.value - 0.48) / 0.52);
      const k = 0.325, bw = 46.0;
      final h = size.height, x = -60 + (size.width + 140) * t;
      final band = Path()
        ..moveTo(x, 0)
        ..lineTo(x + bw, 0)
        ..lineTo(x + bw - k * h, h)
        ..lineTo(x - k * h, h)
        ..close();
      canvas.save();
      canvas.clipRRect(rr);
      canvas.drawPath(
        band,
        Paint()
          ..shader = ui.Gradient.linear(Offset(x - k * h / 2, 0), Offset(x + bw - k * h / 2, 0),
              const [Color(0x00FFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)], const [0, 0.5, 1]),
      );
      canvas.restore();
    }

    // The scratches.
    final clear = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = _brush
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final p in paths) {
      canvas.drawPath(p, clear);
    }
    final bite = Paint()..blendMode = BlendMode.clear;
    for (final (p, r) in dabs) {
      canvas.drawCircle(p, r, bite);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoilPainter old) => true;
}

// ---------------------------------------------------------------- shavings and flakes

class _Shaving {
  _Shaving({required this.p0, required this.v, required this.w, required this.h, required this.rot0, required this.spin, required this.color});
  final Offset p0, v;
  final double w, h, rot0, spin;
  final Color color;
  double born = 0;

  static const life = 1.05;

  bool dead(double now) => now - born > life;

  void paint(Canvas canvas, double now) {
    final s = now - born;
    if (s < 0) return;
    final dr = (1 - math.exp(-2.4 * s)) / 2.4;
    final at = p0 + v * dr + Offset(0, 650 * s * s);
    final op = 1 - _c01((s - 0.6) / 0.45);
    if (op <= 0) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(rot0 + spin * s);
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), const Radius.circular(1));
    canvas.drawRRect(r.shift(const Offset(0, 1)), Paint()..color = Color.fromRGBO(0, 0, 0, 0.25 * op));
    canvas.drawRRect(r, Paint()..color = color.withValues(alpha: op));
    canvas.restore();
  }
}

class _Flake {
  _Flake({required this.cell, required this.panel, required this.origin, required this.delay, required this.seed});

  /// Where the flake sat on the foil, the whole foil, and where the finger was when it broke.
  final Rect cell, panel;
  final Offset origin;
  final double delay, seed;
  double born = 0;

  double _h(int k) => _hash(seed * 5.77 + k * 2.9);

  bool dead(double now) => now - born - delay - 0.08 > 0.72;

  void paint(Canvas canvas, double now) {
    final lu = now - born - delay;
    var tx = 0.0, ty = 0.0, rot = 0.0, s = 1.0, op = 1.0;
    final jag = lu > 0;
    if (jag) {
      final lift = _eo3(lu / 0.1), t2 = math.max(0.0, lu - 0.08);
      final vx = (cell.center.dx - origin.dx) * 1.3 + (_h(1) - 0.5) * 90;
      final vy = -(70 + 150 * _h(2)) + (cell.center.dy - origin.dy) * 0.8;
      tx = vx * t2;
      ty = vy * t2 + 850 * t2 * t2;
      rot = ((_h(3) - 0.5) * 760 * t2 + (_h(4) - 0.5) * 14 * lift) * math.pi / 180;
      s = 1 + 0.1 * lift - 0.3 * _c01(t2 / 0.7);
      op = 1 - _c01((t2 - 0.42) / 0.3);
    }
    if (op <= 0) return;
    final c = cell.center;
    canvas.save();
    canvas.translate(c.dx + tx, c.dy + ty);
    canvas.rotate(rot);
    canvas.scale(s);
    canvas.translate(-c.dx, -c.dy);
    // Torn once it lifts: each corner nibbled in a little.
    final j = jag ? 2.5 : 0.0;
    final poly = Path()
      ..moveTo(cell.left + j * _h(5), cell.top + j * _h(6))
      ..lineTo(cell.right - j * _h(7), cell.top + j * _h(8))
      ..lineTo(cell.right - j * _h(9), cell.bottom - j * _h(10))
      ..lineTo(cell.left + j * _h(11), cell.bottom - j * _h(12))
      ..close();
    canvas.clipRRect(RRect.fromRectAndRadius(panel, const Radius.circular(12)));
    canvas.drawPath(poly, Paint()..shader = _silverShader(panel)..color = Color.fromRGBO(0, 0, 0, op));
    // It catches the light as it turns.
    final glint = 0.22 * (math.sin(rot * 2)).abs() * op;
    if (glint > 0.01) canvas.drawPath(poly, Paint()..color = Color.fromRGBO(255, 255, 255, glint));
    canvas.restore();
  }
}

/// The air above the screen: shavings and flakes fly here, over everything and past the card's edge, and
/// keep falling after the card has moved on. One per overlay; it leaves the overlay when the last bit lands.
class _Debris extends ChangeNotifier {
  _Debris._(this.overlay);
  final OverlayState overlay;

  static final Map<OverlayState, _Debris> _all = {};
  static _Debris of(OverlayState overlay) => _all.putIfAbsent(overlay, () => _Debris._(overlay));

  final List<_Shaving> _shavings = [];
  final List<_Flake> _flakes = [];
  OverlayEntry? _entry;

  /// Seconds on this layer's clock (it runs while anything is in the air).
  double now = 0;
  double _base = 0;

  Offset toLocal(RenderBox box, Offset p) {
    final ob = overlay.context.findRenderObject();
    return ob is RenderBox ? box.localToGlobal(p, ancestor: ob) : box.localToGlobal(p);
  }

  void addShaving(_Shaving s) {
    if (_shavings.length > 90) _shavings.removeAt(0);
    _shavings.add(s..born = now);
    _show();
  }

  void addFlake(_Flake f) {
    _flakes.add(f..born = now);
    _show();
  }

  void _show() {
    if (_entry == null) {
      _base = now;
      _entry = OverlayEntry(builder: (_) => _DebrisLayer(debris: this));
      overlay.insert(_entry!);
    }
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    now = _base + elapsed.inMicroseconds / 1e6;
    _shavings.removeWhere((s) => s.dead(now));
    _flakes.removeWhere((f) => f.dead(now));
    if (_shavings.isEmpty && _flakes.isEmpty) {
      _entry?.remove();
      _entry = null;
      if (_all[overlay] == this) _all.remove(overlay);
      return;
    }
    notifyListeners();
  }

  void paint(Canvas canvas) {
    for (final f in _flakes) {
      f.paint(canvas, now);
    }
    for (final s in _shavings) {
      s.paint(canvas, now);
    }
  }
}

class _DebrisLayer extends StatefulWidget {
  const _DebrisLayer({required this.debris});
  final _Debris debris;

  @override
  State<_DebrisLayer> createState() => _DebrisLayerState();
}

class _DebrisLayerState extends State<_DebrisLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(widget.debris._tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(size: Size.infinite, painter: _DebrisPainter(widget.debris)),
        ),
      );
}

class _DebrisPainter extends CustomPainter {
  _DebrisPainter(this.debris) : super(repaint: debris);
  final _Debris debris;

  @override
  void paint(Canvas canvas, Size size) => debris.paint(canvas);

  @override
  bool shouldRepaint(_DebrisPainter old) => old.debris != debris;
}
