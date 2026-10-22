import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/models.dart';
import 'theme.dart';

/// One texture map (assets/textures/ID.png, made by tools/make_textures.py): a seamless tile, white
/// where the surface is lighter and black where it is darker, the amount in alpha. Painted with plain
/// alpha blending it lightens and darkens any colour, in both themes.
class TextureDef {
  const TextureDef(this.id, this.name, this.tile, {this.fine = false, this.px = 256});
  final String id;
  final String name;

  /// Width of the map in pixels.
  final int px;

  /// Logical size of one repeat.
  final double tile;

  /// Drawn at one map pixel per device pixel (grain), whatever the screen density.
  final bool fine;
}

/// The texture catalogue, the images (loaded on first use) and the current choices.
class Textures extends ChangeNotifier {
  Textures._();
  static final i = Textures._();

  static const all = <TextureDef>[
    TextureDef('plaster', 'Plaster', 360, px: 512),
    TextureDef('limewash', 'Limewash', 380, px: 512),
    TextureDef('stucco', 'Stucco', 300, px: 512),
    TextureDef('brick', 'Painted brick', 300, px: 512),
    TextureDef('concrete', 'Concrete', 340, px: 512),
    TextureDef('slate', 'Slate', 360, px: 512),
    TextureDef('felt', 'Felt', 300, px: 512),
    TextureDef('cardstock', 'Card stock', 150),
    TextureDef('linen', 'Linen', 128),
    TextureDef('laid', 'Laid paper', 140),
    TextureDef('pressed', 'Pressed', 120),
    TextureDef('kraft', 'Kraft', 150),
    TextureDef('wax', 'Wax', 110),
    TextureDef('grain_fine', 'Fine grain', 0, fine: true),
    TextureDef('grain_coarse', 'Coarse grain', 0, fine: true),
  ];

  /// What each element can wear ('none' is plain; 'wall' on sheets follows the wall).
  static const choices = <String, List<String>>{
    'wallLight': ['none', 'plaster', 'limewash', 'stucco', 'brick', 'concrete', 'slate', 'felt'],
    'wallDark': ['none', 'felt', 'slate', 'concrete', 'plaster', 'stucco', 'limewash', 'brick'],
    'cards': ['none', 'cardstock', 'linen', 'laid', 'pressed', 'felt', 'kraft', 'grain_fine'],
    'tiles': ['none', 'cardstock', 'linen', 'laid', 'pressed', 'felt', 'grain_fine'],
    'buttons': ['none', 'cardstock', 'linen', 'pressed', 'grain_fine'],
    'sheets': ['wall', 'none', 'plaster', 'limewash', 'cardstock', 'linen', 'laid'],
    'folders': ['none', 'kraft', 'cardstock', 'linen', 'pressed', 'felt'],
    'seals': ['none', 'wax', 'pressed', 'grain_coarse'],
    'grain': ['none', 'grain_fine', 'grain_coarse'],
  };

  /// Opacity at full strength: walls stay quiet, grain is a whisper.
  static const maxOpacity = <String, double>{
    'wallLight': 0.34,
    'wallDark': 0.42,
    'cards': 0.26,
    'tiles': 0.34,
    'buttons': 0.3,
    'sheets': 0.36,
    'folders': 0.42,
    'seals': 0.5,
    'grain': 0.16,
  };

