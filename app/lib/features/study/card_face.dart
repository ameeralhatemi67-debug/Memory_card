import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/card_layout.dart';
import '../../data/models.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../layout/layout_face.dart';

export '../layout/layout_face.dart' show CardThumb, cardImage, termSize;

/// The front of a study card: label, the prompt, context, then the reveal area and "Hear it".
/// Cards with a picture layout draw it behind the same label and reveal controls.
class CardFront extends StatelessWidget {
  const CardFront({
    super.key,
    required this.card,
    required this.deck,
    required this.revealed,
    required this.mode,
    required this.compact,
    required this.speaking,
    required this.onReveal,
    this.onSpeak,
    this.typing,
    this.typedResult,
    this.pre = PreReveal.none,
  });

  final CardItem card;
  final Deck deck;
  final bool revealed;
  final RevealMode mode;
  final bool compact;
  final bool speaking;
  final VoidCallback onReveal;
  final VoidCallback? onSpeak;

  /// The type-the-answer field (typing decks).
  final Widget? typing;

  /// After a typed answer: 'exact' · 'close' · 'wrong'.
  final String? typedResult;

  /// What pictures marked "blur until revealed" do now (Settings).
  final PreReveal pre;

  /// The answer has its own face (pictures or a free canvas): it replaces the front on reveal.
  bool get _answerReplacesFront =>
      revealed && typing == null && card.hasRichBack && (mode == RevealMode.tap || mode == RevealMode.icon);

  @override
  Widget build(BuildContext context) {
    final reduced = MotionPrefs.reducedOf(context);
    final layout = card.frontLayout;
    final front = layout != null && !layout.isPlain ? _pictured(context, layout) : _classic(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduced ? 0 : 240),
      switchInCurve: McCurves.out,
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: _answerReplacesFront
          ? CardBack(
              key: const ValueKey('rich-answer'),
              card: card,
              deck: deck,
              compact: compact,
              speaking: speaking,
              onSpeak: onSpeak,
              pre: pre,
            )
          : KeyedSubtree(key: const ValueKey('front'), child: front),
    );
  }

  Widget _labelRow(Mc mc, {bool backed = false}) {
    final label = card.isReverse ? 'reverse' : (card.label.isNotEmpty ? card.label : deck.category == 'custom' ? 'card' : deck.level);
    Widget text = Text(label.toUpperCase(),
        maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caps(12, color: backed ? Mc.paper : mc.mutedOnInk));
    if (backed) {
      text = Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: const Color(0x99222222), borderRadius: BorderRadius.circular(9)),
        child: text,
      );
    }
    return Row(
      children: [
        Expanded(child: Align(alignment: Alignment.centerLeft, child: text)),
        if (card.isNew)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Mc.peach, borderRadius: BorderRadius.circular(8)),
            child: Text('NEW', style: T.caps(11, color: Mc.graphite, spacing: 1)),
          )
        else if (card.leech)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Mc.delete, borderRadius: BorderRadius.circular(8)),
            child: Text('TRICKY', style: T.caps(11, color: Mc.graphite, spacing: 1)),
          ),
      ],
    );
  }

  /// A blurred look at the answer's picture, shown inside the reveal button.
  Widget? _peek() {
    if (typing != null || pre.sigma <= 0 || !(mode == RevealMode.tap || mode == RevealMode.icon)) return null;
    final bl = card.backLayout;
    if (bl == null || !card.hasRichBack) return null;
    final pic = bl.images.where((i) => i.blur).firstOrNull;
    return pic == null ? null : PeekStrip(el: pic, sigma: pre.sigma);
  }

  /// Everything under the prompt: the type-it field, the reveal button or the answer, hints, "Hear it".
  List<Widget> _footer(Mc mc, {bool overPicture = false}) {
    final flip = mode == RevealMode.flip;
    return [
      if (typing != null && !revealed) typing!,
      if (mode != RevealMode.front && !flip && typing == null)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: McCurves.out,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: c),
          ),
          child: revealed
              ? _Answer(key: const ValueKey('a'), card: card, typedResult: typedResult, overPicture: overPicture)
              : _RevealButton(key: const ValueKey('r'), icon: mode == RevealMode.icon, onTap: onReveal, peek: _peek()),
        ),
      if (typing != null && revealed) _Answer(card: card, typedResult: typedResult, overPicture: overPicture),
      if (flip && !revealed)
        Text('Tap the card to flip it', textAlign: TextAlign.center, style: T.t(14, w: FontWeight.w600, color: mc.mutedOnInk)),
      if (mode == RevealMode.front)
        Text('Self-check · swipe right if you knew it',
            textAlign: TextAlign.center, style: T.t(14, w: FontWeight.w600, color: mc.mutedOnInk)),
      if (onSpeak != null) ...[
        const SizedBox(height: 10),
        _SpeakButton(speaking: speaking, compact: compact, onTap: onSpeak!),
      ],
    ];
  }

  /// The classic text card (with the older single picture under the prompt).
  Widget _classic(BuildContext context) {
    final mc = Mc.of(context);
    final code = deck.kind == 'code' && !card.isReverse;
    final prompt = card.front;
    final flip = mode == RevealMode.flip;
    // A kanji, a letter, a kana: one big glyph in the middle of the card.
    final glyph = !code && prompt.trim().isNotEmpty && prompt.trim().runes.length <= 3;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labelRow(mc),
          const SizedBox(height: 6),
          if (glyph)
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(prompt.trim(), textDirection: dirOf(prompt), style: T.d(compact ? 84 : 120, color: mc.onInk, height: 1)),
                ),
              ),
            )
          else
            Text(
              prompt,
              textDirection: dirOf(prompt),
              style: code
                  ? T.mono(termSize(prompt, true), color: mc.onInk)
                  : T.d(termSize(prompt, false), color: mc.onInk, height: 1.05),
            ),
          if (card.example.isNotEmpty && !(flip && revealed)) ...[
            const SizedBox(height: 8),
            Text(card.example,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                textDirection: dirOf(card.example),
                style: T.t(compact ? 15 : 17, w: FontWeight.w500, color: mc.mutedOnInk, height: 1.3)),
          ],
          if (card.image != null && card.image!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: cardImage(card.image!, height: compact ? 80 : 120),
              ),
            ),
          ],
          if (!glyph) const Spacer(),
          ..._footer(mc),
        ],
      ),
    );
  }

  /// A card with a picture layout: the layout fills the face, the controls sit on top of it.
  Widget _pictured(BuildContext context, SideLayout layout) {
    final mc = Mc.of(context);
    final reduced = MotionPrefs.reducedOf(context);
    final sharp = revealed || mode == RevealMode.front;
    return Stack(
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: sharp ? 1.0 : 0.0),
          duration: Duration(milliseconds: reduced ? 0 : 600),
          curve: Curves.easeOut,
          builder: (context, t, _) => LayoutFace(
            layout: layout,
            texts: LayoutTexts.of(card, deck, back: false),
            back: false,
            pre: pre,
            reveal: t,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _labelRow(mc, backed: layout.imageUnderLabel),
              const Spacer(),
              ..._footer(mc, overPicture: layout.hasImage),
            ],
          ),
        ),
      ],
    );
  }
}

