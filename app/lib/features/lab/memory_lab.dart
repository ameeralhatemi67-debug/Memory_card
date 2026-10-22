import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../engine/days.dart';
import '../../engine/calibration.dart';
import '../../engine/optimizer.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/routes.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../browse/card_detail.dart';
import '../study/celebrate.dart';

/// Memory Lab: what the engine has learned about your memory, and a forecast of what comes next.
class MemoryLab extends StatefulWidget {
  const MemoryLab({super.key});

  static Route<void> route() => McPageRoute(builder: (_) => const MemoryLab());

  @override
  State<MemoryLab> createState() => _MemoryLabState();
}

class _MemoryLabState extends State<MemoryLab> {
  List<ReviewLog>? _logs;
  bool _training = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await context.storeRead.logs();
    if (mounted) setState(() => _logs = logs);
  }

  Future<void> _train(AppStore store) async {
    final logs = _logs ?? await store.logs();
    final raw = [for (final l in logs) <Object>[l.cardId, l.ts, l.grade]];
    setState(() => _training = true);
    TrainResult? r;
    try {
      r = kIsWeb ? trainInBackground(raw) : await compute(trainInBackground, raw);
    } catch (_) {
      r = null;
    }
    if (!mounted) return;
    setState(() => _training = false);
    if (r == null) {
      Toaster.i.show('Not enough reviews a day apart yet');
      return;
    }
    store.data.engine.calibration.multiplier = 1.0;
    store.personalWeights(r.weights, before: r.lossBefore, after: r.lossAfter, trainedOn: r.reviews);
    store.replaceMemory(r.states);
    store.data.engine.calibration.refit(store.engine.fsrs);
    Fx.i.seal();
    final seals = store.takePendingSeals();
    if (seals.isNotEmpty) announceSeals(context, seals);
    Toaster.i.show('Model trained · prediction error ${(r.improvement * 100).toStringAsFixed(0)}% lower');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final logs = _logs;
    final lib = store.libraryStats();
    final now = store.now();
    final today = dayNumber(now);

    // Retention: long-gap reviews of the last 30 days.
    var lg = 0, lgOk = 0;
    final byHour = List.filled(6, 0), byHourOk = List.filled(6, 0);
    final grades = List.filled(5, 0);
    for (final l in logs ?? const <ReviewLog>[]) {
      final age = today - dayNumber(l.ts);
      if (age <= 30 && l.elapsedDays >= 1) {
        lg++;
        if (l.ok) lgOk++;
      }
      if (age <= 90) {
        final b = ((DateTime.fromMillisecondsSinceEpoch(l.ts).hour + 20) % 24) ~/ 4; // 4–8 first
        byHour[b]++;
        if (l.ok) byHourOk[b]++;
      }
      if (age <= 14) grades[l.grade]++;
    }

    // Forecast: cards that start slipping on each of the next 14 days.
    final forecast = List.filled(14, 0);
    for (final d in store.data.activeDecks) {
      for (final c in store.data.cardsOf(d)) {
        if (c.suspended) continue;
        final at = store.engine.slipsAt(c);
        if (at == null) continue;
        final day = math.max(0, dayNumber(at) - today);
        if (day < 14) forecast[day]++;
      }
    }

    final eng = store.data.engine;
    final scorable = logs == null ? 0 : FsrsOptimizer.scorable([for (final l in logs) TrainReview(l.cardId, l.ts, l.grade)]);
    final tricky = store.data.cards.values.where((c) => c.reps >= 3 && (c.leech || c.successRate < 0.6)).toList()
      ..sort((a, b) => a.successRate.compareTo(b.successRate));

    Widget card({required String title, String? note, required Widget child}) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(18), boxShadow: mc.e1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: T.d(24, color: mc.ink)),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(note, style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.35)),
            ],
            const SizedBox(height: 14),
            child,
          ]),
        );

    return Scaffold(
      backgroundColor: mc.canvas,
      body: Column(children: [
        SizedBox(height: mq.padding.top),
        SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 12, 0),
            child: Row(children: [
              IconTap(icon: McIcons.back, size: const Size(26, 26), label: 'Back', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 6),
              Expanded(child: Text('Memory Lab', style: T.d(30, color: mc.ink))),
            ]),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 30 + mq.padding.bottom),
            children: [
              Text('What the engine has learned about how you remember.',
                  style: T.t(16, w: FontWeight.w500, color: mc.muted, height: 1.35)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: StatTile(value: '${store.data.profile.totalReviews}', label: 'swipes', valueSize: 30)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: lg == 0 ? '—' : '${(lgOk * 100 / lg).round()}%', label: 'retention 30 d', valueSize: 30)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: lib.health == null ? '—' : '${(lib.health! * 100).round()}%', label: 'health', valueSize: 30)),
              ]),
              const SizedBox(height: 14),
              card(
                title: 'The next two weeks',
                note: 'Cards that drop below 90 % recall each day if you don\'t study. Today includes the ones slipping now.',
                child: SizedBox(height: 120, child: _Bars(values: forecast, today: today)),
              ),
              card(
                title: 'Is the model right about you?',
                note: eng.calibration.points.length < 30
                    ? 'After ${30 - eng.calibration.points.length} more reviews a day apart, predictions get tuned to you.'
                    : 'You forget ${eng.calibration.multiplier >= 1 ? '${eng.calibration.multiplier.toStringAsFixed(2)}× faster' : '${(1 / eng.calibration.multiplier).toStringAsFixed(2)}× slower'} '
                        'than the default model; every prediction is adjusted.',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (eng.calibration.points.length >= 10) ...[
                    SizedBox(height: 150, child: _Calibration(store: store)),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: mc.canvas, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(eng.weights == null ? 'Personal memory model' : 'Your personal model is on',
                          style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                      const SizedBox(height: 3),
                      Text(
                        eng.weights == null
                            ? (scorable >= FsrsOptimizer.minReviews
                                ? 'Train FSRS-6 on your own history: $scorable reviews a day apart are ready.'
                                : 'Train FSRS-6 on your own history ($scorable of ${FsrsOptimizer.minReviews} reviews a day apart so far).')
                            : 'Trained on ${eng.trainedOn} reviews, ${dayKey(dayNumber(eng.trainedAt))}. Prediction error '
                                '${eng.lossBefore != null && eng.lossAfter != null && eng.lossBefore! > 0 ? '${((eng.lossBefore! - eng.lossAfter!) / eng.lossBefore! * 100).round()}% lower' : 'updated'}.',
                        style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: InkButton(
                            _training ? 'Training…' : (eng.weights == null ? 'Train on my reviews' : 'Train again'),
                            height: 46,
                            size: 20,
                            enabled: !_training && scorable >= FsrsOptimizer.minReviews,
                            onTap: () => _train(store),
                          ),
                        ),
                        if (eng.weights != null) ...[
                          const SizedBox(width: 8),
                          SoftButton('Defaults', height: 46, onTap: () {
                            store.personalWeights(null);
                            Toaster.i.show('Back to the FSRS-6 defaults');
                          }),
                        ],
                      ]),
                    ]),
                  ),
                ]),
              ),
              card(
                title: 'How you answer',
                note: 'Your normal recall takes about ${(eng.baselines.expectedThinkMs(12, '') / 1000).toStringAsFixed(1)} s for a short prompt. '
                    'Faster and surer than that reads as Easy; much slower or hesitant, as Hard.',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _GradeMix(grades: grades),
                  const SizedBox(height: 10),
                  Text(
                    'Easy from ${(eng.tuner.easyAt * 100).round()} % confidence, Hard below ${(eng.tuner.hardBelow * 100).round()} %. '
                    '${eng.tuner.tallies[4]?.lastObserved == null ? 'These tune themselves as your Easy cards come back.' : 'Your Easy cards were later remembered ${(eng.tuner.tallies[4]!.lastObserved! * 100).round()} % of the time (expected ${(eng.tuner.tallies[4]!.lastExpected! * 100).round()} %).'}',
                    style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.35),
                  ),
                ]),
              ),
              card(
                title: 'When you remember best',
                note: 'Share of cards remembered by time of day, last 90 days.',
                child: SizedBox(height: 120, child: _HourBars(total: byHour, ok: byHourOk)),
              ),
              card(
                title: 'A year of study',
                child: _YearHeat(store: store),
              ),
              if (tricky.isNotEmpty)
                card(
                  title: 'Trickiest cards',
                  note: 'Rewrite them, add a memory hook, or split them into two cards.',
                  child: Column(children: [
                    for (final c in tricky.take(8))
                      Pressable(
                        onTap: () => Navigator.of(context).push(CardDetail.route(c.id)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(child: Text(c.front, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.d(19, color: mc.ink))),
                            Text('${(c.successRate * 100).round()}% · ${c.lapses} misses', style: T.t(13, w: FontWeight.w600, color: mc.muted)),
                          ]),
                        ),
                      ),
                  ]),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.values, required this.today});
  final List<int> values;
  final int today;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final maxV = math.max(1, values.reduce(math.max));
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < values.length; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (values[i] > 0) Text('${values[i]}', style: T.t(10, w: FontWeight.w700, color: mc.muted)),
              const SizedBox(height: 2),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: values[i] / maxV),
                duration: Duration(milliseconds: 500 + i * 30),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Container(
                  height: math.max(3, 74 * v),
                  decoration: BoxDecoration(color: i == 0 ? Mc.red : mc.ink, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 4),
              Text(letters[weekdayOf(today + i) - 1], style: T.t(11, w: FontWeight.w700, color: mc.muted)),
            ]),
          ),
        ),
    ]);
  }
}

