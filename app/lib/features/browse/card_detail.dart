import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../engine/assessor.dart';
import '../../engine/days.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/routes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../editor/editor_sheet.dart';
import '../study/card_face.dart';

/// "Why this card?": the card's memory, its forgetting curve and every answer you gave it.
class CardDetail extends StatelessWidget {
  const CardDetail({super.key, required this.cardId});
  final String cardId;

  static Route<void> route(String cardId) => McPageRoute(builder: (_) => CardDetail(cardId: cardId));

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final c = store.data.cards[cardId];
    if (c == null) {
      return Scaffold(backgroundColor: mc.canvas, body: Wall(child: Center(child: Text('This card was deleted', style: T.d(26, color: mc.ink)))));
    }
    final deck = store.data.decks[c.deckId];
    final now = store.now();
    final r = store.engine.recall(c, now);
    final slip = store.engine.slipsAt(c);
    final events = c.events.reversed.toList();

    String when(int ms) {
      final d = dayNumber(ms) - dayNumber(now);
      if (d == 0) return 'today';
      if (d == 1) return 'tomorrow';
      if (d == -1) return 'yesterday';
      return d > 0 ? 'in $d days' : '${-d} days ago';
    }

    String until(int ms) {
      final d = dayNumber(ms) - dayNumber(now);
      return d <= 0 ? 'until later today' : (d == 1 ? 'until tomorrow' : 'for $d more days');
    }

    return Scaffold(
      backgroundColor: mc.canvas,
      body: Wall(child: Column(children: [
        SizedBox(height: mq.padding.top),
        SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 12, 0),
            child: Row(children: [
              IconTap(icon: McIcons.back, size: const Size(26, 26), label: 'Back', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 6),
              Expanded(child: Text(deck?.name ?? 'Card', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.d(24, color: mc.ink))),
              IconTap(icon: McIcons.list, size: const Size(22, 22), label: 'Edit card', onTap: () => showEditor(context, editCardId: c.id)),
            ]),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + mq.padding.bottom),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(18)),
                decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(18), boxShadow: mc.cardShadow),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text((c.label.isEmpty ? 'card' : c.label).toUpperCase(), style: T.caps(12, color: mc.mutedOnInk)),
                  const SizedBox(height: 6),
                  Text(c.front,
                      style: deck?.kind == 'code' && !c.isReverse
                          ? T.mono(termSize(c.front, true), color: mc.onInk)
                          : T.d(termSize(c.front, false), color: mc.onInk, height: 1.05)),
                  if (c.example.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(c.example, style: T.t(16, color: mc.mutedOnInk, height: 1.3)),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: Mc.peach, borderRadius: BorderRadius.circular(12)),
                    child: Text(c.back, textAlign: TextAlign.center, style: T.d(c.back.length > 22 ? 22 : 28, color: Mc.graphite)),
                  ),
                  if (c.hook.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      McIcon(McIcons.lightbulb, size: const Size(16, 16), color: mc.mutedOnInk),
                      const SizedBox(width: 6),
                      Expanded(child: Text(c.hook, style: T.t(14, w: FontWeight.w600, color: mc.mutedOnInk))),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: StatTile(value: r == null ? 'New' : '${(r * 100).round()}%', label: 'recall now', valueSize: 30)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: c.s == null ? '—' : _days(c.s!), label: 'stability', valueSize: 30)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: c.d == null ? '—' : c.d!.toStringAsFixed(1), label: 'difficulty /10', valueSize: 30)),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(14)),
                decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14), boxShadow: mc.e1),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    c.isNew
                        ? 'Not seen yet. It joins the stack when the pace allows.'
                        : slip == null
                            ? ''
                            : slip <= now
                                ? 'Slipping since ${when(slip)}: it comes up soon.'
                                : 'Stays above 90 % ${until(slip)}.',
                    style: T.t(16, w: FontWeight.w700, color: mc.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${c.reps} reviews · ${c.lapses} ${c.lapses == 1 ? 'miss' : 'misses'} · ${(c.successRate * 100).round()}% remembered'
                    '${c.leech ? ' · tricky card' : ''}${c.suspended ? ' · suspended' : ''}',
                    style: T.t(14, w: FontWeight.w500, color: mc.muted),
                  ),
                  if (c.s != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(height: 150, child: _Curve(store: store, card: c)),
                  ],
                ]),
              ),
              if (events.isNotEmpty) ...[
                const SizedBox(height: 18),
                const SectionLabel('Your answers'),
                const SizedBox(height: 8),
                for (final e in events)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(12)),
                    decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: _gradeColor(e.grade, mc), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Text(Assessment.gradeName(e.grade), style: T.t(15, w: FontWeight.w700, color: mc.ink)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${(e.thinkMs / 1000).toStringAsFixed(1)} s to recall',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: T.t(14, w: FontWeight.w500, color: mc.muted)),
                      ),
                      Text(_date(e.ts), style: T.t(13, w: FontWeight.w600, color: mc.muted)),
                    ]),
                  ),
              ],
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: SoftButton(c.suspended ? 'Unsuspend' : 'Suspend', height: 48, onTap: () {
                    store.toggleSuspend(c.id);
                    Toaster.i.show(c.suspended ? 'Suspended: it skips the stack' : 'Back in the stack');
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SoftButton('Reset', height: 48, onTap: () async {
                    final ok = await confirm(context,
                        title: 'Reset this card?', message: 'Its memory starts over as a new card.', yes: 'Reset', no: 'Keep');
                    if (ok) store.resetCard(c.id);
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SoftButton('Delete', height: 48, textColor: Mc.red, onTap: () async {
                    final ok = await confirm(context, title: 'Delete this card?', message: 'You can undo right after.');
                    if (!ok || !context.mounted) return;
                    final undo = store.deleteCard(c.id);
                    Navigator.pop(context);
                    Toaster.i.show('Card deleted', undo: undo);
                  }),
                ),
              ]),
            ],
          ),
        ),
      ])),
    );
  }

  static String _days(double s) => s < 1 ? '${(s * 24).round()} h' : s < 60 ? '${s.toStringAsFixed(s < 10 ? 1 : 0)} d' : '${(s / 30).toStringAsFixed(1)} mo';

  static String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static Color _gradeColor(int g, Mc mc) => switch (g) { 1 => Mc.delete, 2 => Mc.peach, 3 => mc.ink, _ => Mc.green };
}

