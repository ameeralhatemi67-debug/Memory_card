import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Display size of the prompt, by length (the canvas `termSize`).
double termSize(String text, bool code) {
  final n = text.length;
  if (code) return n > 26 ? 18 : n > 18 ? 21 : n > 12 ? 24 : 27;
  return n > 40 ? 22 : n > 30 ? 24 : n > 20 ? 28 : n > 12 ? 32 : 36;
}

/// A card image from a file path (phone) or a data URI (web).
Widget cardImage(String src, {double? height, BoxFit fit = BoxFit.cover}) {
  if (src.startsWith('data:')) {
    final comma = src.indexOf(',');
    final bytes = Uri.parse(src).data?.contentAsBytes() ?? Uint8List(0);
    if (comma < 0 || bytes.isEmpty) return const SizedBox.shrink();
    return Image.memory(bytes, height: height, fit: fit, gaplessPlayback: true);
  }
  if (kIsWeb) return Image.network(src, height: height, fit: fit);
  return Image.file(File(src), height: height, fit: fit, gaplessPlayback: true);
}

/// The front of a study card: label, the prompt, context, then the reveal area and "Hear it".
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

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final code = deck.kind == 'code' && !card.isReverse;
    final prompt = card.front;
    final label = card.isReverse ? 'reverse' : (card.label.isNotEmpty ? card.label : deck.category == 'custom' ? 'card' : deck.level);
    final flip = mode == RevealMode.flip;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caps(12, color: mc.mutedOnInk)),
              ),
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
          ),
          const SizedBox(height: 6),
          Text(
            prompt,
            textDirection: _dir(prompt),
            style: code
                ? T.mono(termSize(prompt, true), color: mc.onInk)
                : T.d(termSize(prompt, false), color: mc.onInk, height: 1.05),
          ),
          if (card.example.isNotEmpty && !(flip && revealed)) ...[
            const SizedBox(height: 8),
            Text(card.example,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                textDirection: _dir(card.example),
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
          const Spacer(),
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
                  ? _Answer(key: const ValueKey('a'), card: card, typedResult: typedResult)
                  : _RevealButton(key: const ValueKey('r'), icon: mode == RevealMode.icon, onTap: onReveal),
            ),
          if (typing != null && revealed) _Answer(card: card, typedResult: typedResult),
          if (flip && !revealed)
            Text('Tap the card to flip it', textAlign: TextAlign.center, style: T.t(14, w: FontWeight.w600, color: mc.mutedOnInk)),
          if (mode == RevealMode.front)
            Text('Self-check · swipe right if you knew it',
                textAlign: TextAlign.center, style: T.t(14, w: FontWeight.w600, color: mc.mutedOnInk)),
          if (onSpeak != null) ...[
            const SizedBox(height: 10),
            _SpeakButton(speaking: speaking, compact: compact, onTap: onSpeak!),
          ],
        ],
      ),
    );
  }
}

/// The back face for flip mode: the answer in peach.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.card, required this.compact, required this.speaking, this.onSpeak});
  final CardItem card;
  final bool compact;
  final bool speaking;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final answer = card.back;
    return Container(
      decoration: BoxDecoration(color: Mc.peach, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ANSWER', style: T.caps(12, color: Mc.graphite.withValues(alpha: 0.67))),
          const SizedBox(height: 6),
          Text(answer, textDirection: _dir(answer), style: T.d(termSize(answer, false), color: Mc.graphite, height: 1.05)),
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
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({super.key, required this.icon, required this.onTap});
  final bool icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      onTap: onTap,
      label: 'Reveal the answer',
      child: Container(
        height: 56,
        decoration: BoxDecoration(color: mc.pill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon) ...[McIcon(McIcons.eye, size: const Size(22, 22), color: Mc.graphite), const SizedBox(width: 8)],
            Text(icon ? 'Show answer' : 'Tap to reveal', style: T.t(17, w: FontWeight.w600, color: Mc.graphite)),
          ],
        ),
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({super.key, required this.card, this.typedResult});
  final CardItem card;
  final String? typedResult;

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
          _Hook(text: card.hook, color: mc.mutedOnInk),
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
              textDirection: _dir(answer),
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

TextDirection? _dir(String s) => RegExp(r'[֐-ࣿ]').hasMatch(s) ? TextDirection.rtl : null;
