import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store_scope.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/shapes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Settings › Texture: every textured element, its texture and how strong it is. Changes show at once,
/// on this screen's own wall and in the preview at the top.
class TexturePane extends StatelessWidget {
  const TexturePane({super.key});

  static const _elements = <(String id, String title, String note)>[
    ('wallLight', 'Wall · light mode', 'The surface behind every screen in light mode.'),
    ('wallDark', 'Wall · dark mode', 'The surface behind every screen in dark mode.'),
    ('cards', 'Cards', 'Study cards, deck bars, the membership card.'),
    ('tiles', 'Tiles & panels', 'Shop decks, settings groups, stats and lists.'),
    ('buttons', 'Buttons', 'Big buttons, the + diamond, the answer ears.'),
    ('sheets', 'Sheets & dialogs', 'The editor, previews, dialogs and the folder drawer.'),
    ('folders', 'Folders', 'The folders in the drawer.'),
    ('seals', 'Wax seals', 'Goal, mastery and achievement seals.'),
    ('grain', 'Paper grain', 'A fine grain over the whole screen, like printed paper.'),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final t = store.settings.texture;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);

    void edit(void Function(TextureSettings t) fn) => store.updateSettings((s) => fn(s.texture));

    Widget group(List<Widget> children) => Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          margin: const EdgeInsets.only(bottom: 14),
          foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
          decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 30 + mq.padding.bottom),
      children: [
        const _Preview(),
        const SizedBox(height: 16),
        group([
          _SwitchRow(
            title: 'Textures',
            note: 'Real surfaces instead of flat colour. Off makes everything plain.',
            value: t.enabled,
            onChanged: (v) => edit((t) => t.enabled = v),
          ),
        ]),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: t.enabled ? 1 : 0.45,
          child: IgnorePointer(
            ignoring: !t.enabled,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (id, title, note) in _elements.take(2)) group([_LayerEditor(id: id, title: title, note: note)]),
              group([
                _SwitchRow(
                  title: 'Daylight',
                  note: 'Soft light falls across the wall from the top left.',
                  value: t.windowLight,
                  onChanged: (v) => edit((t) => t.windowLight = v),
                ),
                if (t.windowLight)
                  _Strength(value: t.windowStrength, onChanged: (v) => edit((t) => t.windowStrength = v)),
              ]),
              for (final (id, title, note) in _elements.skip(2)) group([_LayerEditor(id: id, title: title, note: note)]),
              group([
                _SwitchRow(
                  title: 'Vignette',
                  note: 'The corners fall into soft shade, like a lit room.',
                  value: t.vignette,
                  onChanged: (v) => edit((t) => t.vignette = v),
                ),
                if (t.vignette)
                  _Strength(value: t.vignetteStrength, onChanged: (v) => edit((t) => t.vignetteStrength = v)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        SoftButton('Back to the default textures', onTap: () {
          Fx.i.tap();
          store.updateSettings((s) => s.texture = TextureSettings());
          Toaster.i.show('Textures reset');
        }),
      ],
    );
  }
}

/// One element: its texture swatches and a strength slider.
class _LayerEditor extends StatelessWidget {
  const _LayerEditor({required this.id, required this.title, required this.note});
  final String id;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final layer = store.settings.texture.layer(id);
    final mc = Mc.of(context);
    void edit(void Function(TextureLayer l) fn) => store.updateSettings((s) => fn(s.texture.layers[id]!));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(title, style: T.t(16, w: FontWeight.w700, color: mc.ink))),
        Text(Textures.nameOf(layer.style), style: T.t(14, w: FontWeight.w600, color: mc.muted)),
      ]),
      Text(note, style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.3)),
      const SizedBox(height: 12),
      // Every choice is visible at once, four to a row: nothing slides out of the panel or gets cut off.
      LayoutBuilder(builder: (context, box) {
        const gap = 8.0, columns = 4;
        final width = ((box.maxWidth - gap * (columns - 1)) / columns).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: [
            for (final style in Textures.choices[id]!)
              _Swatch(
                element: id,
                style: style,
                width: width,
                selected: style == layer.style,
                onTap: () {
                  Fx.i.tap();
                  edit((l) {
                    l.style = style;
                    if (l.strength <= 0) l.strength = 0.5;
                  });
                },
              ),
          ],
        );
      }),
      const SizedBox(height: 4),
      if (layer.style != 'none') _Strength(value: layer.strength, onChanged: (v) => edit((l) => l.strength = v)),
    ]);
  }
}

