import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/store_scope.dart';
import '../../data/widget_snapshot.dart';
import '../../services/home_widgets.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/routes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Settings › Home screen widgets: how the widgets look (shown on live pictures of them), and every widget with a
/// preview, the face you want it to wear, and an Add button.
class WidgetsScreen extends StatelessWidget {
  const WidgetsScreen({super.key});

  static Route<void> route() => McPageRoute(builder: (_) => const WidgetsScreen());

  /// The accent colours (the same as the widgets' own: android/.../widgets/Look.kt).
  static const accents = {
    'red': Color(0xFFD35F5F),
    'orange': Color(0xFFE08A3E),
    'green': Color(0xFF4E9E68),
    'blue': Color(0xFF5C86DA),
    'violet': Color(0xFF8A6FD4),
  };

  /// The name a widget goes by in the Look settings (HomeWidgets.kinds is by provider class).
  static const kindOf = {
    'SealWidget': 'seal',
    'StreakWidget': 'streak',
    'StreakTallWidget': 'streak',
    'TodayWidget': 'today',
    'QuickCardWidget': 'quick',
    'ActionsWidget': 'actions',
    'ActionsGridWidget': 'actionsgrid',
    'ActivityWidget': 'activity',
    'ForecastWidget': 'forecast',
    'MembershipWidget': 'membership',
    'CardOfDayWidget': 'cotd',
    'SealsWidget': 'seals',
    'DecksWidget': 'decks',
  };

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.settings;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final look = widgetLook(s);

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.only(bottom: 8), child: SectionLabel(title)),
            child,
          ]),
        );

    Widget panel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
          padding: padding,
          foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
          decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(t, style: T.t(16, w: FontWeight.w700, color: mc.ink)),
        );

    return Scaffold(
      backgroundColor: mc.canvas,
      body: Wall(
        child: Column(children: [
          SizedBox(height: mq.padding.top),
          SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 18, 16, 0),
              child: Row(children: [
                IconTap(icon: McIcons.back, size: const Size(26, 26), label: 'Back', onTap: () => Navigator.pop(context)),
                const SizedBox(width: 6),
                Text('Widgets', style: T.d(34, color: mc.ink)),
              ]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 30 + mq.padding.bottom),
              children: [
                Text(
                  'Memory Card on your home screen: today\'s goal, your streak, cards to review in place, and more. '
                  'Everything is drawn on the phone from your own numbers.',
                  style: T.t(15, w: FontWeight.w500, color: mc.muted, height: 1.35),
                ),
                const SizedBox(height: 16),
                section(
                  'Look',
                  panel([
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _Preview('SealWidget', look: look),
                          const SizedBox(width: 12),
                          Column(children: [
                            _Preview('StreakWidget', look: look),
                            const SizedBox(height: 12),
                            _Preview('SealWidget', look: look, h: 108),
                          ]),
                        ]),
                      ),
                    ),
                    label('Theme'),
                    Seg<String>(
                      options: const ['auto', 'light', 'dark'],
                      value: s.widgetTheme,
                      labelOf: (v) => const {'auto': 'Follow phone', 'light': 'Light', 'dark': 'Dark'}[v]!,
                      fontSize: 15,
                      onPick: (v) => store.updateSettings((x) => x.widgetTheme = v),
                    ),
                    label('Accent'),
                    Row(children: [
                      for (final e in accents.entries) ...[
                        _Swatch(color: e.value, name: e.key, selected: s.widgetAccent == e.key, onTap: () => store.updateSettings((x) => x.widgetAccent = e.key)),
                        const SizedBox(width: 12),
                      ],
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('The seal, the flame and the rings.', style: T.t(14, w: FontWeight.w500, color: mc.muted)),
                    ),
                    label('Corners'),
                    Seg<String>(
                      options: const ['round', 'soft', 'square'],
                      value: s.widgetCorners,
                      labelOf: (v) => v[0].toUpperCase() + v.substring(1),
                      fontSize: 15,
                      onPick: (v) => store.updateSettings((x) => x.widgetCorners = v),
                    ),
                    label('Background'),
                    Row(children: [
                      Expanded(
                        child: McSlider(
                          value: s.widgetOpacity.toDouble(),
                          min: 30,
                          max: 100,
                          divisions: 14,
                          label: 'Widget background',
                          onChanged: (v) => store.updateSettings((x) => x.widgetOpacity = v.round()),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('${s.widgetOpacity}%', textAlign: TextAlign.right, style: T.t(14, w: FontWeight.w700, color: mc.ink)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Motion', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                          Text(
                            s.reducedMotion
                                ? 'Off while Reduced motion is on (Settings › Feel)'
                                : 'The seal turns, the flame flickers, cards turn over',
                            style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.3),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      McSwitch(value: s.widgetMotion, label: 'Widget motion', onChanged: (v) => store.updateSettings((x) => x.widgetMotion = v)),
                    ]),
                  ]),
                ),
                section(
                  'Add a widget',
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final e in HomeWidgets.kinds.entries) _WidgetRow(cls: e.key, name: e.value, look: look),
                  ]),
                ),
                section(
                  'Quick Settings',
                  panel([
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Memory Card tile', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                          Text('Swipe down from the top: "8 to go · tap to study".', style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.3)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      SoftButton('Add', height: 42, color: mc.ink, textColor: mc.canvas, onTap: () => _addTile(context)),
                    ]),
                  ]),
                ),
                Text(
                  'Answers on the Quick card count as reviews, Again or Good, the next time you open the app.',
                  style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _addTile(BuildContext context) async {
    final r = await HomeWidgets.i.addTile();
    Toaster.i.show(switch (r) {
      'added' => 'Tile added to Quick Settings',
      'already' => 'The tile is already in Quick Settings',
      'declined' => 'Not added',
      _ => 'Pull down Quick Settings, tap the pencil, and drag Memory Card in',
    });
  }
}

