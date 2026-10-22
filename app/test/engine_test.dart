import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/data/app_data.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/engine/assessor.dart';
import 'package:memory_card/engine/baselines.dart';
import 'package:memory_card/engine/days.dart';
import 'package:memory_card/engine/stack_rules.dart';
import 'package:memory_card/engine/study_engine.dart';

const _noon = 1792670400000; // a fixed local-ish timestamp in 2026

AppData world({int cards = 40, Pace pace = Pace.intense, int goal = 20}) {
  final data = AppData(createdAt: _noon);
  data.settings.pace = pace;
  data.settings.goal = goal;
  final deck = Deck(id: 'd1', name: 'Test · Deck', created: _noon);
  for (var i = 0; i < cards; i++) {
    final c = CardItem(
      id: 'c$i',
      deckId: 'd1',
      front: 'front $i',
      back: 'back $i',
      created: _noon,
    );
    data.cards[c.id] = c;
    deck.cardIds.add(c.id);
  }
  deck.stack = [...deck.cardIds];
  data.decks[deck.id] = deck;
  data.folders.add(
    Folder(id: 'f1', name: 'Folder', deckIds: ['d1'], created: _noon),
  );
  return data;
}

ReviewSignals fast() => const ReviewSignals(
  thinkMs: 900,
  verifyMs: 400,
  dragMs: 180,
  velocity: 1600,
);
ReviewSignals slow() => const ReviewSignals(
  thinkMs: 14000,
  verifyMs: 5000,
  dragMs: 900,
  reversals: 2,
  crossings: 3,
  hesitation: 0.3,
);
ReviewSignals normal() => const ReviewSignals(
  thinkMs: 2700,
  verifyMs: 1100,
  dragMs: 300,
  velocity: 900,
);