/// The forgetting curve from the last review: predicted recall over time, the 90 % line and today.
class _Curve extends StatelessWidget {
  const _Curve({required this.store, required this.card});
  final AppStore store;
  final CardItem card;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return CustomPaint(painter: _CurvePainter(store, card, mc), size: Size.infinite);
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.store, this.card, this.mc);
  final AppStore store;
  final CardItem card;
  final Mc mc;

  @override
  void paint(Canvas canvas, Size size) {
    final now = store.now();
    final last = card.last!;
    final s = card.s!;
    final slipDays = store.engine.fsrs.daysUntil(s, 0.9) / store.data.engine.calibration.multiplier;
    final span = math.max(3.0, math.max(slipDays * 2.2, (now - last) / msPerDay * 1.3));
    const left = 34.0, bottom = 20.0;
    final w = size.width - left, h = size.height - bottom;
    double x(double days) => left + days / span * w;
    double y(double r) => (1 - (r - 0.5) / 0.5).clamp(0.0, 1.0) * h;
    final label = T.t(10.5, w: FontWeight.w600, color: mc.muted);

    void text(String t, Offset at) {
      final tp = TextPainter(text: TextSpan(text: t, style: label), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, at);
    }

    final grid = Paint()..color = mc.line..strokeWidth = 1;
    for (final r in [1.0, 0.9, 0.75, 0.5]) {
      canvas.drawLine(Offset(left, y(r)), Offset(size.width, y(r)), grid..color = r == 0.9 ? Mc.red.withValues(alpha: 0.5) : mc.line);
      text('${(r * 100).round()}%', Offset(0, y(r) - 6));
    }
    final path = Path();
    for (var i = 0; i <= 80; i++) {
      final d = span * i / 80;
      final r = store.engine.fsrs.retrievability(d * store.data.engine.calibration.multiplier, s);
      final p = Offset(x(d), y(r));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = mc.ink);
    final nowD = (now - last) / msPerDay;
    final nowR = store.engine.recall(card, now) ?? 1;
    canvas.drawLine(Offset(x(nowD), 0), Offset(x(nowD), h), Paint()..color = mc.muted..strokeWidth = 1);
    canvas.drawCircle(Offset(x(nowD), y(nowR)), 6, Paint()..color = Mc.red);
    text('now', Offset(x(nowD) - 10, h + 4));
    text('last review', Offset(left, h + 4));
  }

  @override
  bool shouldRepaint(_CurvePainter old) => true;
}