class _HourBars extends StatelessWidget {
  const _HourBars({required this.total, required this.ok});
  final List<int> total;
  final List<int> ok;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    const labels = ['4–8', '8–12', '12–16', '16–20', '20–24', 'night'];
    final rates = [for (var i = 0; i < 6; i++) total[i] < 5 ? null : ok[i] / total[i]];
    final best = rates.whereType<double>().fold<double>(0, math.max);
    if (rates.every((r) => r == null)) {
      return Center(child: Text('Study at a few different times to see this.', style: T.t(14, w: FontWeight.w600, color: mc.muted)));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < 6; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(rates[i] == null ? '' : '${(rates[i]! * 100).round()}%', style: T.t(11, w: FontWeight.w700, color: mc.muted)),
              const SizedBox(height: 2),
              Container(
                height: rates[i] == null ? 3 : math.max(3, 70 * rates[i]!),
                decoration: BoxDecoration(
                  color: rates[i] != null && rates[i] == best ? Mc.green : mc.ink,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: T.t(10.5, w: FontWeight.w700, color: mc.muted)),
            ]),
          ),
        ),
    ]);
  }
}

class _GradeMix extends StatelessWidget {
  const _GradeMix({required this.grades});
  final List<int> grades;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final total = math.max(1, grades.skip(1).fold<int>(0, (a, b) => a + b));
    final parts = [(grades[1], Mc.delete, 'Again'), (grades[2], Mc.peach, 'Hard'), (grades[3], mc.ink, 'Good'), (grades[4], Mc.green, 'Easy')];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          height: 12,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (n, c, _) in parts)
              if (n > 0) Expanded(flex: (n * 1000 ~/ total).clamp(1, 1000), child: ColoredBox(color: c)),
            if (total == 1 && grades.every((g) => g == 0)) Expanded(child: ColoredBox(color: mc.line)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, children: [
        for (final (n, c, label) in parts)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('$label $n', style: T.t(13, w: FontWeight.w600, color: mc.muted)),
          ]),
      ]),
    ]);
  }
}

