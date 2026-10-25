import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'shell.dart';

/// The nav bar is a hand of cards (nav canvas, design B): Home · Lab · the + card · Shop · Account, fanned
/// around a point far below the screen. The chosen card is drawn up and floats; the + card is a card back
/// that deals New deck / New card, and the hand spreads while it does.
class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    required this.current,
    required this.onHome,
    required this.onLab,
    required this.onCreate,
    required this.onShop,
    required this.onAccount,
    this.open = false,
    this.badge = false,
  });

  /// Room the bar takes above the system inset (pages pad and fade by this much).
  static const height = 104.0;

  /// A card of the hand, and how far below its top the hand is held.
  static const cardW = 66.0;
  static const cardH = 98.0;
  static const _pivot = 403.0;

  /// How far a card reaches below the screen's usable bottom edge (it is held, not laid down).
  static const _sink = 30.0;

  final ShellTab current;
  final VoidCallback onHome;
  final VoidCallback onLab;
  final VoidCallback onCreate;
  final VoidCallback onShop;
  final VoidCallback onAccount;

  /// The create cards are out: the hand spreads and the + turns into an ×.
  final bool open;

  /// A new version is waiting: a gold 1 on the + card.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final left = mq.size.width / 2 - cardW / 2;
    final base = mq.padding.bottom - _sink;
    Widget place(Widget card) => Positioned(left: left, bottom: base, width: cardW, height: cardH, child: card);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        place(_HandCard(icon: McIcons.home, iconSize: const Size(24, 24), label: 'Home', rank: 'H', accent: Mc.blue, degrees: -16, selected: current == ShellTab.decks, spread: open, onTap: onHome)),
        place(_HandCard(icon: McIcons.lab, iconSize: const Size(24, 24), label: 'Lab', rank: 'L', accent: Mc.green, degrees: -8, selected: current == ShellTab.lab, spread: open, onTap: onLab)),
        place(_HandCard(icon: McIcons.shop, iconSize: const Size(26, 22), label: 'Shop', rank: 'S', accent: Mc.peach, degrees: 8, selected: current == ShellTab.shop, spread: open, onTap: onShop)),
        place(_HandCard(icon: McIcons.account, iconSize: const Size(23, 23), label: 'Account', rank: 'A', accent: Mc.red, degrees: 16, selected: current == ShellTab.account, spread: open, onTap: onAccount)),
        place(_BackCard(open: open, badge: badge, onTap: onCreate)),
      ],
    );
  }
}

/// Places a card of the hand: turned [degrees] about the pivot far below, spread wider by [spread] (0…1),
/// lifted along its own axis by [lift] px.
Widget _held({required double degrees, required double spread, required double lift, required Widget child}) {
  final angle = degrees * (1 + 0.5 * spread) * math.pi / 180;
  return Transform.rotate(
    angle: angle,
    origin: const Offset(0, NavBar._pivot - NavBar.cardH / 2),
    child: Transform.translate(offset: Offset(0, -lift + 26 * spread), child: child),
  );
}

class _HandCard extends StatefulWidget {
  const _HandCard({
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.rank,
    required this.accent,
    required this.degrees,
    required this.selected,
    required this.spread,
    required this.onTap,
  });

  final String icon;
  final Size iconSize;
  final String label;

  /// The corner letter, like a playing card's rank.
  final String rank;
  final Color accent;
  final double degrees;
  final bool selected;
  final bool spread;
  final VoidCallback onTap;

  @override
  State<_HandCard> createState() => _HandCardState();
}