  static TextureDef? def(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  static String nameOf(String id) => id == 'none' ? 'None' : (id == 'wall' ? 'Match the wall' : def(id)?.name ?? id);

  TextureSettings _settings = TextureSettings();
  String _key = '';
  TextureSettings get settings => _settings;

  final _images = <String, ui.Image>{};
  final _loading = <String, Future<void>>{};

  /// Takes the user's choices; repaints textured widgets only when something actually changed.
  void update(TextureSettings s) {
    final key = jsonEncode(s.toJson());
    _settings = s;
    if (key == _key) return;
    _key = key;
    for (final l in s.layers.values) {
      if (l.on) load(l.style);
    }
    notifyListeners();
  }

  /// Loads the maps in use (call before the first frame so the walls are there from the start).
  Future<void> preload(TextureSettings s) async {
    _settings = s;
    _key = jsonEncode(s.toJson());
    await Future.wait([
      for (final l in s.layers.values)
        if (l.on) load(l.style),
    ]);
  }

  ui.Image? image(String id) {
    final img = _images[id];
    if (img == null) load(id);
    return img;
  }

  Future<void> load(String id) {
    if (_images.containsKey(id) || def(id) == null) return Future.value();
    // Through Flutter's image cache: the painters here and every container's DecorationImage share one
    // decoded copy, warm before those containers first paint.
    return _loading[id] ??= () async {
      final done = Completer<void>();
      final stream = AssetImage('assets/textures/$id.png').resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          _images[id] = info.image.clone();
          info.dispose();
          stream.removeListener(listener);
          if (!done.isCompleted) done.complete();
        },
        // Missing or undecodable map: that element simply stays plain.
        onError: (_, _) {
          stream.removeListener(listener);
          if (!done.isCompleted) done.complete();
        },
      );
      stream.addListener(listener);
      await done.future;
      _loading.remove(id);
      if (_images.containsKey(id)) notifyListeners();
    }();
  }

  /// Which texture [element] wears right now and how opaque (null when plain), resolved for the theme.
  ({TextureDef def, double opacity})? resolveLayer(String element, {required bool dark}) {
    final s = _settings;
    if (!s.enabled) return null;
    var layer = s.layer(element);
    var style = layer.style;
    var opacityKey = element;
    if (element == 'sheets' && style == 'wall') {
      final wall = s.layer(dark ? 'wallDark' : 'wallLight');
      style = wall.style;
      opacityKey = dark ? 'wallDark' : 'wallLight';
      layer = TextureLayer(style, wall.strength * layer.strength * 2);
    }
    if (style == 'none' || layer.strength <= 0) return null;
    final d = def(style);
    if (d == null) return null;
    return (def: d, opacity: (layer.strength * (maxOpacity[opacityKey] ?? 0.3)).clamp(0.0, 1.0));
  }

  /// The layer to draw for [element] right now (null when plain), resolved for the theme.
  ({ui.Image image, TextureDef def, double opacity})? resolve(String element, {required bool dark}) {
    final s = _settings;
    if (!s.enabled) return null;
    var layer = s.layer(element);
    var style = layer.style;
    var opacityKey = element;
    if (element == 'sheets' && style == 'wall') {
      final wall = s.layer(dark ? 'wallDark' : 'wallLight');
      style = wall.style;
      opacityKey = dark ? 'wallDark' : 'wallLight';
      layer = TextureLayer(style, wall.strength * layer.strength * 2);
    }
    if (style == 'none' || layer.strength <= 0) return null;
    final d = def(style);
    final img = d == null ? null : image(style);
    if (d == null || img == null) return null;
    return (image: img, def: d, opacity: (layer.strength * (maxOpacity[opacityKey] ?? 0.3)).clamp(0.0, 1.0));
  }
}

/// Paints one texture map, repeated, at [opacity].
class TexturePainter extends CustomPainter {
  TexturePainter({
    required this.image,
    required this.def,
    required this.opacity,
    required this.dpr,
    this.radius = BorderRadius.zero,
    this.shape,
    this.origin = Offset.zero,
  });

  final ui.Image image;
  final TextureDef def;
  final double opacity;
  final double dpr;
  final BorderRadius radius;

  /// A custom outline (folders); otherwise the rounded rect.
  final Path Function(Size size)? shape;

  /// Where the pattern starts, so neighbouring pieces don't all begin at the same spot.
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || size.isEmpty) return;
    final tile = def.fine ? image.width / dpr : def.tile;
    final scale = tile / image.width;
    final m = Matrix4.identity()
      ..translateByDouble(origin.dx, origin.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    final paint = Paint()
      ..shader = ImageShader(image, TileMode.repeated, TileMode.repeated, m.storage, filterQuality: FilterQuality.medium)
      // Opacity as a colour filter: honoured with shaders by every renderer.
      ..colorFilter = ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, opacity, 0,
      ]);
    final rect = Offset.zero & size;
    if (shape != null) {
      canvas.drawPath(shape!(size), paint);
    } else if (radius == BorderRadius.zero) {
      canvas.drawRect(rect, paint);
    } else {
      canvas.drawRRect(radius.toRRect(rect), paint);
    }
  }

  @override
  bool shouldRepaint(TexturePainter old) =>
      old.image != image || old.opacity != opacity || old.def != def || old.radius != radius || old.dpr != dpr || old.origin != origin;
}

/// A texture laid over [child] for one element ('cards', 'tiles', 'buttons', 'sheets', 'folders',
/// 'seals'), clipped to [radius] (or [shape]). Plain when that element's texture is off.
class Textured extends StatelessWidget {
  const Textured({
    super.key,
    required this.element,
    required this.child,
    this.radius = BorderRadius.zero,
    this.shape,
    this.seed = 0,
  });

  final String element;
  final Widget child;
  final BorderRadius radius;
  final Path Function(Size size)? shape;

