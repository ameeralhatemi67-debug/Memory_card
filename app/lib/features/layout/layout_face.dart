import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/card_layout.dart';
import '../../data/models.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';
import '../media/card_video.dart';

/// Display size of the prompt, by length (the canvas `termSize`).
double termSize(String text, bool code) {
  final n = text.length;
  if (code) return n > 26 ? 18 : n > 18 ? 21 : n > 12 ? 24 : 27;
  return n > 40 ? 22 : n > 30 ? 24 : n > 20 ? 28 : n > 12 ? 32 : 36;
}

TextDirection? dirOf(String s) => RegExp(r'[֐-ࣿ]').hasMatch(s) ? TextDirection.rtl : null;

/// A card picture from a file path (phone), a data URI (web) or a bundled `asset:` path (shop decks).
Widget cardImage(
  String src, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  int? cacheWidth,
}) {
  if (src.startsWith('asset:')) {
    return Image.asset(src.substring(6),
        width: width, height: height, fit: fit, alignment: alignment, gaplessPlayback: true, cacheWidth: cacheWidth);
  }
  if (src.startsWith('data:')) {
    final comma = src.indexOf(',');
    final bytes = Uri.parse(src).data?.contentAsBytes() ?? Uint8List(0);
    if (comma < 0 || bytes.isEmpty) return const SizedBox.shrink();
    return Image.memory(bytes, width: width, height: height, fit: fit, alignment: alignment, gaplessPlayback: true, cacheWidth: cacheWidth);
  }
  if (kIsWeb) return Image.network(src, width: width, height: height, fit: fit, alignment: alignment);
  return Image.file(File(src),
      width: width, height: height, fit: fit, alignment: alignment, gaplessPlayback: true, cacheWidth: cacheWidth);
}

/// What pictures marked "blur until revealed" do before the reveal (Settings › Study).
@immutable
class PreReveal {
  const PreReveal(this.sigma, {this.hide = false, this.hintSigma = 0});

  /// Gaussian blur, in pixels on a 276-wide face; 0 = none.
  final double sigma;

  /// Not even a blur: the picture is invisible until the reveal.
  final bool hide;

  /// How strongly a hint is blurred until it is tapped. Hints stay covered even when waiting pictures are
  /// set to show (a hint in plain sight is not a hint).
  final double hintSigma;

  static const none = PreReveal(0);

  factory PreReveal.of(Settings s) => switch (s.imageReveal) {
        'hide' => const PreReveal(0, hide: true),
        'show' => PreReveal(0, hintSigma: 6 + 34 * s.blurAmount),
        _ => PreReveal(s.blurSigma, hintSigma: s.blurSigma),
      };

  bool get active => sigma > 0 || hide;
}

/// How a face treats its videos and hints: still (previews, thumbnails, the next card waiting underneath)
/// or live (the card on top of the stack: videos play, hints open on a tap).
@immutable
class FaceMedia {
  const FaceMedia({this.live = false, this.autoPlay = true, this.hintsOpen = const {}, this.onHint});

  /// Videos may play here.
  final bool live;

  /// They start by themselves once nothing holds them back (Settings › Study).
  final bool autoPlay;

  /// Hints opened on this card so far (element ids).
  final Set<String> hintsOpen;

  /// A hint was tapped open; null where hints are not interactive.
  final ValueChanged<String>? onHint;

  static const still = FaceMedia();
}

/// The words a layout draws: the card's own fields (or the editor's live text).
@immutable
class LayoutTexts {
  const LayoutTexts({this.main = '', this.example = '', this.hook = '', this.code = false});

  final String main;
  final String example;
  final String hook;

  /// The main text is code (monospace).
  final bool code;

  factory LayoutTexts.of(CardItem c, Deck? d, {required bool back}) => LayoutTexts(
        main: back ? c.back : c.front,
        example: c.example,
        hook: c.hook,
        code: d?.kind == 'code' && !back && !c.isReverse,
      );
}

/// Draws one side of a card from its [SideLayout]. Transparent: the card's own face shows through.
/// Everything is placed by fractions of the box it is given, so the same layout fits the study card,
/// the editor preview and the small thumbnails.
class LayoutFace extends StatelessWidget {
  const LayoutFace({
    super.key,
    required this.layout,
    required this.texts,
    required this.back,
    this.pre = PreReveal.none,
    this.reveal = 1,
    this.hidden = const {},
    this.media = FaceMedia.still,
  });

  final SideLayout layout;
  final LayoutTexts texts;

  /// Back side: peach face, dark text.
  final bool back;
  final PreReveal pre;

  /// 0 → 1 as the card is revealed: flagged pictures sharpen (or appear) with it.
  final double reveal;

  /// Elements not to draw (the editor draws the one being dragged itself).
  final Set<String> hidden;