class _Calibration extends StatelessWidget {
  const _Calibration({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return CustomPaint(painter: _CalPainter(store.data.engine.calibration.bins(store.engine.fsrs), mc), size: Size.infinite);
  }
}

class _CalPainter extends CustomPainter {
  _CalPainter(this.bins, this.mc);
  final List<CalibBin> bins;
  final Mc mc;

  @override
  void paint(Canvas canvas, Size size) {
    const lo = 0.5;
    double x(double v) => (v - lo) / (1 - lo) * size.width;
    double y(double v) => size.height - (v - lo).clamp(0.0, 1 - lo) / (1 - lo) * size.height;
    final grid = Paint()..color = mc.line..strokeWidth = 1;
    canvas.drawLine(Offset(x(lo), y(lo)), Offset(x(1), y(1)), grid..strokeWidth = 2);
    for (final v in [0.6, 0.7, 0.8, 0.9]) {
      canvas.drawLine(Offset(0, y(v)), Offset(size.width, y(v)), grid..strokeWidth = 1);
    }
    for (final b in bins) {
      final c = Offset(x(b.predicted), y(b.observed));
      final r = 4.0 + math.min(10.0, math.sqrt(b.n.toDouble()));
      canvas.drawCircle(c, r, Paint()..color = mc.ink);
    }
    final style = T.t(10.5, w: FontWeight.w600, color: mc.muted);
    final up = TextPainter(text: TextSpan(text: 'remembered', style: style), textDirection: TextDirection.ltr)..layout();
    up.paint(canvas, const Offset(2, 2));
    final across = TextPainter(text: TextSpan(text: 'predicted', style: style), textDirection: TextDirection.ltr)..layout();
    across.paint(canvas, Offset(size.width - across.width - 2, size.height - across.height - 2));
  }

