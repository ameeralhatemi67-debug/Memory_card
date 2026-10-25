import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'nav_bar.dart';

// What the + card deals (nav canvas, design B): two cards leave the hand face down, flip in the air and land
// above it, "New deck" and "New card". The shell draws them over the page and under nothing, with the hand
// spread and still live below; [anim] runs 0 → 1 as they are dealt and back as they return.

/// The page behind dims while the cards are out; a tap on it puts them back.
class CreateDim extends StatelessWidget {
  const CreateDim({super.key, required this.anim, required this.onClose});
  final Animation<double> anim;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: ColoredBox(color: mc.canvas.withValues(alpha: 0.78 * Curves.easeOut.transform(anim.value.clamp(0.0, 1.0)))),
      ),
    );
  }
}

/// The dealt cards: New deck and New card, and between them a gold Update card while a new version is waiting
/// (then they are a little smaller so three fit). [onPick] gets 'deck', 'update' or 'card'.
class CreateDeal extends StatelessWidget {
  const CreateDeal({super.key, required this.anim, required this.onPick, this.update, this.updateNote = ''});
  final Animation<double> anim;
  final ValueChanged<String> onPick;

  /// The version waiting ("1.6.0"), or null for the usual two cards.
  final String? update;

  /// Under the Update card's title: "1.6.0 · 150 MB".
  final String updateNote;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final reduced = MotionPrefs.reducedOf(context);
    final cx = mq.size.width / 2;
    final three = update != null;
    final w = three ? math.min(116.0, (mq.size.width - 2 * 10 - 2 * 8) / 3) : 142.0;
    final h = three ? 160.0 : 180.0;
    final gap = three ? w + 8 : math.min(80.0, (mq.size.width - 2 * w - 24) / 2 + w / 2);
    // They leave from the + card's face and land above the hand (the Update card a little higher, in the middle).
    final fromBottom = mq.padding.bottom - 18.0;
    final toBottom = mq.padding.bottom + 118.0;
    final cards = three ? const ['deck', 'update', 'card'] : const ['deck', 'card'];
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final v = anim.value;
        return Stack(children: [
          for (var i = 0; i < cards.length; i++)
            () {
              final kind = cards[i];
              final t = ((v * 650 - i * 90) / 560).clamp(0.0, 1.0);
              final pos = reduced ? t : McCurves.springy.transform(t);
              final flip = reduced ? 1.0 : Curves.easeOut.transform(t);
              final side = kind == 'deck' ? -1.0 : (kind == 'card' ? 1.0 : 0.0);
              final angleY = math.pi * (1 - flip);
              final m = Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateZ(side * 6 * math.pi / 180 * pos)
                ..rotateY(angleY)
                ..scaleByDouble(lerpDouble(0.42, 1, pos)!, lerpDouble(0.42, 1, pos)!, 1, 1);
              return Positioned(
                left: cx + side * gap * pos - w / 2,
                bottom: lerpDouble(fromBottom, toBottom + (kind == 'update' ? 32 : 0), pos),
                width: w,
                height: h,
                child: IgnorePointer(
                  ignoring: v < 0.95,
                  child: Opacity(
                    opacity: (t * 5).clamp(0.0, 1.0),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: m,
                      child: angleY > math.pi / 2
                          ? const _Back()
                          : switch (kind) {
                              'deck' => _Face(
                                  title: 'New deck',
                                  note: three ? 'Name, look, seals' : 'Name, look and seals',
                                  band: Mc.blue,
                                  art: const _DeckArt(),
                                  small: three,
                                  onTap: () => onPick('deck'),
                                ),
                              'update' => _Face(
                                  title: 'Update',
                                  note: updateNote,
                                  band: Mc.peach,
                                  art: const _UpdateArt(),
                                  small: true,
                                  onTap: () => onPick('update'),
                                ),
                              _ => _Face(
                                  title: 'New card',
                                  note: three ? 'For any deck' : 'For any of your decks',
                                  band: Mc.peach,
                                  art: const _CardArt(),
                                  small: three,
                                  onTap: () => onPick('card'),
                                ),
                            },
                    ),
                  ),
                ),
              );
            }(),
        ]);
      },
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.title, required this.note, required this.band, required this.art, required this.onTap, this.small = false});
  final String title;
  final String note;
  final Color band;
  final Widget art;
  final VoidCallback onTap;

  /// One of three across the screen: a smaller title.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      label: title,
      haptic: true,
      onTap: onTap,
      child: Container(
        foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(16)),
        decoration: BoxDecoration(
          color: mc.ink,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 36, offset: Offset(0, 18))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(left: 0, right: 0, top: 0, height: 10, child: ColoredBox(color: band)),
          Positioned(left: 14, top: 26, child: art),
          Positioned(
            left: 14,
            right: 12,
            bottom: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(title, style: T.d(small ? 24 : 27, color: mc.onInk, height: 1))),
              const SizedBox(height: 4),
              Text(note, maxLines: 2, style: T.t(13, w: FontWeight.w600, color: mc.onInk.withValues(alpha: 0.62), height: 1.15)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Container(
      decoration: BoxDecoration(
        color: mc.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mc.ink, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: CardBackPainter(mc.ink.withValues(alpha: 0.16), gap: 12, width: 3)),
    );
  }
}

/// Three deck bars, fanned: a deck.
class _DeckArt extends StatelessWidget {
  const _DeckArt();

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return SizedBox(
      width: 74,
      height: 52,
      child: Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < 3; i++)
          Positioned(
            left: 4 + i * 6.0,
            top: 30 - i * 13.0,
            child: Transform.rotate(
              angle: (-9 + i * 4.5) * math.pi / 180,
              child: Container(
                width: 54,
                height: 18,
                decoration: BoxDecoration(color: [Mc.blue, Mc.peach, mc.onInk][i], borderRadius: BorderRadius.circular(5)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// One card with an arrow pointing down into it: the update.
class _UpdateArt extends StatelessWidget {
  const _UpdateArt();

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Transform.rotate(
      angle: -7 * math.pi / 180,
      child: Container(
        width: 34,
        height: 48,
        decoration: BoxDecoration(color: mc.onInk, borderRadius: BorderRadius.circular(7)),
        child: Center(child: CustomPaint(size: const Size(16, 18), painter: _ArrowDown(mc.ink))),
      ),
    );
  }
}

class _ArrowDown extends CustomPainter {
  const _ArrowDown(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final c = size.width / 2;
    canvas.drawLine(Offset(c, 1), Offset(c, size.height - 2), p);
    canvas.drawPath(
      Path()
        ..moveTo(c - 6.5, size.height - 8.5)
        ..lineTo(c, size.height - 2)
        ..lineTo(c + 6.5, size.height - 8.5),
      p,
    );
  }

  @override
  bool shouldRepaint(_ArrowDown old) => old.color != color;
}

/// One card with a + on it: a card.
class _CardArt extends StatelessWidget {
  const _CardArt();

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Transform.rotate(
      angle: -7 * math.pi / 180,
      child: Container(
        width: 34,
        height: 48,
        decoration: BoxDecoration(color: mc.onInk, borderRadius: BorderRadius.circular(7)),
        child: Center(child: McIcon(McIcons.plus, size: const Size(16, 16), color: mc.ink)),
      ),
    );
  }
}
