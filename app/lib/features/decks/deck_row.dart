import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../data/models.dart';
import '../../engine/study_engine.dart';
import '../../data/store_scope.dart';
import '../../ui/coach.dart';
import '../../ui/deck_look.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/sink_mask.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';

/// Which deck row is swiped open (only one at a time).
final openDeck = ValueNotifier<String?>(null);

/// A deck bar's meta line: "24 cards · 3 slipping".
String deckMetaOf(DeckStats s) {
  final status = s.slipping > 0
      ? '${s.slipping} slipping'
      : s.fresh == s.total
      ? 'new'
      : s.fresh > 0
      ? '${s.fresh} still new'
      : 'all strong';
  return '${s.total} ${s.total == 1 ? 'card' : 'cards'} · $status';
}

/// Stepped swipe detents (text_Mockup §3, RES-02/RES-03): option 1 at 65px, option 2 at 125px.
const _step1 = 65.0;
const _step2 = 125.0;
const _span2 = _step2 - _step1;
const _gap = 10.0;
const _margin = 20.0;

/// Room above and below the bar inside the fade, so its soft shadow is not cut off while it slides.
const _shadowRoom = 24.0;

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
    this.skin,
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

  /// The deck's look (null = the plain ink bar).
  final DeckSkin? skin;

  @override
  State<DeckRow> createState() => _DeckRowState();
}

/// How far a deck bar is swiped open and to which side. A notifier, so that while the bar moves only the
/// parts that depend on it repaint.
class _Motion extends ChangeNotifier {
  double e = 0; // extent of the open side
  int dir = 0; // -1 open to the left (delete side), 1 to the right (move side)

  void update({double? e, int? dir}) {
    final ne = e ?? this.e, nd = dir ?? this.dir;
    if (ne == this.e && nd == this.dir) return;
    this.e = ne;
    this.dir = nd;
    notifyListeners();
  }
}