  @override
  bool shouldRepaint(_CalPainter old) => true;
}

class _YearHeat extends StatelessWidget {
  const _YearHeat({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final today = store.today.day;
    final start = today - 52 * 7 - (weekdayOf(today) - 1);
    final hist = store.data.profile.history;
    // A year is 53 columns; on a phone that only fits with readable cells as a strip you can scroll
    // back through. It opens on the latest weeks.
    const cell = 11.0, gap = 3.0, monthRow = 18.0;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    int monthOf(int day) => DateTime.fromMillisecondsSinceEpoch(day * msPerDay, isUtc: true).month;
    final shades = [
      mc.line,
      mc.dark ? const Color(0xFF8A8A8A) : const Color(0xFFBDBDBD),
      mc.dark ? const Color(0xFFBDBDBD) : const Color(0xFF8A8A8A),
      mc.dark ? const Color(0xFFDADADA) : const Color(0xFF5E5E5E),
      mc.ink,
    ];
    return SizedBox(
      height: monthRow + 7 * (cell + gap),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var w = 0; w < 53; w++)
            Padding(
              padding: const EdgeInsets.only(right: gap),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  height: monthRow,
                  width: cell,
                  child: w == 0 || monthOf(start + w * 7) != monthOf(start + (w - 1) * 7)
                      ? OverflowBox(
                          alignment: Alignment.topLeft,
                          maxWidth: 40,
                          child: Text(months[monthOf(start + w * 7) - 1], style: T.t(11, w: FontWeight.w600, color: mc.muted)),
                        )
                      : null,
                ),
                for (var d = 0; d < 7; d++)
                  () {
                    final day = start + w * 7 + d;
                    if (day > today) return const SizedBox(width: cell, height: cell + gap);
                    final n = hist[day]?.swipes ?? 0;
                    final lvl = n == 0 ? 0 : n < 10 ? 1 : n < 25 ? 2 : n < 45 ? 3 : 4;
                    return Container(
                      width: cell,
                      height: cell,
                      margin: const EdgeInsets.only(bottom: gap),
                      decoration: BoxDecoration(
                        color: shades[lvl],
                        borderRadius: BorderRadius.circular(2.5),
                        border: day == today ? Border.all(color: Mc.red, width: 1.5) : null,
                      ),
                    );
                  }(),
              ]),
            ),
          // Room for the last month's name.
          const SizedBox(width: 16),
        ]),
      ),
    );
  }
}