void main() {
  group('stack rules', () {
    test(
      'a missed card returns 8–20 cards later, never inside working memory',
      () {
        for (final rate in [0.0, 0.3, 0.6, 1.0]) {
          final n = StackRules.failGap(
            successRate: rate,
            stabilityBefore: null,
            lapses: 0,
            kind: RecallKind.missed,
            restLength: 100,
          );
          expect(n, inInclusiveRange(8, 20));
        }
        expect(
          StackRules.failGap(
            successRate: 1,
            stabilityBefore: null,
            lapses: 0,
            kind: RecallKind.missed,
            restLength: 7,
          ),
          7,
        );
        expect(
          StackRules.failGap(
            successRate: 0.5,
            stabilityBefore: null,
            lapses: 0,
            kind: RecallKind.missed,
            restLength: 4,
          ),
          4,
        );
      },
    );

    test(
      'near misses wait longer than blanks; strong cards that slipped wait longer',
      () {
        int gap(RecallKind k, {double? s}) => StackRules.failGap(
          successRate: 0.5,
          stabilityBefore: s,
          lapses: 0,
          kind: k,
          restLength: 100,
        );
        expect(gap(RecallKind.nearMiss), greaterThan(gap(RecallKind.blank)));
        expect(
          gap(RecallKind.missed, s: 30),
          greaterThan(gap(RecallKind.missed)),
        );
      },
    );

    test('reverse siblings stay at least 10 apart', () {
      final rest = List.generate(40, (i) => 'x$i')..[9] = 'sib';
      final pos = StackRules.awayFromSibling(rest, 8, 'sib');
      expect((pos - 9).abs(), greaterThanOrEqualTo(10));
    });

    test('warm-up puts the weakest cards first', () {
      final stack = ['a', 'b', 'c', 'd'];
      final r = {'a': 0.95, 'b': 0.4, 'c': null, 'd': 0.7};
      final (out, moved) = StackRules.warmUp(stack, (id) => r[id], count: 2);
      expect(out.take(2), ['b', 'd']);
      expect(moved, 2);
      expect(out.toSet(), stack.toSet());
    });
  });

  group('assessor', () {
    final tuner = GradeTuner();
    test(
      'fast, decisive recall is Easy; slow and hesitant is Hard; ordinary is Good',
      () {
        final b = PersonalBaselines();
        const a = Assessor();
        Assessment run(ReviewSignals s) => a.assess(
          recalled: true,
          s: s,
          baselines: b,
          tuner: tuner,
          deckId: 'd1',
          firstExposure: false,
        );
        expect(run(fast()).grade, 4);
        expect(run(slow()).grade, 2);
        expect(run(normal()).grade, 3);
      },
    );

    test('an interruption is never read as hesitation', () {
      final b = PersonalBaselines();
      const a = Assessor();
      final r = a.assess(
        recalled: true,
        s: const ReviewSignals(thinkMs: 240000, verifyMs: 900, velocity: 1500),
        baselines: b,
        tuner: tuner,
        deckId: 'd1',
        firstExposure: false,
      );
      expect(r.latencyTrusted, isFalse);
      expect(r.grade, 3);
    });

    test(
      'the baseline adapts: a slow person is not punished for being slow',
      () {
        final b = PersonalBaselines();
        for (var i = 0; i < 60; i++) {
          b.observeCorrect(
            thinkMs: 9000,
            chars: 10,
            deckId: 'd1',
            verifyMs: 3000,
          );
        }
        const a = Assessor();
        final r = a.assess(
          recalled: true,
          s: const ReviewSignals(thinkMs: 9000, verifyMs: 3000, velocity: 900),
          baselines: b,
          tuner: tuner,
          deckId: 'd1',
          firstExposure: false,
        );
        expect(r.grade, 3);
      },
    );

    test('a missed card is Again, labelled blank or near miss', () {
      final b = PersonalBaselines();
      const a = Assessor();
      final blank = a.assess(
        recalled: false,
        s: fast(),
        baselines: b,
        tuner: tuner,
        deckId: 'd1',
        firstExposure: false,
      );
      final near = a.assess(
        recalled: false,
        s: slow(),
        baselines: b,
        tuner: tuner,
        deckId: 'd1',
        firstExposure: false,
      );
      expect(blank.grade, 1);
      expect(blank.kind, RecallKind.blank);
      expect(near.kind, RecallKind.nearMiss);
    });

    test('smart grading off gives the binary Again / Good of RES-47', () {
      final b = PersonalBaselines();
      const a = Assessor();
      final r = a.assess(
        recalled: true,
        s: fast(),
        baselines: b,
        tuner: tuner,
        deckId: 'd1',
        firstExposure: false,
        smartGrading: false,
      );
      expect(r.grade, 3);
    });

    test(
      'the Easy bar rises when Easy cards later fail more than predicted',
      () {
        final t = GradeTuner();
        final before = t.easyAt;
        for (var i = 0; i < GradeTuner.window; i++) {
          t.observe(4, i % 2 == 0, 0.92);
        }
        expect(t.easyAt, greaterThan(before));
      },
    );
  });

  group('study engine', () {
    test(
      'right goes to the back, left comes back 8–20 later, FSRS state is written',
      () {
        final data = world();
        final e = StudyEngine(data);
        final d = data.decks['d1']!;
        final top = e.topCard(d, _noon)!;
        e.swipe(d, top, recalled: true, signals: normal(), now: _noon);
        expect(d.stack.last, top);
        expect(data.cards[top]!.s, isNotNull);

        final next = e.topCard(d, _noon)!;
        final out = e.swipe(
          d,
          next,
          recalled: false,
          signals: normal(),
          now: _noon + 5000,
        );
        expect(d.stack.indexOf(next), inInclusiveRange(8, 20));
        expect(out.assessment.grade, 1);
        expect(data.today!.done, 2);
      },
    );

    test('the goal is reached at the swipe target and starts a streak', () {
      final data = world(goal: 10);
      final e = StudyEngine(data);
      final d = data.decks['d1']!;
      SwipeOutcome? last;
      for (var i = 0; i < 10; i++) {
        last = e.swipe(
          d,
          e.topCard(d, _noon + i * 4000)!,
          recalled: true,
          signals: normal(),
          now: _noon + i * 4000,
        );
      }
      expect(last!.goalNow, isTrue);
      expect(data.profile.streak, 1);
      expect(data.today!.goalHit, isTrue);
    });

    test(
      'a missed day uses a grace shield; a second gap without shields breaks the streak',
      () {
        final data = world(goal: 5);
        final e = StudyEngine(data);
        final d = data.decks['d1']!;
        void studyDay(int day) {
          final t = _noon + day * msPerDay;
          for (var i = 0; i < 5; i++) {
            e.swipe(
              d,
              e.topCard(d, t + i * 3000)!,
              recalled: true,
              signals: normal(),
              now: t + i * 3000,
            );
          }
        }

        studyDay(0);
        studyDay(1);
        expect(data.profile.streak, 2);
        studyDay(3); // day 2 missed: shield
        expect(data.profile.streak, 3);
        expect(data.profile.shields, 1);
        e.ensureToday(
          _noon + 8 * msPerDay,
        ); // four days missed, one shield left
        expect(data.profile.streak, 0);
      },
    );

    test(
      'balanced pace holds cards in the reservoir until success is high enough',
      () {
        final data = world(cards: 30, pace: Pace.balanced);
        final d = data.decks['d1']!;
        d.reservoir = d.stack.sublist(15);
        d.stack = d.stack.sublist(0, 15);
        d.ema = 0.5;
        final e = StudyEngine(data);
        final out = e.swipe(
          d,
          e.topCard(d, _noon)!,
          recalled: true,
          signals: normal(),
          now: _noon,
        );
        expect(out.introduced, isEmpty);
        d.ema = 0.9;
        final out2 = e.swipe(
          d,
          e.topCard(d, _noon + 4000)!,
          recalled: true,
          signals: normal(),
          now: _noon + 4000,
        );
        expect(out2.introduced, hasLength(1));
        expect(d.stack.indexOf(out2.introduced.first), 3);
      },
    );

    test('a tough patch pauses new cards', () {
      final data = world(cards: 30, pace: Pace.balanced);
      final d = data.decks['d1']!;
      d.reservoir = d.stack.sublist(15);
      d.stack = d.stack.sublist(0, 15);
      d.ema = 0.95;
      final e = StudyEngine(data);
      final mood = SessionMood.of(List.filled(10, false));
      final out = e.swipe(
        d,
        e.topCard(d, _noon)!,
        recalled: true,
        signals: normal(),
        now: _noon,
        mood: mood,
      );
      expect(out.pausedNew, isTrue);
      expect(out.introduced, isEmpty);
    });

    test('eight lapses flag a leech and send it to the end', () {
      final data = world();
      final e = StudyEngine(data);
      final d = data.decks['d1']!;
      final c = data.cards['c0']!..lapses = 7;
      d.stack = ['c0', ...d.stack.where((x) => x != 'c0')];
      final out = e.swipe(
        d,
        'c0',
        recalled: false,
        signals: normal(),
        now: _noon,
      );
      expect(out.leechNow, isTrue);
      expect(c.leech, isTrue);
      expect(d.stack.last, 'c0');
    });

    test('mastered cards rest instead of taking a turn', () {
      final data = world(cards: 5);
      final e = StudyEngine(data);
      final d = data.decks['d1']!;
      data.cards['c0']!
        ..s = 120
        ..d = 3
        ..last = _noon - msPerDay;
      expect(e.topCard(d, _noon), 'c1');
      expect(d.stack.last, 'c0');
    });

    test('after two days away the weakest cards come first', () {
      final data = world(cards: 10);
      final e = StudyEngine(data);
      final d = data.decks['d1']!;
      for (var i = 0; i < 10; i++) {
        data.cards['c$i']!
          ..s = 1.0 + i
          ..d = 5
          ..last = _noon - 3 * msPerDay;
      }
      d.lastStudied = _noon - 3 * msPerDay;
      final warm = e.prepareDeck(d, _noon);
      expect(warm, 10);
      expect(d.stack.first, 'c0');
    });

    test('a review log entry carries the signals and FSRS before/after', () {
      final data = world();
      final e = StudyEngine(data);
      final d = data.decks['d1']!;
      final out = e.swipe(
        d,
        e.topCard(d, _noon)!,
        recalled: true,
        signals: fast(),
        now: _noon,
      );
      expect(out.log.sBefore, isNull);
      expect(out.log.sAfter, greaterThan(0));
      expect(out.log.signals['think'], 900);
      expect(out.log.elapsedDays, -1);
    });
  });

  group('days', () {
    test('a new study day starts at 04:00', () {
      final evening = DateTime(2026, 10, 22, 23, 30).millisecondsSinceEpoch;
      final lateNight = DateTime(2026, 10, 23, 3, 30).millisecondsSinceEpoch;
      final morning = DateTime(2026, 10, 23, 4, 30).millisecondsSinceEpoch;
      expect(dayNumber(evening), dayNumber(lateNight));
      expect(dayNumber(morning), dayNumber(evening) + 1);
      expect(dayKey(dayNumber(morning)), '2026-10-23');
      expect(dayFromKey('2026-10-23'), dayNumber(morning));
    });
  });
}
