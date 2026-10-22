import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../engine/study_engine.dart';
import '../../data/store_scope.dart';
import '../../ui/coach.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';

/// Which deck row is swiped open (only one at a time).
final openDeck = ValueNotifier<String?>(null);

/// Stepped swipe detents (text_Mockup §3, RES-02/RES-03): option 1 at 65px, option 2 at 125px.
const _step1 = 65.0;
const _step2 = 125.0;
const _span2 = _step2 - _step1;
const _gap = 10.0;
const _margin = 20.0;

/// Finger → open distance. The bar follows the finger 1:1 up to the second detent (the springs on
/// release do the snapping), then stretches like a rubber band that stiffens smoothly: the slope starts
/// at 1 and falls off, so there is no jump anywhere along the drag.
double gravity(double raw) {
  final a = raw.abs();
  if (a <= _step2) return a;
  const give = 26.0;
  return _step2 + give * (1 - math.exp(-(a - _step2) / give));
}

/// The inverse of [gravity], to resume a drag from wherever the bar is.
double _ungravity(double e) {
  if (e <= _step2) return e;
  const give = 26.0;
  final f = ((e - _step2) / give).clamp(0.0, 0.999);
  return _step2 - give * math.log(1 - f);
}

/// One deck bar: ink bar with the title, meta line and the stepped progress fan; swipe left for
/// Delete / Archive, right for Move / Pin.
class DeckRow extends StatefulWidget {
  const DeckRow({
    super.key,
    required this.deck,
    required this.stats,
    required this.onOpen,
    required this.onDelete,
    required this.onArchive,
    required this.onMove,
    required this.onPin,
    this.archived = false,
    this.demo = false,
    this.highlight = false,
  });

  final Deck deck;
  final DeckStats stats;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onMove;
  final VoidCallback onPin;
  final bool archived;

  /// Plays the "this swipes" hint once (first visit).
  final bool demo;

  /// A deck that was just added glows in.
  final bool highlight;

  @override
  State<DeckRow> createState() => _DeckRowState();
}