/// The back face: the answer in peach. With a layout it shows its pictures and text where you put them.
class CardBack extends StatelessWidget {
  const CardBack({
    super.key,
    required this.card,
    required this.compact,
    required this.speaking,
    this.onSpeak,
    this.deck,
    this.pre = PreReveal.none,
    this.reveal,
  });
  final CardItem card;
  final Deck? deck;
  final bool compact;
  final bool speaking;
  final VoidCallback? onSpeak;
  final PreReveal pre;

  /// 0…1 as the face turns up (flip mode); null = sharpen on its own, once, as it appears.
  final double? reveal;

  @override
  Widget build(BuildContext context) {
    final layout = card.backLayout;
    if (layout != null && !layout.isPlain) return _pictured(context, layout);
    final answer = card.back;
    return Container(
      decoration: BoxDecoration(color: Mc.peach, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ANSWER', style: T.caps(12, color: Mc.graphite.withValues(alpha: 0.67))),
          const SizedBox(height: 6),
          Text(answer, textDirection: dirOf(answer), style: T.d(termSize(answer, false), color: Mc.graphite, height: 1.05)),
          if (card.example.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(card.example, style: T.t(16, w: FontWeight.w500, color: Mc.graphite.withValues(alpha: 0.7), height: 1.3)),
          ],
          if (card.hook.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Hook(text: card.hook, color: Mc.graphite),
          ],
          const Spacer(),
          if (onSpeak != null) _SpeakButton(speaking: speaking, compact: compact, onTap: onSpeak!),
        ],
      ),
    );
  }

  Widget _pictured(BuildContext context, SideLayout layout) {
    final reduced = MotionPrefs.reducedOf(context);
    Widget face(double t) => LayoutFace(
          layout: layout,
          texts: LayoutTexts.of(card, deck, back: true),
          back: true,
          pre: pre,
          reveal: t,
        );
    final backed = layout.imageUnderLabel;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Mc.peach, borderRadius: BorderRadius.circular(18)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          reveal != null
              ? face(reveal!)
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1.0 : 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOut,
                  builder: (context, t, _) => face(t),
                ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: backed ? const EdgeInsets.symmetric(horizontal: 9, vertical: 3) : EdgeInsets.zero,
                    decoration: backed ? BoxDecoration(color: const Color(0x99222222), borderRadius: BorderRadius.circular(9)) : null,
                    child: Text('ANSWER', style: T.caps(12, color: backed ? Mc.paper : Mc.graphite.withValues(alpha: 0.67))),
                  ),
                ),
                const Spacer(),
                if (onSpeak != null) _SpeakButton(speaking: speaking, compact: compact, onTap: onSpeak!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A blurred sliver of the answer's picture: a hint that something is waiting behind the reveal.
class PeekStrip extends StatelessWidget {
  const PeekStrip({super.key, required this.el, required this.sigma});
  final ImageEl el;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PictureView(
          el: ImageEl(
              x: 0, y: 0, w: 1, h: 1, src: el.src, aspect: el.aspect, contain: false, radius: 0, zoom: el.zoom, panX: el.panX, panY: el.panY),
          k: 1,
          forceBlur: sigma,
        ),
        const ColoredBox(color: Color(0x40000000)),
      ],
    );
  }
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({super.key, required this.icon, required this.onTap, this.peek});
  final bool icon;
  final VoidCallback onTap;
  final Widget? peek;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      onTap: onTap,
      label: 'Reveal the answer',
      child: Container(
        height: 56,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: mc.pill, borderRadius: BorderRadius.circular(12)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ?peek,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon) ...[
                  McIcon(McIcons.eye, size: const Size(22, 22), color: peek == null ? Mc.graphite : Mc.paper),
                  const SizedBox(width: 8),
                ],
                Text(icon ? 'Show answer' : 'Tap to reveal',
                    style: T.t(17, w: FontWeight.w600, color: peek == null ? Mc.graphite : Mc.paper)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({super.key, required this.card, this.typedResult, this.overPicture = false});
  final CardItem card;
  final String? typedResult;

  /// The card has a picture behind this: the hook gets a backing so it stays readable.
  final bool overPicture;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final answer = card.back;
    final long = answer.length > 22;
    final color = switch (typedResult) { 'exact' => Mc.green, 'wrong' => Mc.delete, _ => Mc.peach };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (card.hook.isNotEmpty) ...[
          overPicture
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xB8222222), borderRadius: BorderRadius.circular(10)),
                  child: _Hook(text: card.hook, color: Mc.paper),
                )
              : _Hook(text: card.hook, color: mc.mutedOnInk),
          const SizedBox(height: 8),
        ],
        Semantics(
          liveRegion: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: long ? 10 : 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Text(
              answer,
              textAlign: TextAlign.center,
              textDirection: dirOf(answer),
              style: long
                  ? T.t(answer.length > 44 ? 17 : 19, w: FontWeight.w700, color: Mc.graphite, height: 1.2)
                  : T.d(28, color: Mc.graphite),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hook extends StatelessWidget {
  const _Hook({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: McIcon(McIcons.lightbulb, size: const Size(16, 16), color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: T.t(14, w: FontWeight.w600, color: color, height: 1.3)),
          ),
        ],
      );
}

class _SpeakButton extends StatelessWidget {
  const _SpeakButton({required this.speaking, required this.compact, required this.onTap});
  final bool speaking;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      label: 'Play pronunciation',
      child: Container(
        height: compact ? 58 : 76,
        decoration: BoxDecoration(color: Mc.red, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AmbientClock(
              enabled: speaking,
              builder: (context, ms) => Transform.scale(
                scale: speaking ? 1 + 0.08 * math.sin(ms / 140) : 1,
                child: McIcon(McIcons.speaker, size: const Size(30, 30), color: Mc.paper),
              ),
            ),
            const SizedBox(width: 10),
            Text(speaking ? 'Playing…' : 'Hear it', style: T.d(25, color: Mc.paper)),
          ],
        ),
      ),
    );
  }
}

