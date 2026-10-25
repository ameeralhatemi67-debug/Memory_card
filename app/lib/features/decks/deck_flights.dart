import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/models.dart' show DeckSkin;
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/theme.dart';
import '../shell/nav_bar.dart';
import 'deck_motion.dart';
import 'deck_row.dart';

/// Everything a flight needs to draw the deck bar it carries.
class FlightDeck {
  const FlightDeck({
    required this.id,
    required this.name,
    required this.meta,
    required this.steps,
    required this.skin,
    this.pinned = false,
  });

  final String id;
  final String name;
  final String meta;
  final int steps;
  final DeckSkin? skin;
  final bool pinned;
}

/// Puts [build]'s widget in the root overlay (above the list, the nav bar and the toasts' stack order at the time),
/// and removes it when the widget calls the callback it is given.
void startFlight(BuildContext context, Widget Function(VoidCallback done) build) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => build(() {
      if (entry.mounted) entry.remove();
    }),
  );
  overlay.insert(entry);
}

/// A clock for a short animation that outlives the row that started it.
abstract class _FlightState<W extends StatefulWidget> extends State<W> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double t = 0;
  bool _finished = false;

  double get total;
  VoidCallback get done;

  /// Called every frame, before the frame is drawn, with the previous and the new time.
  void onFrame(double from, double to) {}

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      final nt = d.inMicroseconds / 1e6;
      onFrame(t, nt);
      if (!mounted) return;
      setState(() => t = nt);
      if (nt >= total && !_finished) {
        _finished = true;
        _ticker.stop();
        done();
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  bool crossed(double from, double to, double at) => from < at && to >= at;
}

List<BoxShadow> _liftShadow(double lift, bool dark) {
  final a = 0.18 + lift * 0.1;
  return [
    BoxShadow(color: Colors.black.withValues(alpha: a), blurRadius: 14 + lift * 16, offset: Offset(0, 6 + lift * 9)),
    if (dark && lift > 0.02) BoxShadow(color: const Color(0xFFF1F1F1).withValues(alpha: lift * 0.1), blurRadius: lift * 20),
  ];
}

/// The deck bar as it is carried: [face], lifted (shadow level [lift], 0…2) and squashed/rotated about
/// [alignment].
Widget _carried({
  required Widget face,
  required double lift,
  required double rot,
  required double sx,
  required double sy,
  required bool dark,
  Alignment alignment = Alignment.center,
}) {
  return Transform(
    alignment: alignment,
    transform: Matrix4.identity()
      ..rotateZ(rot)
      ..scaleByDouble(sx, sy, 1, 1),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: _liftShadow(lift, dark)),
          ),
        ),
        face,
      ],
    ),
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Delete A: the burst.

class BurstFlight extends StatefulWidget {
  const BurstFlight({super.key, required this.center, required this.barWidth, required this.onDone});
  final Offset center;
  final double barWidth;
  final VoidCallback onDone;

  @override
  State<BurstFlight> createState() => _BurstFlightState();
}

class _BurstFlightState extends _FlightState<BurstFlight> {
  @override
  double get total => 1.05;
  @override
  VoidCallback get done => widget.onDone;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: BurstPainter(u: t, center: widget.center, barWidth: widget.barWidth, ink: mc.ink, muted: mc.muted),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Archive B "Snap-in".

class ArchiveFlight extends StatefulWidget {
  const ArchiveFlight({
    super.key,
    required this.deck,
    required this.rest,
    required this.start,
    required this.count,
    required this.onRelease,
    required this.onDone,
  });

  final FlightDeck deck;

  /// The bar's place in the list with the swipe closed, and where it is right now (swiped open), in screen
  /// coordinates.
  final Rect rest;
  final Rect start;

  /// How many decks the archive holds once this one is in.
  final int count;

  /// The deck leaves the list (the others close the gap).
  final VoidCallback onRelease;
  final VoidCallback onDone;

  @override
  State<ArchiveFlight> createState() => _ArchiveFlightState();
}

class _ArchiveFlightState extends _FlightState<ArchiveFlight> {
  static const _rise = 30.0, _g = 7500.0, _tf = 0.5;
  bool _released = false, _hit = false;
  late double _lipBottom, _lipTop, _trayTop, _restTop, _dist, _df, _tEnd;
  double _screenH = 800;
  bool _geom = false;

  @override
  double get total => _tEnd + 0.2 + 0.35 + 0.05;
  @override
  VoidCallback get done => widget.onDone;

  void _measure(BuildContext context) {
    if (_geom) return;
    _geom = true;
    final mq = MediaQuery.of(context);
    _screenH = mq.size.height;
    _lipBottom = mq.size.height - NavBar.height - mq.padding.bottom - 58;
    _lipTop = _lipBottom - 50;
    _trayTop = _lipBottom - 78;
    _restTop = _lipTop - 40;
    final d = _restTop - widget.rest.top;
    _dist = math.max(d + _rise + 3, 48);
    _df = math.sqrt(2 * _dist / _g);
    _tEnd = _tf + _df + 0.18 + 0.24;
  }