/// A small square of the element's own colour wearing one texture.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.element, required this.style, required this.width, required this.selected, required this.onTap});
  final String element;
  final String style;

  /// The width of its column; the square is as wide, the name wraps under it.
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final base = switch (element) {
      'wallLight' => Mc.light.canvas,
      'wallDark' => Mc.darkTheme.canvas,
      'cards' || 'buttons' => mc.ink,
      'tiles' => mc.soft,
      'folders' => const Color(0xFF5A5A5A),
      'seals' => Mc.red,
      _ => mc.canvas,
    };
    final mapId = style == 'wall' ? Textures.i.settings.layer(mc.dark ? 'wallDark' : 'wallLight').style : style;
    final def = Textures.def(mapId);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Pressable(
      onTap: onTap,
      label: '${Textures.nameOf(style)}${selected ? ', selected' : ''}',
      child: SizedBox(
        width: width,
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width,
            height: width * 0.86,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? mc.ink : mc.line, width: selected ? 2.5 : 1),
              image: def == null
                  ? null
                  : DecorationImage(
                      image: AssetImage('assets/textures/${def.id}.png'),
                      repeat: ImageRepeat.repeat,
                      alignment: Alignment.topLeft,
                      // A little stronger than in use, so the difference shows at this size.
                      opacity: ((Textures.maxOpacity[element] ?? 0.3) * 1.6).clamp(0.0, 1.0),
                      scale: def.fine ? dpr : def.px / def.tile * 2,
                    ),
            ),
            child: selected
                ? Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: mc.ink, shape: BoxShape.circle),
                      child: Center(child: McIcon(McIcons.done, size: const Size(11, 11), color: mc.canvas)),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 5),
          // Two lines, so "Painted brick" and "Match the wall" show in full.
          Text(
            Textures.nameOf(style),
            maxLines: 2,
            textAlign: TextAlign.center,
            style: T.t(12.5, w: FontWeight.w700, color: selected ? mc.ink : mc.muted, height: 1.1),
          ),
        ]),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.note, required this.value, required this.onChanged});
  final String title;
  final String note;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.t(16, w: FontWeight.w700, color: mc.ink)),
          Text(note, style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.3)),
        ]),
      ),
      const SizedBox(width: 12),
      McSwitch(value: value, onChanged: onChanged, label: title),
    ]);
  }
}

/// Strength, 0–100 %.
class _Strength extends StatelessWidget {
  const _Strength({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Row(children: [
      Text('Strength', style: T.t(14, w: FontWeight.w600, color: mc.muted)),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: mc.ink,
            inactiveTrackColor: mc.line,
            thumbColor: mc.ink,
            overlayColor: mc.ink.withValues(alpha: 0.08),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            divisions: 20,
            onChanged: (v) => onChanged(double.parse(v.toStringAsFixed(2))),
          ),
        ),
      ),
      SizedBox(
        width: 40,
        child: Text('${(value * 100).round()}%',
            textAlign: TextAlign.right, style: T.t(14, w: FontWeight.w700, color: mc.ink)),
      ),
    ]);
  }
}

/// A little room: a wall, a study card, a deck tile, a button, a folder and a seal, all wearing the current
/// textures. Everything has its own place: nothing overlaps and nothing runs off the edge.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 224,
        decoration: BoxDecoration(
          color: mc.canvas,
          border: Border.all(color: mc.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Wall(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // A study card.
              SizedBox(
                width: 114,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Transform.rotate(
                    angle: -0.05,
                    child: Container(
                      height: 152,
                      padding: const EdgeInsets.all(12),
                      foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(14)),
                      decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(14), boxShadow: mc.cardShadow),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('NOUN', style: T.caps(9, color: mc.mutedOnInk)),
                        const SizedBox(height: 4),
                        Text('el gato', style: T.d(26, color: mc.onInk)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(children: [
                  // A deck tile and a button.
                  SizedBox(
                    height: 72,
                    child: Row(children: [
                      Container(
                        width: 72,
                        foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(14)),
                        decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14), boxShadow: mc.e1),
                        alignment: Alignment.center,
                        child: Text('Es', style: T.d(30, color: mc.ink)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Center(
                          child: Container(
                            height: 40,
                            foregroundDecoration: texDeco(context, 'buttons', BorderRadius.circular(12)),
                            decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(12), boxShadow: mc.e2),
                            alignment: Alignment.center,
                            child: Text('Study', style: T.d(20, color: mc.canvas)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  // A folder and a seal.
                  Expanded(
                    child: Row(children: [
                      Expanded(
                        child: LayoutBuilder(builder: (context, box) {
                          // A folder is drawn from a tab and a body: it needs room for both.
                          final tab = (box.maxWidth * 0.5).clamp(48.0, 70.0);
                          return CustomPaint(
                            size: Size(box.maxWidth, box.maxHeight),
                            painter: FolderPainter(tabWidth: tab, c1: const Color(0xFF6A6A6A), c2: const Color(0xFF555555), shadowAlpha: 0.3),
                            foregroundPainter: texPainter(context, 'folders', (s) => FolderShape.path(s.width, s.height, tab)),
                          );
                        }),
                      ),
                      const SizedBox(width: 10),
                      const WaxSeal(size: 54, check: true),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
