import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';

/// A deck drawn as a small physical card stack: two fanned cards behind a dark front card with the
/// monogram, and the category's coloured tab (canvas Shop.dc.html).
class StackArt extends StatelessWidget {
  const StackArt({
    super.key,
    required this.mono,
    required this.tab,
    this.held = false,
    this.inverse = false,
    this.scale = 1,
    this.swayDelayMs,
    this.swayPeriodMs,
  });

  final String mono;
  final Color tab;
  final bool held;

  /// Drawn on an ink surface (a selected tile): the front card turns canvas-coloured.
  final bool inverse;
  final double scale;

  /// When set, the two cards under the front one rock now and then (see [Sway]).
  final int? swayDelayMs;
  final int? swayPeriodMs;

  /// How far the under-cards swing, in radians (5.22°).
  static const swing = 5.22 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final back2 = held ? const Color(0xFF9D9D9D) : mc.back2;
    final back1 = held ? const Color(0xFF747474) : mc.back1;
    final front = held ? Mc.graphite : (inverse ? mc.canvas : mc.ink);
    final onFront = held ? Mc.paper : (inverse ? mc.ink : mc.onInk);
    if (swayPeriodMs == null) return _art(back2, back1, front, onFront, 0);
    return Sway(
      delayMs: swayDelayMs ?? 0,
      periodMs: swayPeriodMs!,
      builder: (context, v) => _art(back2, back1, front, onFront, v),
    );
  }

  Widget _art(Color back2, Color back1, Color front, Color onFront, double v) {
    return SizedBox(
      width: 150 * scale,
      height: 120 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 26 * scale,
            top: 14 * scale,
            child: Transform.rotate(
              angle: -0.14 - v * swing,
              child: Container(
                width: 94 * scale,
                height: 100 * scale,
                decoration: BoxDecoration(color: back2, borderRadius: BorderRadius.circular(12 * scale)),
              ),
            ),
          ),
          Positioned(
            left: 30 * scale,
            top: 10 * scale,
            child: Transform.rotate(
              angle: 0.105 + v * swing,
              child: Container(
                width: 94 * scale,
                height: 100 * scale,
                decoration: BoxDecoration(color: back1, borderRadius: BorderRadius.circular(12 * scale)),
              ),
            ),
          ),
          Positioned(
            left: 37 * scale,
            top: 1 * scale,
            child: Container(
              width: 30 * scale,
              height: 12 * scale,
              decoration: BoxDecoration(color: tab, borderRadius: BorderRadius.circular(5 * scale)),
            ),
          ),
          Positioned(
            left: 27 * scale,
            top: 8 * scale,
            child: Container(
              width: 94 * scale,
              height: 104 * scale,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: front,
                borderRadius: BorderRadius.circular(12 * scale),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(mono, style: T.d(40 * scale, color: onFront)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tile of the shop grid.
class ShopTile extends StatelessWidget {
  const ShopTile({super.key, required this.deck, this.added = false, this.pinned = false, this.held = false});

  final CatalogDeck deck;
  final bool added;
  final bool pinned;
  final bool held;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final tab = Color(CatalogCategory.of(deck.category).color);
    final meta = '${deck.cards.length} cards${deck.level.isNotEmpty ? ' · ${deck.level}' : ''}';
    return Container(
      height: 214,
      padding: const EdgeInsets.all(12),
      foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(18)),
      decoration: BoxDecoration(
        color: held ? const Color(0xFFE4E4E4) : mc.soft,
        borderRadius: BorderRadius.circular(18),
        boxShadow: held ? const [BoxShadow(color: Color(0x66000000), blurRadius: 44, offset: Offset(0, 18))] : mc.e1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                StackArt(
                  mono: deck.mono,
                  tab: tab,
                  held: held,
                  // Staggered so the grid never moves in lockstep: each deck has its own delay and beat.
                  swayDelayMs: held ? null : 250 + (deck.id.hashCode.abs() % 9) * 170,
                  swayPeriodMs: held ? null : const [7000, 8000, 9000, 7500][deck.id.hashCode.abs() % 4],
                ),
                if (added || pinned)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Row(children: [
                      if (pinned)
                        _Badge(icon: McIcons.pin, color: Mc.green),
                      if (added) ...[
                        const SizedBox(width: 4),
                        _Badge(icon: McIcons.done, color: held ? Mc.graphite : mc.ink, iconColor: held ? Mc.paper : mc.canvas),
                      ],
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Text(deck.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: T.d(19, color: held ? Mc.graphite : mc.ink, height: 20 / 19)),
          ),
          const SizedBox(height: 2),
          Text(meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.t(13, w: FontWeight.w600, color: held ? const Color(0xFF555555) : mc.muted)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, this.iconColor = Mc.graphite});
  final String icon;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: McIcon(icon, size: const Size(13, 13), color: iconColor)),
      );
}