  /// Videos play and hints open (the card on top of the stack), or everything stays still.
  final FaceMedia media;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 276.0;
      final h = box.maxHeight.isFinite ? box.maxHeight : w * 384 / 276;
      final k = w / 276;
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final e in layout.els)
              if (!hidden.contains(e.id))
                Positioned(
                  left: e.x * w,
                  top: e.y * h,
                  width: e.w * w,
                  height: e.h * h,
                  child: switch (e) {
                    ImageEl() => PictureView(el: e, k: k, pre: pre, reveal: reveal, media: media),
                    TextEl() => TextView(el: e, texts: texts, k: k, back: back),
                  },
                ),
          ],
        ),
      );
    });
  }
}

/// One picture (or video) in its frame: fill or fit, zoom, pan, corner radius, plate, outline, and the
/// blur that holds it back until the reveal (or, for a hint, until it is tapped).
class PictureView extends StatelessWidget {
  const PictureView({
    super.key,
    required this.el,
    required this.k,
    this.pre = PreReveal.none,
    this.reveal = 1,
    this.forceBlur,
    this.media = FaceMedia.still,
  });

  final ImageEl el;
  final double k;
  final PreReveal pre;
  final double reveal;

  /// Blur at this sigma regardless of the element's own flag (the peek in the reveal button).
  final double? forceBlur;
  final FaceMedia media;

  @override
  Widget build(BuildContext context) {
    if (!el.hint) return _build(el.blur ? reveal.clamp(0.0, 1.0) : 1.0);
    // A hint sharpens when it is tapped open, or with the rest of the card at the reveal.
    final opened = media.hintsOpen.contains(el.id) || reveal >= 1;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: opened ? 1.0 : 0.0),
      duration: Duration(milliseconds: MotionPrefs.reducedOf(context) ? 0 : 480),
      curve: Curves.easeOut,
      builder: (context, t, _) => _build(math.max(t, reveal.clamp(0.0, 1.0))),
    );
  }

  /// [open] is 0 while the picture is held back, 1 once it is in plain sight.
  Widget _build(double open) {
    final al = Alignment(el.panX * 2 - 1, el.panY * 2 - 1);
    Widget content(BoxFit fit, Alignment a) => el.isVideo && media.live && forceBlur == null
        ? CardVideo(el: el, allowed: open >= 0.999, autostart: media.autoPlay, fit: fit, alignment: a)
        : cardImage(el.src, fit: fit, alignment: a);
    // A whole, unzoomed picture is wrapped tightly, so its plate, outline and corners follow the picture
    // itself and not the (larger) frame it sits in.
    if (el.contain && el.aspect > 0 && el.zoom == 1) {
      return LayoutBuilder(builder: (context, box) {
        var w = box.maxWidth, h = box.maxHeight;
        if (w / h > el.aspect) {
          w = h * el.aspect;
        } else {
          h = w / el.aspect;
        }
        return Align(alignment: al, child: SizedBox(width: w, height: h, child: _framed(content(BoxFit.fill, Alignment.center), open)));
      });
    }
    Widget pic = content(el.contain ? BoxFit.contain : BoxFit.cover, al);
    if (el.zoom != 1) pic = Transform.scale(scale: el.zoom, alignment: al, child: pic);
    return _framed(SizedBox.expand(child: ClipRect(child: pic)), open);
  }

  Widget _framed(Widget pic, double open) {
    final held = (el.blur || el.hint) && forceBlur == null;
    final base = el.hint ? pre.hintSigma : pre.sigma;
    final sigma = forceBlur ?? (held && base > 0 ? base * (1 - open) : 0.0);
    if (sigma > 0.05) {
      pic = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: sigma * k, sigmaY: sigma * k, tileMode: TileMode.clamp), child: pic);
    }
    if (held && pre.hide && open < 1) pic = Opacity(opacity: open, child: pic);
    // Where a video does not play, its poster says it is one.
    if (el.isVideo && forceBlur == null && !(media.live && open >= 0.999)) {
      pic = Stack(fit: StackFit.expand, children: [
        pic,
        if (open > 0.5 || !held) Positioned(left: 7 * k, bottom: 7 * k, child: VideoTag(ms: el.videoMs, k: k)),
      ]);
    }
    if (el.hint && forceBlur == null && open < 0.98) pic = _hintCover(pic, open);

    final radius = BorderRadius.circular(el.radius * k);
    Widget framed = ClipRRect(borderRadius: radius, child: pic);
    if (el.plate.isNotEmpty) {
      framed = DecoratedBox(
        decoration: BoxDecoration(color: el.plate == 'paper' ? Mc.paper : Mc.graphite, borderRadius: radius),
        child: Padding(padding: EdgeInsets.all(6 * k), child: framed),
      );
    }
    if (el.outline) {
      framed = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: const Color(0x2E000000), width: 1)),
        child: framed,
      );
    }
    return framed;
  }

  /// "Hint · tap to see" over a hint that is still covered; the whole frame is the button.
  Widget _hintCover(Widget pic, double open) {
    final tap = media.onHint;
    final chip = Opacity(
      opacity: (1 - open).clamp(0.0, 1.0),
      child: Padding(
        padding: EdgeInsets.all(6 * k),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 6 * k),
          decoration: BoxDecoration(color: const Color(0xD9222222), borderRadius: BorderRadius.circular(12 * k)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            McIcon(McIcons.lightbulb, size: Size(15 * k, 15 * k), color: Mc.peach),
            SizedBox(width: 6 * k),
            Text(tap == null ? 'Hint' : (el.isVideo ? 'Hint · tap to watch' : 'Hint · tap to see'),
                style: T.t(13 * k, w: FontWeight.w700, color: Mc.paper)),
          ]),
            ),
          ),
        ),
      ),
    );
    final covered = Stack(fit: StackFit.expand, children: [pic, IgnorePointer(child: chip)]);
    if (tap == null || open > 0) return covered;
    return Semantics(
      button: true,
      label: el.isVideo ? 'Watch the hint' : 'See the hint',
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => tap(el.id), child: covered),
    );
  }
}