  @override
  void onFrame(double from, double to) {
    if (!_geom) return;
    if (!_released && to >= _tf + 0.06) {
      _released = true;
      widget.onRelease();
    }
    if (!_hit && to >= _tf + _df) {
      _hit = true;
      Fx.i.thud();
    }
  }

  @override
  Widget build(BuildContext context) {
    _measure(context);
    final mc = Mc.of(context);
    final w = widget.rest.width;
    final k = 1 - Mo.eo3((t - 0.02) / 0.3);
    var lift = 2 * Mo.eo3((t - 0.1) / 0.22);
    var y = 3 * (1 - Mo.eo3(t / 0.1)) - (3 + _rise) * Mo.ebk((t - 0.1) / 0.24, 2.2);
    var sx = 1.0, sy = 1.0, op = 1.0;
    if (t < 0.1) {
      final a = Mo.eo3(t / 0.1);
      sy = 1 - 0.06 * a;
      sx = 1 + 0.03 * a;
    } else if (t < 0.34) {
      final q = (t - 0.1) / 0.24;
      final sn = math.sin(math.pi * math.min(1.0, q * 1.2));
      sy = 0.94 + 0.13 * sn + 0.06 * q;
      sx = 1.03 - 0.04 * math.sin(math.pi * q) + 0.01 * q;
    } else {
      sx = sy = 1.05;
    }
    var rot = -4 * Mo.eo3((t - 0.16) / 0.3);
    var bump = 0.0;
    var pop = 0.0;
    var counted = false;
    if (t >= _tf) {
      final tau = t - _tf;
      rot = -4 * (1 - Mo.c01(tau / _df));
      sx = sy = 1.05;
      if (tau < _df) {
        final q = tau / _df;
        y = -_rise - 3 + _dist * q * q;
      } else {
        final u = tau - _df;
        final imp = math.exp(-14 * u);
        y = _restTop - widget.rest.top + 10 * math.exp(-10 * u) * math.sin(18 * u);
        sy = 1 - 0.13 * imp;
        sx = 1 + 0.08 * imp;
        lift = 2 * Mo.c01(1 - u / 0.1);
        bump = 11 * math.exp(-8 * u) * math.sin(20 * u + 0.4);
        final us = u - 0.18;
        if (us > 0) {
          y += 44 * Mo.ei3(us / 0.24);
          op = 1 - Mo.c01((us - 0.14) / 0.1);
        }
        if (u > 0.18) {
          counted = true;
          final pt = u - 0.18;
          pop = 0.12 * math.exp(-12 * pt) * math.sin(24 * pt + 1);
        }
      }
    }
    final x = widget.rest.left + (widget.start.left - widget.rest.left) * k;
    final top = widget.rest.top + y;

    // The tray slides up from below the screen, stays while the deck goes in, and slides away again.
    final trayIn = 1 - Mo.eo3(t / 0.3);
    final trayOut = Mo.eo3((t - (_tEnd + 0.2)) / 0.35);
    final away = (trayIn + trayOut) * (_screenH - _trayTop + 30);
    final dy = away + bump;

    final face = DeckBarFace(
      id: widget.deck.id,
      name: widget.deck.name,
      meta: widget.deck.meta,
      steps: widget.deck.steps,
      pinned: widget.deck.pinned,
      skin: widget.deck.skin,
      width: w,
    );
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: widget.rest.left,
              top: _trayTop + dy,
              width: w,
              height: 78,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: mc.soft,
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, -0.1),
                    colors: [Colors.black.withValues(alpha: mc.dark ? 0.55 : 0.2), Colors.black.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            // The deck is clipped where it passes behind the tray's front lip.
            Positioned.fill(
              child: ClipRect(
                clipper: _CutBelow(_lipBottom + dy),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: x,
                      top: top,
                      width: w,
                      height: 72,
                      child: Opacity(
                        opacity: op.clamp(0.0, 1.0),
                        child: _carried(face: face, lift: lift, rot: rot * math.pi / 180, sx: sx, sy: sy, dark: mc.dark, alignment: Alignment.bottomRight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: widget.rest.left,
              top: _lipTop + dy,
              width: w,
              height: 50,
              child: Transform.scale(
                scale: 1 + pop,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: mc.well,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    border: Border(top: BorderSide(color: mc.ink.withValues(alpha: 0.16), width: 2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      McIcon(McIcons.archive, size: const Size(14, 15), color: mc.ink),
                      const SizedBox(width: 8),
                      Text(
                        'Archived · ${counted ? widget.count : widget.count - 1}',
                        style: T.t(15, w: FontWeight.w700, color: mc.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Pin A "Press from above".

class PinFlight extends StatefulWidget {
  const PinFlight({
    super.key,
    required this.deck,
    required this.rest,
    required this.start,
    required this.end,
    required this.onRelease,
    required this.onDone,
  });

  final FlightDeck deck;
  final Rect rest;
  final Rect start;

  /// Where the bar lands: its place in the list once pinned. Known a frame after [onRelease].
  final ValueListenable<Rect?> end;

  /// The store pins the deck and the others make room.
  final VoidCallback onRelease;
  final VoidCallback onDone;

  @override
  State<PinFlight> createState() => _PinFlightState();
}

class _PinFlightState extends _FlightState<PinFlight> {
  bool _released = false, _hit = false;

  @override
  double get total => 2.0;
  @override
  VoidCallback get done => widget.onDone;

  @override
  void onFrame(double from, double to) {
    if (!_released && to >= 0.34) {
      _released = true;
      widget.onRelease();
    }
    if (!_hit && to >= 1.25) {
      _hit = true;
      Fx.i.thud();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final w = widget.rest.width;
    final end = widget.end.value ?? widget.rest;
    final k = 1 - Mo.eo3(t / 0.3);
    var lift = 2 * Mo.eo3(t / 0.32);
    var sc = 1 + 0.03 * lift;
    final s = Mo.eio((t - 0.34) / 0.62);
    final rot = -2.2 * math.sin(math.pi * s) * math.pi / 180;
    final x = widget.rest.left + (widget.start.left - widget.rest.left) * k;
    var top = Mo.lerp(widget.rest.top, end.top, s);
    var sy = sc;
    var shift = 0.0;
    var rings = <(double, double)>[];
    var pressK = 1.0;
    // The pin comes down along the z axis: big and blurred up near you, then smaller and sharper until it presses in.
    double? pinH;
    double pinOp = 0, pinS = 1, pinDx = 0, pinDy = 0;
    if (t >= 0.78) {
      final q = Mo.c01((t - 0.78) / 0.47);
      final h = 1 - q * q;
      pinH = h;
      pinS = 1 + 3.2 * h;
      pinOp = Mo.c01((t - 0.78) / 0.08);
      pinDx = 16 * h;
      pinDy = -22 * h;
    }
    final u = t - 1.25;
    if (u >= 0) {
      top += 3.5 * math.exp(-10 * u) * math.cos(14 * u);
      sy = sc * (1 - 0.012 * math.exp(-10 * u));
      lift = 2 * Mo.c01(1 - u / 0.18);
      pressK = 1 - 0.16 * math.exp(-9 * u) * math.cos(16 * u);
      rings = [(8 + 70 * Mo.eo3(u / 0.5), u < 0.5 ? 0.55 * (1 - u / 0.5) : 0.0)];
      shift = 21 * Mo.spr(u + 0.05, 0.7, 16);
    }
    final face = DeckBarFace(
      id: widget.deck.id,
      name: widget.deck.name,
      meta: widget.deck.meta,
      steps: widget.deck.steps,
      pinned: false,
      skin: widget.deck.skin,
      width: w,
      titleShift: shift,
    );
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: x,
              top: top,
              width: w,
              height: 72,
              child: _carried(
                face: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    face,
                    if (rings.isNotEmpty)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CustomPaint(painter: RipplePainter(rings, const Offset(16 + 7.5, 23), Mc.green)),
                        ),
                      ),
                    if (pinH != null) _pin(pinH, pinS * pressK, pinOp, pinDx, pinDy),
                  ],
                ),
                lift: lift,
                rot: rot,
                sx: sc,
                sy: sy,
                dark: mc.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The pushpin: its tip is the point it lands on (the pin icon's own place in a pinned deck's title), and the head
  /// rises toward you as it is lifted, with a shadow that falls further away the higher it is.
  Widget _pin(double h, double scale, double op, double dx, double dy) {
    const size = Size(15, 15);
    const tip = Alignment(-0.94, 0.92);
    Widget glyph(Color c) => McIcon(McIcons.pin, size: size, color: c);
    Matrix4 m() => Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    return Positioned(
      left: 16,
      top: 15.6,
      width: size.width,
      height: size.height,
      child: Opacity(
        opacity: op,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(h * 12 + 1, h * 20 + 2),
              child: Transform(
                alignment: tip,
                transform: m(),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: h * 4 + 0.5, sigmaY: h * 4 + 0.5),
                  child: Opacity(opacity: 0.3 + 0.2 * h, child: glyph(Colors.black)),
                ),
              ),
            ),
            Transform(alignment: tip, transform: m(), child: glyph(Mc.green)),
          ],
        ),
      ),
    );
  }
}

/// Shows only what is above [bottom] (the deck goes in behind the tray's front lip).
class _CutBelow extends CustomClipper<Rect> {
  const _CutBelow(this.bottom);
  final double bottom;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, size.width, math.min(size.height, bottom));

  @override
  bool shouldReclip(_CutBelow old) => old.bottom != bottom;
}
