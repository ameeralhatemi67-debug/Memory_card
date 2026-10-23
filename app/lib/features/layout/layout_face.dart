import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/card_layout.dart';
import '../../data/models.dart';
import '../../ui/icons.dart';
import '../../ui/theme.dart';

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
  const PreReveal(this.sigma, {this.hide = false});

  /// Gaussian blur, in pixels on a 276-wide face; 0 = none.
  final double sigma;

  /// Not even a blur: the picture is invisible until the reveal.
  final bool hide;

  static const none = PreReveal(0);

  factory PreReveal.of(Settings s) => switch (s.imageReveal) {
        'hide' => const PreReveal(0, hide: true),
        'show' => none,
        _ => PreReveal(s.blurSigma),
      };

  bool get active => sigma > 0 || hide;
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
                    ImageEl() => PictureView(el: e, k: k, pre: pre, reveal: reveal),
                    TextEl() => TextView(el: e, texts: texts, k: k, back: back),
                  },
                ),
          ],
        ),
      );
    });
  }
}

/// One picture in its frame: fill or fit, zoom, pan, corner radius, plate, outline, reveal blur.
class PictureView extends StatelessWidget {
  const PictureView({super.key, required this.el, required this.k, this.pre = PreReveal.none, this.reveal = 1, this.forceBlur});

  final ImageEl el;
  final double k;
  final PreReveal pre;
  final double reveal;

  /// Blur at this sigma regardless of the element's own flag (the peek in the reveal button).
  final double? forceBlur;

  @override
  Widget build(BuildContext context) {
    final al = Alignment(el.panX * 2 - 1, el.panY * 2 - 1);
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
        return Align(alignment: al, child: SizedBox(width: w, height: h, child: _framed(cardImage(el.src, fit: BoxFit.fill))));
      });
    }
    Widget pic = cardImage(el.src, fit: el.contain ? BoxFit.contain : BoxFit.cover, alignment: al);
    if (el.zoom != 1) pic = Transform.scale(scale: el.zoom, alignment: al, child: pic);
    return _framed(SizedBox.expand(child: ClipRect(child: pic)));
  }

  Widget _framed(Widget pic) {

    final sigma = forceBlur ?? (el.blur && pre.sigma > 0 ? pre.sigma * (1 - reveal.clamp(0.0, 1.0)) : 0.0);
    if (sigma > 0.05) {
      pic = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: sigma * k, sigmaY: sigma * k, tileMode: TileMode.clamp), child: pic);
    }
    if (el.blur && pre.hide && forceBlur == null && reveal < 1) pic = Opacity(opacity: reveal.clamp(0.0, 1.0), child: pic);

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: Mc.of(context).well,
          child: cardImage(src, width: size, height: size, cacheWidth: (size * 3).round()),
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
