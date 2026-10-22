import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/store_scope.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../editor/editor_sheet.dart';
import '../shell/shell.dart';
import '../shop/preview_sheet.dart';

/// "Empty mind" (canvas EmptyFolder.dc.html): a breathing brain with three floating question marks.
class EmptyFolder extends StatelessWidget {
  const EmptyFolder({super.key, required this.folder, required this.bottom});

  final Folder? folder;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final store = context.store;
    final starters = _starters(store.catalog, folder?.name ?? '', store.data.shopAdded.keys.toSet());
    return LayoutBuilder(builder: (context, box) {
      final compact = box.maxHeight < 640;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, compact ? 4 : 22, 28, bottom + 24),
        child: Column(
          children: [
            SizedBox(width: 240, height: compact ? 150 : 190, child: FittedBox(child: const BrainArt())),
            const SizedBox(height: 18),
            Text('Empty mind', style: T.d(46, color: mc.ink)),
            const SizedBox(height: 10),
            Text(
              folder == null ? 'Make a folder to start.' : 'Nothing to remember in this folder yet.',
              textAlign: TextAlign.center,
              style: T.t(18, w: FontWeight.w500, color: mc.muted, height: 1.35),
            ),
            const SizedBox(height: 22),
            InkButton('Look for something to remember', onTap: () => Shell.of(context).openShop()),
            const SizedBox(height: 10),
            SoftButton('Create a deck', onTap: () => showEditor(context, folderId: folder?.id, newDeck: true)),
            if (starters.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Align(alignment: Alignment.centerLeft, child: SectionLabel('Start here', size: 14)),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < starters.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _Starter(deck: starters[i], index: i, folderId: folder?.id)),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  static List<CatalogDeck> _starters(Catalog c, String folderName, Set<String> added) {
    final name = folderName.toLowerCase();
    final cat = CatalogCategory.all.where((x) => name.contains(x.name.toLowerCase()) || name.contains(x.id)).firstOrNull;
    final pool = c.decks.where((d) => !added.contains(d.id)).toList();
    final picked = <CatalogDeck>[];
    if (cat != null) picked.addAll(pool.where((d) => d.category == cat.id).take(3));
    for (final id in const ['de-a1-basics', 'python-syntax', 'es-basics', 'it-basics', 'world-capitals']) {
      if (picked.length >= 3) break;
      final d = c.byId(id);
      if (d != null && !added.contains(id) && !picked.contains(d)) picked.add(d);
    }
    return picked.take(3).toList();
  }
}

class _Starter extends StatelessWidget {
  const _Starter({required this.deck, required this.index, required this.folderId});
  final CatalogDeck deck;
  final int index;
  final String? folderId;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final colors = [Mc.blue, Mc.peach, mc.ink];
    final bg = colors[index % 3];
    final fg = index % 3 == 2 ? mc.canvas : Mc.graphite;
    return Pressable(
      onTap: () => showPreview(context, deck.id, folderId: folderId),
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40), bottom: Radius.circular(14)),
          boxShadow: mc.e1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(deck.mono, textAlign: TextAlign.center, style: T.d(30, color: fg)),
            ),
            Text(deck.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.t(13, w: FontWeight.w700, color: fg, height: 1.15)),
          ],
        ),
      ),
    );
  }
}

/// The brain illustration: cerebrum, cerebellum, four folds, a gloss, breathing; three "?" float above.
class BrainArt extends StatelessWidget {
  const BrainArt({super.key});

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return AmbientClock(
      builder: (context, ms) => CustomPaint(size: const Size(240, 190), painter: _BrainPainter(ms, mc)),
    );
  }
}

class _BrainPainter extends CustomPainter {
  _BrainPainter(this.ms, this.mc);
  final double ms;
  final Mc mc;

  static final _cerebellum = Path()
    ..moveTo(134, 120)
    ..cubicTo(142, 108, 170, 104, 184, 114)
    ..cubicTo(194, 122, 190, 138, 174, 141)
    ..cubicTo(158, 144, 142, 138, 134, 128)
    ..close();

  static final _cerebrum = Path()
    ..moveTo(40, 110)
    ..cubicTo(22, 96, 20, 62, 42, 50)
    ..cubicTo(48, 30, 78, 22, 92, 34)
    ..cubicTo(104, 18, 134, 18, 144, 32)
    ..cubicTo(160, 24, 184, 40, 180, 62)
    ..cubicTo(196, 74, 190, 104, 170, 108)
    ..cubicTo(160, 116, 142, 112, 132, 118)
    ..cubicTo(118, 132, 84, 134, 70, 122)
    ..cubicTo(58, 130, 38, 124, 40, 110)
    ..close();

  static final _folds = [
    Path()
      ..moveTo(64, 104)
      ..cubicTo(84, 96, 106, 98, 130, 90),
    Path()
      ..moveTo(114, 26)
      ..cubicTo(106, 44, 118, 58, 104, 86),
    Path()
      ..moveTo(52, 70)
      ..cubicTo(62, 62, 74, 68, 82, 58),
    Path()
      ..moveTo(136, 46)
      ..cubicTo(144, 60, 160, 56, 164, 72),
  ];

  static final _gloss = Path()
    ..moveTo(52, 52)
    ..cubicTo(60, 42, 74, 36, 86, 38);

  @override
  void paint(Canvas canvas, Size size) {
    final breathe = 1 + 0.018 * math.sin(ms / 3200 * math.pi * 2);
    canvas.save();
    canvas.translate(100, 100);
    canvas.scale(breathe);
    canvas.translate(-100, -100);
    canvas.translate(-8, 18);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: mc.dark ? 0.6 : 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(_cerebrum.shift(const Offset(0, 10)), shadow);
    canvas.drawPath(_cerebellum, Paint()..color = mc.ink2);
    canvas.drawPath(_cerebrum, Paint()..color = mc.ink);
    final fold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = mc.canvas;
    for (final f in _folds) {
      canvas.drawPath(f, fold);
    }
    canvas.drawPath(_gloss, fold..color = mc.gloss);
    canvas.restore();

    const marks = [(192.0, 76.0, 8.0, 22.0), (207.0, 58.0, 12.0, 28.0), (222.0, 42.0, 16.0, 34.0)];
    for (var i = 0; i < marks.length; i++) {
      final (x, y, tilt, fs) = marks[i];
      final a = ms / 4000 * math.pi * 2 + i * 0.8;
      final tp = TextPainter(
        text: TextSpan(text: '?', style: T.d(fs, color: Mc.red)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(x + 3 * math.sin(a), y - 3 * math.cos(a));
      canvas.rotate(tilt * math.pi / 180);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height * 0.8));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BrainPainter old) => old.ms != ms || old.mc != mc;
}