class _HandCardState extends State<_HandCard> with SingleTickerProviderStateMixin {
  /// The drawn card floats a little, as if still in the hand.
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFloat();
  }

  @override
  void didUpdateWidget(_HandCard old) {
    super.didUpdateWidget(old);
    _syncFloat();
  }

  void _syncFloat() {
    final on = widget.selected && !MotionPrefs.reducedOf(context);
    if (on && !_float.isAnimating) {
      _float.repeat(reverse: true);
    } else if (!on && _float.isAnimating) {
      _float.stop();
      _float.value = 0;
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.spread ? 1 : 0),
      duration: const Duration(milliseconds: 600),
      curve: McCurves.springy,
      builder: (context, spread, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: widget.selected ? 1 : 0),
        duration: const Duration(milliseconds: 620),
        curve: McCurves.springy,
        builder: (context, lift, _) {
          final l = lift.clamp(0.0, 1.0);
          return _held(
            degrees: widget.degrees,
            spread: spread,
            lift: 30 * lift,
            child: Semantics(
              selected: widget.selected,
              child: Pressable(
                label: widget.label,
                scale: 0.94,
                onTap: () {
                  Fx.i.nav();
                  widget.onTap();
                },
                child: Container(
                  foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(11)),
                  decoration: BoxDecoration(
                    color: mc.ink,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.32 + 0.16 * l),
                        blurRadius: 10 + 16 * l,
                        offset: Offset(-3 * (1 - l), 3 + 9 * l),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    // The suit colour along the top edge, wider on the drawn card.
                    Positioned(left: 0, right: 0, top: 0, height: 4 + 5 * l, child: ColoredBox(color: widget.accent)),
                    Positioned(
                      left: 6,
                      top: 8,
                      child: Opacity(opacity: 0.55 * (1 - l), child: Text(widget.rank, style: T.d(13, color: mc.onInk, height: 1))),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 18,
                      child: AnimatedBuilder(
                        animation: _float,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, -3 * Curves.easeInOut.transform(_float.value)),
                          child: child,
                        ),
                        child: Column(children: [
                          Opacity(opacity: 0.62 + 0.38 * l, child: McIcon(widget.icon, size: widget.iconSize, color: mc.onInk)),
                          const SizedBox(height: 6),
                          Opacity(
                            opacity: l,
                            child: Transform.translate(
                              offset: Offset(0, 6 * (1 - lift)),
                              child: Text(widget.label, maxLines: 1, style: T.t(12.5, w: FontWeight.w700, color: mc.onInk, spacing: 0.3)),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The + is the back of a card in the middle of the hand, a little higher than the rest.
class _BackCard extends StatelessWidget {
  const _BackCard({required this.open, required this.onTap, this.badge = false});
  final bool open;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: open ? 1 : 0),
      duration: const Duration(milliseconds: 560),
      curve: McCurves.springy,
      builder: (context, v, _) => _held(
        degrees: 0,
        spread: 0,
        lift: 12 + 8 * v,
        child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
          Pressable(
            label: open ? 'Close' : (badge ? 'Create, one update waiting' : 'Create'),
            scale: 0.92,
            haptic: true,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: mc.canvas,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: mc.ink, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 10))],
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(
                painter: CardBackPainter(mc.ink.withValues(alpha: 0.16)),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Transform.rotate(angle: v * 3 * math.pi / 4, child: McIcon(McIcons.plus, size: const Size(30, 30), color: mc.ink)),
                  ),
                ),
              ),
            ),
          ),
          if (badge) const Positioned(right: -9, top: -11, child: IgnorePointer(child: _Badge())),
        ]),
      ),
    );
  }
}

/// The gold 1 that says a new version is waiting; it breathes slowly unless motion is reduced.
class _Badge extends StatefulWidget {
  const _Badge();

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = !MotionPrefs.reducedOf(context);
    if (on && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!on && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
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
    // The + card itself says "one update waiting"; the dot only looks.
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(scale: 1 + 0.14 * Curves.easeInOut.transform(_c.value), child: child),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Mc.peach, shape: BoxShape.circle, border: Border.all(color: mc.canvas, width: 3)),
          child: Text('1', style: T.t(13, w: FontWeight.w800, color: const Color(0xFF151515), height: 1)),
        ),
      ),
    );
  }
}

/// The diagonal hatching of a card back.
class CardBackPainter extends CustomPainter {
  const CardBackPainter(this.color, {this.gap = 9, this.width = 2});
  final Color color;
  final double gap;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = width;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(CardBackPainter old) => old.color != color || old.gap != gap || old.width != width;
}