/// A colour you can pick.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.name, required this.selected, required this.onTap});
  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name accent',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? mc.ink : Colors.transparent, width: 3),
            boxShadow: mc.e1,
          ),
          child: selected ? Icon(Icons.check_rounded, size: 20, color: Colors.white.withValues(alpha: 0.95)) : null,
        ),
      ),
    );
  }
}

/// One widget: its name and sizes; opened, a preview, the face it wears, and an Add button.
class _WidgetRow extends StatefulWidget {
  const _WidgetRow({required this.cls, required this.name, required this.look});
  final String cls;
  final String name;
  final Map<String, Object?> look;

  @override
  State<_WidgetRow> createState() => _WidgetRowState();
}

class _WidgetRowState extends State<_WidgetRow> {
  bool _open = false;

  Future<void> _add() async {
    if (await HomeWidgets.i.canPin()) {
      await HomeWidgets.i.pin(widget.cls);
    } else {
      Toaster.i.show('Long-press your home screen, tap Widgets, then find Memory Card');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.settings;
    final mc = Mc.of(context);
    final kind = WidgetsScreen.kindOf[widget.cls]!;
    final face = s.widgetSurfaces[kind] ?? '';
    final size = HomeWidgets.previewSize[widget.cls]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
      decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Pressable(
          onTap: () => setState(() => _open = !_open),
          scale: 0.99,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.name, style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                  Text(HomeWidgets.sizes[widget.cls]!, style: T.t(13, w: FontWeight.w600, color: mc.muted)),
                ]),
              ),
              AnimatedRotation(
                turns: _open ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: McIcon(McIcons.chevron, size: const Size(18, 18), color: mc.muted),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: McCurves.paper,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _Preview(widget.cls, look: widget.look, w: size.$1, h: size.$2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Face', style: T.t(15, w: FontWeight.w700, color: mc.ink)),
                    const SizedBox(height: 8),
                    Seg<String>(
                      options: const ['', 'paper', 'ink'],
                      value: face,
                      height: 34,
                      fontSize: 14,
                      background: mc.canvas,
                      labelOf: (v) => const {'': 'As designed', 'paper': 'Paper', 'ink': 'Ink'}[v]!,
                      onPick: (v) => store.updateSettings((x) {
                        if (v.isEmpty) {
                          x.widgetSurfaces.remove(kind);
                        } else {
                          x.widgetSurfaces[kind] = v;
                        }
                      }),
                    ),
                    if (widget.cls == 'QuickCardWidget') ...[
                      const SizedBox(height: 14),
                      Text('Layout (4×2)', style: T.t(15, w: FontWeight.w700, color: mc.ink)),
                      const SizedBox(height: 8),
                      Seg<String>(
                        options: const ['stacked', 'side'],
                        value: s.widgetQuick,
                        height: 34,
                        fontSize: 14,
                        background: mc.canvas,
                        labelOf: (v) => v == 'side' ? 'Side by side' : 'Stacked',
                        onPick: (v) => store.updateSettings((x) => x.widgetQuick = v),
                      ),
                    ],
                    const SizedBox(height: 14),
                    InkButton('Add to home screen', height: 46, size: 20, onTap: _add),
                  ]),
                ),
        ),
      ]),
    );
  }
}

/// A live picture of a widget, drawn by the same code the home screen uses.
class _Preview extends StatefulWidget {
  const _Preview(this.cls, {required this.look, this.w, this.h});
  final String cls;
  final Map<String, Object?> look;
  final double? w;
  final double? h;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  Future<Uint8List?>? _pending;
  Uint8List? _last;
  String _key = '';

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final size = HomeWidgets.previewSize[widget.cls]!;
    final w = widget.w ?? size.$1;
    final h = widget.h ?? size.$2;
    final key = '${widget.cls}|${jsonEncode(widget.look)}|$night|$w|$h';
    if (key != _key) {
      _key = key;
      final f = HomeWidgets.i.preview(widget.cls, look: widget.look, night: night, w: w, h: h);
      _pending = f;
      f.then((bytes) {
        if (!mounted || _pending != f || bytes == null) return;
        setState(() => _last = bytes);
      });
    }
    final bytes = _last;
    return SizedBox(
      width: w,
      height: h,
      child: bytes == null
          ? null
          : Image.memory(bytes, scale: MediaQuery.devicePixelRatioOf(context), gaplessPlayback: true, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
    );
  }
}