  /// Shifts the pattern, so a list of identical cards doesn't repeat the same spots.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final dark = Mc.of(context).dark;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ListenableBuilder(
      listenable: Textures.i,
      child: child,
      builder: (context, child) {
        final t = Textures.i.resolve(element, dark: dark);
        if (t == null) return child!;
        return Stack(fit: StackFit.passthrough, children: [
          child!,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: TexturePainter(
                  image: t.image,
                  def: t.def,
                  opacity: t.opacity,
                  dpr: dpr,
                  radius: radius,
                  shape: shape,
                  origin: Offset((seed * 97 % 211).toDouble(), (seed * 61 % 173).toDouble()),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

/// The wall behind a screen: its texture, and soft daylight across it. Put [child] (the screen) on top.
class Wall extends StatelessWidget {
  const Wall({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Mc.of(context).dark;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Stack(fit: StackFit.expand, children: [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: ListenableBuilder(
              listenable: Textures.i,
              builder: (context, _) {
                final s = Textures.i.settings;
                final t = Textures.i.resolve(dark ? 'wallDark' : 'wallLight', dark: dark);
                return CustomPaint(
                  painter: _WallPainter(
                    texture: t == null
                        ? null
                        : TexturePainter(image: t.image, def: t.def, opacity: t.opacity, dpr: dpr),
                    light: s.enabled && s.windowLight ? s.windowStrength : 0,
                    dark: dark,
                  ),
                );
              },
            ),
          ),
        ),
      ),
      child,
    ]);
  }
}

class _WallPainter extends CustomPainter {
  _WallPainter({required this.texture, required this.light, required this.dark});
  final TexturePainter? texture;
  final double light;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    texture?.paint(canvas, size);
    if (light <= 0) return;
    // Daylight from the top left, falling off across the wall; the far corner sits in soft shade.
    final rect = Offset.zero & size;
    final r = math.max(size.width, size.height) * 1.25;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-1.1, -1.15),
          radius: r / size.shortestSide,
          colors: [
            Colors.white.withValues(alpha: (dark ? 0.07 : 0.55) * light),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: (dark ? 0.16 : 0.07) * light),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_WallPainter old) =>
      old.light != light || old.dark != dark || (old.texture == null) != (texture == null) ||
      (texture != null && texture!.shouldRepaint(old.texture!));
}

/// Over the whole app: paper grain and a soft vignette, when chosen. Never takes a touch.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: Textures.i,
          builder: (context, _) {
            final s = Textures.i.settings;
            final t = Textures.i.resolve('grain', dark: dark);
            final vig = s.enabled && s.vignette ? s.vignetteStrength : 0.0;
            if (t == null && vig == 0) return const SizedBox.expand();
            return CustomPaint(
              size: Size.infinite,
              painter: _OverlayPainter(
                grain: t == null ? null : TexturePainter(image: t.image, def: t.def, opacity: t.opacity, dpr: dpr),
                vignette: vig,
                dark: dark,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({required this.grain, required this.vignette, required this.dark});
  final TexturePainter? grain;
  final double vignette;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    grain?.paint(canvas, size);
    if (vignette <= 0) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: (dark ? 0.5 : 0.22) * vignette)],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.vignette != vignette || old.dark != dark || (old.grain == null) != (grain == null) ||
      (grain != null && grain!.shouldRepaint(old.grain!));
}

/// Puts [Textures] in the tree, so [texDeco] users rebuild when a texture setting changes.
class TextureScope extends InheritedNotifier<Textures> {
  TextureScope({super.key, required super.child}) : super(notifier: Textures.i);

  static void watch(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TextureScope>();
}

/// [element]'s texture as a repeating decoration image (null when plain). Put it in a BoxDecoration's
/// `image:` to texture a panel's background under its content.
DecorationImage? texImage(BuildContext context, String element) {
  TextureScope.watch(context);
  final t = Textures.i.resolveLayer(element, dark: Mc.of(context).dark);
  if (t == null) return null;
  final scale = t.def.fine ? MediaQuery.devicePixelRatioOf(context) : t.def.px / t.def.tile;
  return DecorationImage(
    image: AssetImage('assets/textures/${t.def.id}.png'),
    repeat: ImageRepeat.repeat,
    alignment: Alignment.topLeft,
    opacity: t.opacity,
    scale: scale,
    filterQuality: FilterQuality.medium,
  );
}

/// A foreground decoration that lays [element]'s texture over a container, clipped to [radius]; null
/// when that element is plain. Use as `foregroundDecoration:` on a Container.
Decoration? texDeco(BuildContext context, String element, [BorderRadiusGeometry? radius]) {
  final image = texImage(context, element);
  return image == null ? null : BoxDecoration(borderRadius: radius, image: image);
}

/// A painter for [element]'s texture inside a custom outline (folders, seals); null when plain.
TexturePainter? texPainter(BuildContext context, String element, Path Function(Size size) shape) {
  TextureScope.watch(context);
  final t = Textures.i.resolve(element, dark: Mc.of(context).dark);
  if (t == null) return null;
  return TexturePainter(
    image: t.image,
    def: t.def,
    opacity: t.opacity,
    dpr: MediaQuery.devicePixelRatioOf(context),
    shape: shape,
  );
}
