import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/store_scope.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/routes.dart';
import '../../ui/shapes.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../shell/shell.dart';
import '../study/celebrate.dart';

/// Today (canvas Goal.dc.html): the seal, the day's numbers, the streak and memory health.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static Route<void> route() => McPageRoute(builder: (_) => const TodayScreen());

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final t = store.today;
    final goal = store.settings.goal;
    final reached = t.goalHit;
    final left = math.max(0, goal - t.done);
    final lib = store.libraryStats();
    final health = lib.health == null ? 0.0 : lib.health! * 100;
    final streak = store.engine.liveStreak();
    final p = store.data.profile;
    final used = 2 - p.shields;
    final lastDeck = t.lastDeck == null ? null : store.data.decks[t.lastDeck];
    final mins = math.max(t.done > 0 ? 1 : 0, (t.ms / 60000).round());
    final events = p.lastEvents;
    final again = t.fail, hard = t.hard, easy = t.easy;
    final good = math.max(0, t.ok - hard - easy);

    return Scaffold(
      backgroundColor: mc.canvas,
      body: Column(children: [
        SizedBox(height: mq.padding.top),
        SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 16, 0),
            child: Row(children: [
              IconTap(icon: McIcons.logo, label: 'Back', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(child: Text('Today', style: T.d(24, color: mc.ink))),
            ]),
          ),
        ),
        Expanded(
          child: Stack(children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Center(
                child: reached
                    ? const StampedSeal(size: 168, label: 'DONE')
                    : _ProgressSeal(done: t.done, goal: goal),
              ),
              const SizedBox(height: 14),
              Text(reached ? 'Goal reached' : '$left to go', textAlign: TextAlign.center, style: T.d(42, color: mc.ink)),
              const SizedBox(height: 8),
              Text(
                [
                  if (lastDeck != null) lastDeck.name,
                  '$mins min',
                  if (!reached && t.slipStart.isNotEmpty) 'or see every slipping card once (${store.engine.slipLeft()} left)',
                ].join(' · '),
                textAlign: TextAlign.center,
                style: T.t(17, w: FontWeight.w500, color: mc.muted),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: StatTile(value: '${t.done}', label: 'reviewed')),
                const SizedBox(width: 10),
                Expanded(child: StatTile(value: '${t.ok}', label: 'remembered')),
                const SizedBox(width: 10),
                Expanded(child: StatTile(value: '${t.fail}', label: 'relearned')),
              ]),
              if (t.done > 0) ...[
                const SizedBox(height: 12),
                _GradeBar(again: again, hard: hard, good: good, easy: easy),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(14), boxShadow: mc.e2),
                child: Row(children: [
                  const SizedBox(width: 26, height: 30, child: FlickerFlame()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$streak-day streak', style: T.d(26, color: mc.onInk)),
                      const SizedBox(height: 3),
                      Text(
                        '${p.shields} grace ${p.shields == 1 ? 'shield' : 'shields'} left this month'
                        '${events.contains('shield') ? ' · one covered a missed day' : events.contains('broken') ? ' · streak reset after a missed day' : ''}',
                        style: T.t(14, w: FontWeight.w500, color: mc.mutedOnInk),
                      ),
                    ]),
                  ),
                  for (var i = 0; i < 2; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: SizedBox(width: 22, height: 26, child: CustomPaint(painter: ShieldPainter(used: i < used))),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              _Health(health: health, tomorrow: lib.tomorrow, slipping: lib.slipping),
              if (t.bestRun >= 5) ...[
                const SizedBox(height: 12),
                Text('Best run today: ${t.bestRun} in a row',
                    textAlign: TextAlign.center, style: T.t(15, w: FontWeight.w600, color: mc.muted)),
              ],
            ],
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: BottomFade(height: 28)),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + mq.padding.bottom),
          child: Column(children: [
            InkButton('Keep going', size: 26, onTap: () {
              Navigator.pop(context);
              final shell = Shell.maybeOf(context);
              final last = store.data.today?.lastDeck ?? store.data.lastDeckId;
              if (shell != null && last != null && store.data.decks.containsKey(last)) shell.study(last);
            }),
            const SizedBox(height: 10),
            SoftButton('Back to decks', onTap: () {
              Navigator.pop(context);
              Shell.maybeOf(context)?.goHome();
            }),
          ]),
        ),
      ]),
    );
  }
}

/// A grey seal that fills with the day's progress until the goal is met.
class _ProgressSeal extends StatelessWidget {
  const _ProgressSeal({required this.done, required this.goal});
  final int done;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final f = goal == 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: f),
      duration: const Duration(milliseconds: 900),
      curve: McCurves.out,
      builder: (context, v, _) => SizedBox(
        width: 168,
        height: 168,
        child: Stack(alignment: Alignment.center, children: [
          WaxSeal(size: 168, color: mc.soft),
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: Mc.red,
              backgroundColor: mc.line,
            ),
          ),
          Text('$done/$goal', style: T.d(30, color: mc.ink)),
        ]),
      ),
    );
  }
}

/// How the day's answers were graded.
class _GradeBar extends StatelessWidget {
  const _GradeBar({required this.again, required this.hard, required this.good, required this.easy});
  final int again, hard, good, easy;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final total = math.max(1, again + hard + good + easy);
    final parts = [
      (again, Mc.delete, 'again'),
      (hard, Mc.peach, 'hard'),
      (good, mc.ink, 'good'),
      (easy, Mc.green, 'easy'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14), boxShadow: mc.e1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How you answered', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (n, c, _) in parts)
                if (n > 0) Expanded(flex: (n * 1000 ~/ total).clamp(1, 1000), child: ColoredBox(color: c)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          for (final (n, c, label) in parts)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('$n $label', style: T.t(14, w: FontWeight.w600, color: mc.muted)),
            ]),
        ]),
      ]),
    );
  }
}

class _Health extends StatelessWidget {
  const _Health({required this.health, required this.tomorrow, required this.slipping});
  final double health;
  final int tomorrow;
  final int slipping;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14), boxShadow: mc.e1),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: health),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Expanded(child: Text('Memory health', style: T.t(16, w: FontWeight.w700, color: mc.ink))),
            Text('${v.round()}%', style: T.d(26, color: mc.ink)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(children: [
                Positioned.fill(child: ColoredBox(color: mc.track)),
                FractionallySizedBox(widthFactor: (v / 100).clamp(0.0, 1.0), heightFactor: 1, child: ColoredBox(color: mc.ink)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Predicted recall right now. ${slipping > 0 ? '$slipping slipping · ' : ''}$tomorrow ${tomorrow == 1 ? 'card starts' : 'cards start'} slipping tomorrow.',
            style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.3),
          ),
        ]),
      ),
    );
  }
}

/// The streak flame flickers like a candle: stretches, squeezes and leans around its base.
class FlickerFlame extends StatelessWidget {
  const FlickerFlame({super.key});

  @override
  Widget build(BuildContext context) {
    return AmbientClock(builder: (context, ms) {
      final f1 = math.sin(ms / 900 * math.pi * 2), f2 = math.sin(ms / 370 * math.pi * 2);
      return Transform(
        alignment: const Alignment(0, 0.8),
        transform: Matrix4.identity()
          ..rotateZ(2 * math.sin(ms / 1300 * math.pi * 2) * math.pi / 180)
          ..scaleByDouble(1 - 0.03 * math.sin(ms / 900 * math.pi * 2 + 1), 1 + 0.06 * f1 + 0.03 * f2, 1, 1),
        child: const CustomPaint(painter: FlamePainter()),
      );
    });
  }
}