/// One text box: the card's words (or your own) in the chosen size, colour and backdrop. Text that does
/// not fit its box shrinks to fit instead of being cut off.
class TextView extends StatelessWidget {
  const TextView({super.key, required this.el, required this.texts, required this.k, required this.back});

  final TextEl el;
  final LayoutTexts texts;
  final double k;
  final bool back;

  String get text => switch (el.source) {
        'main' => texts.main,
        'example' => texts.example,
        'hook' => texts.hook,
        _ => el.text,
      };

  @override
  Widget build(BuildContext context) {
    final t = text.trim();
    if (!el.visible || t.isEmpty) return const SizedBox.shrink();
    final mc = Mc.of(context);
    final isMain = el.source == 'main';
    final onFace = back ? Mc.graphite : mc.onInk;
    final muted = back ? Mc.graphite.withValues(alpha: 0.7) : mc.mutedOnInk;
    final color = switch (el.color) {
      'light' => Mc.paper,
      'dark' => Mc.graphite,
      'peach' => Mc.peach,
      'red' => Mc.red,
      _ => (el.source == 'example' || el.source == 'hook') ? muted : onFace,
    };
    final size = (el.size == 0 ? termSize(t, isMain && texts.code) : el.size) * k;
    final style = isMain && texts.code
        ? T.mono(size, color: color)
        : el.font == 'display'
            ? T.d(size, color: color, height: 1.05)
            : T.t(size, w: el.source == 'example' ? FontWeight.w500 : FontWeight.w700, color: color, height: 1.25);
    final align = switch (el.align) {
      1 => TextAlign.center,
      2 => TextAlign.right,
      _ => TextAlign.left,
    };
    final box = switch (el.align) {
      1 => Alignment.topCenter,
      2 => Alignment.topRight,
      _ => Alignment.topLeft,
    };
    Widget body = Text(t, textAlign: align, textDirection: dirOf(t), style: style);
    if (el.source == 'hook') {
      body = Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: EdgeInsets.only(top: 1 * k), child: McIcon(McIcons.lightbulb, size: Size(size + 2 * k, size + 2 * k), color: color)),
        SizedBox(width: 6 * k),
        Flexible(child: body),
      ]);
    }
    final chip = switch (el.bg) {
      'dark' => const Color(0xB8222222),
      'light' => const Color(0xE6F1F1F1),
      'peach' => Mc.peach,
      _ => null,
    };
    if (chip != null) {
      body = Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * k, vertical: 6 * k),
        decoration: BoxDecoration(color: chip, borderRadius: BorderRadius.circular(10 * k)),
        child: body,
      );
    }
    return LayoutBuilder(
      builder: (context, c) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: box,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: c.maxWidth), child: body),
      ),
    );
  }
}

/// A small square showing a card's picture (lists, search results).
class CardThumb extends StatelessWidget {
  const CardThumb({super.key, required this.card, this.size = 40});
  final CardItem card;
  final double size;

  @override
  Widget build(BuildContext context) {
    final src = card.thumbSrc;
    if (src == null) return const SizedBox.shrink();
    final video = (card.frontLayout?.hasVideo ?? false) || (card.backLayout?.hasVideo ?? false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: Mc.of(context).well,
          child: Stack(fit: StackFit.expand, children: [
            cardImage(src, width: size, height: size, cacheWidth: (size * 3).round()),
            if (video)
              Center(
                child: Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0xB3222222), shape: BoxShape.circle),
                  child: McIcon(McIcons.play, size: Size(size * 0.2, size * 0.2), color: Mc.paper),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Width ÷ height of a card picture, read from the picture itself (null if it cannot be loaded).
Future<double?> measureAspect(String src) {
  final ImageProvider provider = src.startsWith('asset:')
      ? AssetImage(src.substring(6))
      : src.startsWith('data:')
          ? MemoryImage(Uri.parse(src).data!.contentAsBytes())
          : FileImage(File(src));
  final done = Completer<double?>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener((info, _) {
    if (!done.isCompleted) done.complete(info.image.width / info.image.height);
    stream.removeListener(listener);
  }, onError: (_, _) {
    if (!done.isCompleted) done.complete(null);
    stream.removeListener(listener);
  });
  stream.addListener(listener);
  return done.future;
}