class _DeckRowState extends State<DeckRow> with TickerProviderStateMixin {
  double _e = 0; // extent of the open side
  int _dir = 0; // -1 open to the left (delete side), 1 to the right (move side)
  double _raw = 0;
  bool _dragging = false;
  bool _passedStep = false;
  Ticker? _spring;
  String? _removing; // 'delete' | 'archive'
  late final AnimationController _remove = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    openDeck.addListener(_onOpenChanged);
    if (widget.demo) _playDemo();
    if (widget.highlight) _glow.forward();
  }

  @override
  void dispose() {
    openDeck.removeListener(_onOpenChanged);
    _spring?.dispose();
    _remove.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _onOpenChanged() {
    if (openDeck.value != widget.deck.id && _e > 0 && !_dragging) _animateTo(0, overshoot: false);
  }

  Future<void> _playDemo() async {
    final store = context.storeRead;
    await Future.delayed(const Duration(milliseconds: 1100));
    // One lesson at a time: a first-visit coach mark on this screen goes first.
    for (var i = 0; i < 30 && mounted; i++) {
      if (CoachTarget.active.value == null && store.coachSeen('drawer')) break;
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted || _dragging) return;
    _dir = -1;
    _animateTo(_step1, overshoot: true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted || _dragging) return;
    _animateTo(0, overshoot: false);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || _dragging) return;
    _dir = 1;
    _animateTo(_step1, overshoot: true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted || _dragging) return;
    _animateTo(0, overshoot: false);
  }

  /// Spring engine from the canvas: opening overshoots +12px, closing past a detent squashes −9px.
  void _animateTo(double target, {required bool overshoot}) {
    _spring?.dispose();
    var cur = _e;
    var vel = 0.0;
    var over = target;
    if (overshoot) {
      if (target > cur) {
        over = target + 12;
      } else if (cur > target + 1) {
        over = target - 9;
      }
    }
    var phase = overshoot && (over - target).abs() > 1 ? 0 : 1;
    Duration last = Duration.zero;
    _spring = createTicker((elapsed) {
      // Step the original 60 fps physics, whatever the display rate.
      final frames = ((elapsed - last).inMicroseconds / 16667).clamp(0.0, 4.0);
      last = elapsed;
      var steps = frames;
      while (steps > 0) {
        final k = math.min(1.0, steps);
        final dest = phase == 0 ? over : target;
        vel = (vel + (dest - cur) * 0.16 * k) * math.pow(0.74, k).toDouble();
        cur += vel * k;
        steps -= 1;
      }
      if (phase == 0 && (cur - over).abs() < 1.2) phase = 1;
      if (phase == 1 && (cur - target).abs() < 0.3 && vel.abs() < 0.15) {
        _spring?.stop();
        setState(() {
          _e = target;
          if (target == 0) _dir = 0;
        });
        return;
      }
      setState(() => _e = math.max(0, cur));
    })..start();
  }

  void _onStart(DragStartDetails d) {
    _spring?.stop();
    _dragging = true;
    _raw = _dir * _ungravity(_e);
    _passedStep = _e >= _step1;
    if (openDeck.value != widget.deck.id) openDeck.value = widget.deck.id;
  }

  void _onUpdate(DragUpdateDetails d) {
    _raw += d.delta.dx;
    final dir = _raw < 0 ? -1 : 1;
    final e = gravity(_raw);
    final step = e >= _step1;
    if (step != _passedStep) {
      _passedStep = step;
      if (step) Fx.i.lock();
    }
    setState(() {
      _dir = dir;
      _e = e;
    });
  }

  void _onEnd(DragEndDetails d) {
    _dragging = false;
    final raw = _raw.abs();
    final v = d.velocity.pixelsPerSecond.dx;
    // A quick flick in the open direction advances one detent; against it, closes.
    if (v.abs() > 700 && (v.sign != _dir.sign || _dir == 0)) {
      _animateTo(0, overshoot: false);
      return;
    }
    if (raw <= _step1) {
      if (raw / _step1 < 0.5 && v.abs() < 700) {
        _animateTo(0, overshoot: false);
      } else {
        _animateTo(_step1, overshoot: true);
      }
    } else if ((raw - _step1) / _span2 < 0.5 && v.abs() < 700) {
      _animateTo(_step1, overshoot: false);
    } else {
      _animateTo(_step2, overshoot: true);
    }
  }

  void _close() {
    _animateTo(0, overshoot: false);
    if (openDeck.value == widget.deck.id) openDeck.value = null;
  }

  Future<void> _removeThen(String kind, VoidCallback action) async {
    setState(() => _removing = kind);
    Fx.i.pop();
    await _remove.forward();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final reduced = MotionPrefs.reducedOf(context);
    final width = MediaQuery.of(context).size.width;
    final barW = math.min(width - 2 * _margin, 520.0);
    final e = _e < 0.5 ? 0.0 : _e;
    final dir = e == 0 ? 0 : _dir;
    final excess = math.max(0.0, e - _step2);
    final second = e <= _step1 ? 0.0 : math.min(65.0, e - _step1) + excess * 0.45;
    final progress = e / _step1;
    final sinkOp = math.min(1.0, progress * 1.5);
    final stop = math.max(0.0, 1 - progress * 0.2);
    // The bar moves from the first pixel (half speed at first) and settles to keeping a _gap from the
    // tile as it opens, with no dead zone.
    final double tx = dir == 0 ? 0.0 : dir.toDouble() * (e - (_margin - _gap) * (1 - math.exp(-e / 20)));

    final s = widget.stats;
    final status = s.slipping > 0
        ? '${s.slipping} slipping'
        : s.fresh == s.total
        ? 'new'
        : s.fresh > 0
        ? '${s.fresh} still new'
        : 'all strong';
    final meta = '${s.total} ${s.total == 1 ? 'card' : 'cards'} · $status';

    Widget tile(
      Color color,
      String icon,
      Size size,
      double w, {
      required bool left,
      double iconW = 65,
      VoidCallback? onTap,
      String? label,
      bool top = false,
    }) {
      return Positioned(
        top: 0,
        bottom: 0,
        left: left ? 0 : null,
        right: left ? null : 0,
        width: w,
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: left
                    ? const BorderRadius.horizontal(right: Radius.circular(16))
                    : const BorderRadius.horizontal(left: Radius.circular(16)),
                boxShadow: top
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: Offset(left ? 3 : -3, 0),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.hardEdge,
              child: OverflowBox(
                alignment: top ? Alignment.center : (left ? Alignment.centerRight : Alignment.centerLeft),
                minWidth: iconW,
                maxWidth: math.max(iconW, w),
                child: SizedBox(
                  width: top ? math.max(iconW, w) : iconW,
                  child: Center(
                    child: McIcon(icon, size: size, color: Mc.graphite),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final bar = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _removing == null ? _onStart : null,
      onHorizontalDragUpdate: _removing == null ? _onUpdate : null,
      onHorizontalDragEnd: _removing == null ? _onEnd : null,
      onTap: () {
        if (e > 0) {
          _close();
        } else {
          Fx.i.tap();
          widget.onOpen();
        }
      },
      child: Transform.translate(
        offset: Offset(tx, 0),
        child: AnimatedBuilder(
          animation: _glow,
          builder: (context, child) {
            final g = _glow.isAnimating ? math.sin(_glow.value * math.pi) : 0.0;
            return Container(
              width: barW,
              height: 72,
              decoration: BoxDecoration(
                color: mc.ink,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  ...mc.e1,
                  if (g > 0)
                    BoxShadow(
                      color: Mc.peach.withValues(alpha: 0.55 * g),
                      blurRadius: 18 * g,
                      spreadRadius: 2 * g,
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            );
          },
          child: Stack(
            children: [
              // Now and then the fan riffles: back to front, each card lifts and leans for a moment.
              Positioned.fill(
                child: Pulse(
                  delayMs: 1400 + (widget.deck.id.hashCode.abs() % 7) * 450,
                  periodMs: const [8000, 9000, 10000][widget.deck.id.hashCode.abs() % 3],
                  durationMs: 1300,
                  builder: (context, t) => Stack(
                    children: [
                      for (var i = 0; i < 5; i++)
                        () {
                          final u = ((t * 1300 - i * 90) / 640).clamp(0.0, 1.0);
                          final lift = t == 0 ? 0.0 : math.sin(math.pi * Curves.easeInOut.transform(u));
                          return Positioned(
                            right: -10 + (4 - i) * 15.0,
                            bottom: -40 + i * 8.0 + lift * 4,
                            child: Transform.rotate(
                              alignment: Alignment.bottomRight,
                              angle: (-16 + i * 3 - lift * 3.5) * math.pi / 180,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                curve: McCurves.paper,
                                width: 54,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: i < s.steps ? mc.fanOn[i] : mc.fanOff,
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(-2, 0)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }(),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: 11,
                right: 112,
                child: Row(
                  children: [
                    if (widget.deck.pinned) ...[
                      McIcon(McIcons.pin, size: const Size(15, 15), color: Mc.green),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        widget.deck.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.d(23, color: mc.onInk, height: 1.05),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                bottom: 11,
                right: 112,
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.t(13, w: FontWeight.w500, color: mc.mutedOnInk, spacing: 0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final row = SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Delete / Archive (swiping left), flush to the right edge.
          if (dir < 0) ...[
            tile(
              Mc.delete,
              McIcons.x,
              const Size(20, 20),
              e,
              left: false,
              onTap: () => _removeThen('delete', widget.onDelete),
              label: 'Delete deck',
            ),
            if (second > 0)
              tile(
                Mc.peach,
                McIcons.archive,
                const Size(20, 22),
                second,
                left: false,
                top: true,
                onTap: () => _removeThen('archive', widget.onArchive),
                label: widget.archived ? 'Restore deck' : 'Archive deck',
              ),
          ],
          // Move / Pin (swiping right), flush to the left edge.
          if (dir > 0) ...[
            tile(
              Mc.blue,
              McIcons.move,
              const Size(24, 18),
              e,
              left: true,
              iconW: 58,
              onTap: () {
                _close();
                widget.onMove();
              },
              label: 'Move deck to another folder',
            ),
            if (second > 0)
              tile(
                Mc.green,
                McIcons.pin,
                const Size(22, 22),
                second,
                left: true,
                top: true,
                iconW: 54,
                onTap: () {
                  _close();
                  widget.onPin();
                },
                label: widget.deck.pinned ? 'Unpin deck' : 'Pin deck to the top',
              ),
          ],
          Positioned(left: (width - barW) / 2, top: 0, child: bar),
          // The trailing edge sinks into the canvas as the deck slides.
          if (dir != 0)
            Positioned(
              top: -1,
              bottom: -1,
              left: dir < 0 ? 0 : null,
              right: dir > 0 ? 0 : null,
              width: width / 2,
              child: IgnorePointer(
                child: Opacity(
                  opacity: sinkOp,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: dir < 0 ? Alignment.centerRight : Alignment.centerLeft,
                        end: dir < 0 ? Alignment.centerLeft : Alignment.centerRight,
                        colors: [mc.canvasClear, mc.canvas],
                        stops: [0, stop],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _remove,
      builder: (context, child) {
        final t = McCurves.paper.transform(_remove.value);
        if (_removing == null) return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
        final collapse = _removing == 'delete' || t > 0.6;
        return Opacity(
          opacity: 1 - t,
          child: Transform.translate(
            offset: Offset(_removing == 'archive' && !reduced ? -width * 1.1 * t : 0, 0),
            child: SizedBox(
              height: collapse ? 84 * (1 - t) : 84,
              child: ClipRect(
                child: OverflowBox(
                  maxHeight: 84,
                  alignment: Alignment.topCenter,
                  child: Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
                ),
              ),
            ),
          ),
        );
      },
      child: Semantics(
        label: '${widget.deck.name}, $meta. Swipe left to delete or archive, right to move or pin',
        child: row,
      ),
    );
  }
}