class _DeckRowState extends State<DeckRow> with TickerProviderStateMixin {
  /// The swipe's extent and side. A swipe repaints the bar's offset, the action tiles and the edge fade;
  /// the bar itself (text, fan, textures, shadows) is built once and kept as a cached layer.
  final _motion = _Motion();
  double get _e => _motion.e;
  int get _dir => _motion.dir;
  double _raw = 0;
  bool _dragging = false;
  bool _passedStep = false;
  double _target = 0;
  late final AnimationController _spring = AnimationController.unbounded(vsync: this)
    ..addListener(() => _motion.update(e: math.max(0.0, _spring.value)))
    ..addStatusListener(_onSpringStatus);
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
    _spring.dispose();
    _motion.dispose();
    _remove.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _onOpenChanged() {
    if (openDeck.value != widget.deck.id && _e > 0 && !_dragging) _animateTo(0);
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
    _motion.update(dir: -1);
    _animateTo(_step1, bounce: true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted || _dragging) return;
    _animateTo(0);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || _dragging) return;
    _motion.update(dir: 1);
    _animateTo(_step1, bounce: true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted || _dragging) return;
    _animateTo(0);
  }

  /// One real spring takes the bar from wherever it is (and however fast the finger was going) to a
  /// detent. Closing is critically damped: no wobble, no undershoot. Opening to a detent is a touch
  /// under-damped: it lands with one soft overshoot of a couple of pixels and settles, no more.
  void _animateTo(double target, {double velocity = 0, bool bounce = false}) {
    _target = target;
    _spring.stop();
    final from = _e;
    if ((from - target).abs() < 0.05 && velocity.abs() < 1) {
      _settle();
      return;
    }
    _spring.value = from;
    // A finger still moving away from the detent the bar is about to snap back to hands over only a
    // fraction of its speed, so the bar does not fly past before returning.
    if (velocity * (target - from) < 0) velocity *= 0.3;
    final spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 360, ratio: bounce ? 0.74 : 1.0);
    _spring.animateWith(
      SpringSimulation(spring, from, target, velocity, tolerance: const Tolerance(distance: 0.05, velocity: 1.5)),
    );
  }

  void _onSpringStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _settle();
  }

  /// Rests exactly on the target.
  void _settle() => _motion.update(e: _target, dir: _target == 0 ? 0 : _dir);

  void _onStart(DragStartDetails d) {
    _spring.stop();
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
    _motion.update(e: e, dir: dir);
  }

  void _onEnd(DragEndDetails d) {
    _dragging = false;
    final raw = _raw.abs();
    final v = d.velocity.pixelsPerSecond.dx;
    // How fast the bar's opening is changing as the finger lets go (positive = opening further): the
    // spring starts from that speed, so the bar carries on from the finger instead of restarting.
    final open = (_dir * v).clamp(-2500.0, 2500.0);
    // A quick flick in the open direction advances one detent; against it, closes.
    if (v.abs() > 700 && (v.sign != _dir.sign || _dir == 0)) {
      _animateTo(0, velocity: open);
      return;
    }
    if (raw <= _step1) {
      if (raw / _step1 < 0.5 && v.abs() < 700) {
        _animateTo(0, velocity: open);
      } else {
        _animateTo(_step1, velocity: open, bounce: true);
      }
    } else if ((raw - _step1) / _span2 < 0.5 && v.abs() < 700) {
      _animateTo(_step1, velocity: open);
    } else {
      _animateTo(_step2, velocity: open, bounce: true);
    }
  }

  /// A drag that the system took away (a call, the list scrolling): settle like a gentle release.
  void _onCancel() => _onEnd(DragEndDetails(velocity: Velocity.zero));

  void _close() {
    _animateTo(0);
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
    final reduced = MotionPrefs.reducedOf(context);
    final width = MediaQuery.of(context).size.width;
    final barW = math.min(width - 2 * _margin, 520.0);

    final s = widget.stats;
    final meta = deckMetaOf(s);

    Widget tile(
      String id,
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
        key: ValueKey('tile-$id'),
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

    // The bar itself: built once and kept as its own cached layer, so sliding it is only a change of
    // offset. Nothing in here depends on how far it is swiped.
    final barVisual = RepaintBoundary(
      key: ValueKey('deck-bar-${widget.deck.id}'),
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, _) => DeckBarFace(
          id: widget.deck.id,
          name: widget.deck.name,
          meta: meta,
          steps: s.steps,
          pinned: widget.deck.pinned,
          skin: widget.skin,
          width: barW,
          glow: _glow.isAnimating ? math.sin(_glow.value * math.pi) : 0.0,
        ),
      ),
    );

    // Everything that moves with the swipe, and only that.
    final row = SizedBox(
      height: 72,
      child: AnimatedBuilder(
        animation: _motion,
        child: barVisual,
        builder: (context, bar) {
          final e = _motion.e < 0.5 ? 0.0 : _motion.e;
          final dir = e == 0 ? 0 : _motion.dir;
          final excess = math.max(0.0, e - _step2);
          final second = e <= _step1 ? 0.0 : math.min(65.0, e - _step1) + excess * 0.45;
          final progress = e / _step1;
          final sinkOp = math.min(1.0, progress * 1.5);
          final stop = math.max(0.0, 1 - progress * 0.2);
          // The bar moves from the first pixel (half speed at first) and settles to keeping a _gap from
          // the tile as it opens, with no dead zone.
          final double tx = dir == 0 ? 0.0 : dir.toDouble() * (e - (_margin - _gap) * (1 - math.exp(-e / 20)));
          final left0 = (width - barW) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Delete / Archive (swiping left), flush to the right edge.
              if (dir < 0) ...[
                tile(
                  'delete',
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
                    'archive',
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
                  'move',
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
                    'pin',
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
              // The trailing edge sinks into the wall as the deck slides: the bar itself fades there (a mask
              // fixed to the screen while the bar moves under it), so the wall's texture shows through.
              // The mask is part of the tree at rest too (switched off), so a swipe never rebuilds the bar.
              Positioned(
                key: const ValueKey('bar'),
                left: 0,
                top: -_shadowRoom,
                child: SinkMask(
                  // The mask spans the whole row, so the bar sliding past its own box is faded too (a
                  // mask only as wide as the bar left a hard-edged strip of it un-faded at the screen edge).
                  shaderCallback: dir == 0
                      ? null
                      : (rect) => ui.Gradient.linear(
                            Offset(width / 2, 0),
                            Offset(width / 2 + ((dir < 0 ? 0.0 : width) - width / 2) * stop, 0),
                            [const Color(0xFF000000), Color.fromRGBO(0, 0, 0, 1 - sinkOp)],
                          ),
                  child: SizedBox(
                    width: width,
                    height: 72 + 2 * _shadowRoom,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: left0,
                          top: _shadowRoom,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: _removing == null ? _onStart : null,
                            onHorizontalDragUpdate: _removing == null ? _onUpdate : null,
                            onHorizontalDragEnd: _removing == null ? _onEnd : null,
                            onHorizontalDragCancel: _removing == null ? _onCancel : null,
                            onTap: () {
                              if (_motion.e > 0.5) {
                                _close();
                              } else {
                                Fx.i.tap();
                                widget.onOpen();
                              }
                            },
                            child: Transform.translate(offset: Offset(tx, 0), child: bar),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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

/// The face of a deck bar: the ink bar (or the deck's skin under a shade), the name, the meta line and the
/// stepped progress fan that riffles now and then. Also the deck maker's live preview.
class DeckBarFace extends StatelessWidget {
  const DeckBarFace({
    super.key,
    required this.id,
    required this.name,
    required this.meta,
    required this.steps,
    required this.width,
    this.pinned = false,
    this.skin,
    this.glow = 0,
  });

  /// Seeds the riffle's timing, so bars never move in lockstep.
  final String id;
  final String name;
  final String meta;
  final int steps;
  final double width;
  final bool pinned;
  final DeckSkin? skin;

  /// 0…1: the peach glow of a deck that was just added.
  final double glow;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final skin = this.skin;
    final (title, sub) = skin == null ? (mc.onInk, mc.mutedOnInk) : skinInk(skin);
    final g = glow;
    return Container(
      width: width,
      height: 72,
      foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(10)),
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
      child: Stack(
        children: [
          if (skin != null) ...[
            Positioned.fill(child: SkinPicture(skin: skin)),
            Positioned.fill(child: SkinShade(skin: skin)),
          ],
          // Now and then the fan riffles: back to front, each card lifts and leans for a moment.
          Positioned.fill(
            child: Pulse(
              delayMs: 1400 + (id.hashCode.abs() % 7) * 450,
              periodMs: const [8000, 9000, 10000][id.hashCode.abs() % 3],
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
                              color: i < steps ? mc.fanOn[i] : mc.fanOff,
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
                if (pinned) ...[
                  McIcon(McIcons.pin, size: const Size(15, 15), color: Mc.green),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.d(23, color: title, height: 1.05),
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
              style: T.t(13, w: skin == null ? FontWeight.w500 : FontWeight.w600, color: sub, spacing: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}
