import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// The "+" asks what to make: two paper cards fan up out of it ("New deck", "New card") and the + turns
/// into an ×. [anchor] is the + in global coordinates. Returns 'deck', 'card' or null.
Future<String?> showCreateMenu(BuildContext context, Rect anchor) {
  Fx.i.whoosh();
  return Navigator.of(context, rootNavigator: true).push<String>(PageRouteBuilder<String>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    barrierLabel: 'Close',
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, a, b) => Material(type: MaterialType.transparency, child: _CreateMenu(anchor: anchor, animation: a)),
  ));
}

class _CreateMenu extends StatelessWidget {
  const _CreateMenu({required this.anchor, required this.animation});
  final Rect anchor;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final reduced = MotionPrefs.reducedOf(context);
    final size = MediaQuery.of(context).size;
    final c = anchor.center;
    const tileW = 156.0, tileH = 112.0, gap = 12.0;
    final top = anchor.top - tileH - 18;
    final options = [
      ('deck', 'New deck', 'Its name, look and seals', McIcons.newFolder),
      ('card', 'New card', 'For any of your decks', McIcons.plus),
    ];
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = animation.value;
        return Stack(children: [
          // The page dims and steps back a little.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: ColoredBox(color: mc.canvas.withValues(alpha: 0.78 * Curves.easeOut.transform(v.clamp(0.0, 1.0)))),
            ),
          ),
          for (var i = 0; i < options.length; i++)
            () {
              // Each card leaves the + a beat after the other and lands with a soft overshoot.
              final local = ((v * 520 - i * 70) / 450).clamp(0.0, 1.0);
              final t = reduced ? local : McCurves.springy.transform(local);
              final restX = c.dx + (i == 0 ? -(tileW + gap / 2) : gap / 2);
              final left = restX.clamp(16.0, size.width - tileW - 16);
              final dx = (c.dx - tileW / 2 - left) * (1 - t);
              final dy = (anchor.top - top) * (1 - t);
              final angle = (i == 0 ? -1 : 1) * (1 - t) * 18 * math.pi / 180;
              final (id, title, note, icon) = options[i];
              return Positioned(
                left: left,
                top: top,
                width: tileW,
                height: tileH,
                child: Opacity(
                  opacity: local.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(dx, dy),
                    child: Transform.rotate(
                      angle: angle,
                      child: Transform.scale(
                        scale: 0.5 + 0.5 * t,
                        child: _Option(
                          title: title,
                          note: note,
                          icon: icon,
                          deck: id == 'deck',
                          onTap: () {
                            Fx.i.pop();
                            Navigator.pop(context, id);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }(),
          // The + turned ×, right over the one in the nav bar.
          Positioned(
            left: anchor.left,
            top: anchor.top,
            width: anchor.width,
            height: anchor.height,
            child: Pressable(
              label: 'Close',
              scale: 0.9,
              onTap: () => Navigator.pop(context),
              child: Stack(alignment: Alignment.center, children: [
                Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 58,
                    height: 58,
                    foregroundDecoration: texDeco(context, 'buttons', BorderRadius.circular(15)),
                    decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(15), boxShadow: mc.e2),
                  ),
                ),
                Transform.rotate(
                  angle: Curves.easeOutBack.transform(v.clamp(0.0, 1.0)) * math.pi / 4,
                  child: McIcon(McIcons.plus, size: const Size(30, 30), color: mc.canvas),
                ),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.title, required this.note, required this.icon, required this.deck, required this.onTap});
  final String title;
  final String note;
  final String icon;
  final bool deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      label: title,
      haptic: true,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(16)),
        decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(16), boxShadow: mc.e3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 34, child: deck ? const _MiniDeck() : const _MiniCard()),
          // The words sit at the bottom and shrink rather than spill if the text is set large.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: T.d(22, color: mc.onInk, height: 1.05)),
                const SizedBox(height: 2),
                Text(note, maxLines: 1, style: T.t(12.5, w: FontWeight.w600, color: mc.mutedOnInk)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Three little deck bars, fanned: a deck.
class _MiniDeck extends StatelessWidget {
  const _MiniDeck();

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Stack(clipBehavior: Clip.none, children: [
      for (var i = 0; i < 3; i++)
        Positioned(
          left: i * 7.0,
          top: 12 - i * 6.0,
          child: Transform.rotate(
            angle: (-8 + i * 6) * math.pi / 180,
            child: Container(
              width: 46,
              height: 18,
              decoration: BoxDecoration(color: [Mc.blue, Mc.peach, mc.onInk][i], borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
    ]);
  }
}

/// One card with a + on it: a card.
class _MiniCard extends StatelessWidget {
  const _MiniCard();

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.rotate(
        angle: -6 * math.pi / 180,
        child: Container(
          width: 26,
          height: 34,
          decoration: BoxDecoration(color: mc.onInk, borderRadius: BorderRadius.circular(5)),
          child: Center(child: McIcon(McIcons.plus, size: const Size(12, 12), color: mc.ink)),
        ),
      ),
    );
  }
}
