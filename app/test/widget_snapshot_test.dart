import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/data/widget_snapshot.dart';
import 'package:memory_card/engine/assessor.dart';
import 'package:memory_card/engine/days.dart';

/// Home-screen widgets: the snapshot the app hands them, and the Quick card answers they hand back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  late Deck deck;

  // One store for the whole file (Hive keeps its boxes open between tests).
  setUpAll(() async {
    store = await AppStore.open(path: Directory.systemTemp.createTempSync('mc_widgets_').path);
    final f = store.createFolder('Languages');
    deck = store.addCatalogDeck('de-a1-basics', f.id);
    store.prepare(deck.id);
    // Study eight cards, then let two weeks pass so they slip.
    for (var i = 0; i < 8; i++) {
      store.swipe(
        deckId: deck.id,
        cardId: store.top(deck.id)!,
        recalled: i != 3,
        signals: const ReviewSignals(thinkMs: 2500, verifyMs: 900, velocity: 1200),
      );
    }
    store.shiftClock(14 * msPerDay);
  });

  int realNow() => store.now() - store.data.clockOffset;

  test('the snapshot holds the day and the cards closest to slipping, most urgent first', () {
    final s = buildWidgetSnapshot(store);
    expect(s['v'], 2);
    expect(s['day'], store.today.day);
    expect(s['goal'], store.settings.goal);
    expect(s['done'], 0, reason: 'the clock jump started a new day');
    expect(s['offset'], store.data.clockOffset);
    final q = (s['queue']! as List).cast<Map<String, Object?>>();
    expect(q, isNotEmpty);
    expect(q.length, lessThanOrEqualTo(12));
    final rs = [for (final c in q) c['r']! as double];
    expect(rs, orderedEquals([...rs]..sort()));
    expect(q.every((c) => (c['front']! as String).isNotEmpty && (c['back']! as String).isNotEmpty), isTrue);
    expect(q.every((c) => !store.data.cards[c['id']]!.isNew), isTrue, reason: 'new cards have nothing to recall yet');
    expect(q.first['deckName'], deck.name);
    expect(() => jsonEncode(s), returnsNormally);
  });

  test('the snapshot carries what the newer widgets draw: heat, forecast, health ahead, membership, seals, decks, look', () {
    final s = buildWidgetSnapshot(store);
    expect((s['heat']! as List).length, 126);
    expect((s['forecast']! as List).length, 14);
    expect((s['forecast']! as List).cast<int>().every((n) => n >= 0), isTrue);
    final hz = (s['hz']! as List).cast<double>();
    final sz = (s['sz']! as List).cast<int>();
    expect(hz.length, 25);
    expect(sz.length, 25);
    expect(hz.first, greaterThan(hz.last), reason: 'recall only falls while you are away');
    expect(sz.first, lessThanOrEqualTo(sz.last), reason: 'cards only slip further as time passes');
    final m = s['member']! as Map;
    expect(m['tier'], anyOf('Bronze', 'Silver', 'Gold', 'Platinum'));
    expect(m['name'], 'Guest Learner');
    final seals = s['seals']! as Map;
    expect(seals['total'], greaterThan(10));
    final decks = (s['decks']! as List).cast<Map<String, Object?>>();
    expect(decks, isNotEmpty);
    expect(decks.first['name'], deck.name);
    expect(decks.first['steps'], inInclusiveRange(0, 5));
    final look = s['look']! as Map;
    expect(look['theme'], 'auto');
    expect(look['accent'], 'red');
    expect(look['corners'], 'round');
    expect(look['opacity'], 100);
    expect(look['motion'], isTrue);
    expect(() => jsonEncode(s), returnsNormally);
  });

  test('the Look settings reach the widgets, and reduced motion switches their motion off', () {
    store.updateSettings((x) {
      x.widgetTheme = 'dark';
      x.widgetAccent = 'blue';
      x.widgetCorners = 'square';
      x.widgetOpacity = 70;
      x.widgetSurfaces['streak'] = 'paper';
      x.reducedMotion = true;
    });
    final look = buildWidgetSnapshot(store)['look']! as Map;
    expect(look['theme'], 'dark');
    expect(look['accent'], 'blue');
    expect(look['corners'], 'square');
    expect(look['opacity'], 70);
    expect(look['motion'], isFalse, reason: 'reduced motion wins');
    expect((look['surfaces']! as Map)['streak'], 'paper');
    // And they survive a save: settings round-trip through JSON.
    final back = Settings.fromJson(jsonDecode(jsonEncode(store.settings.toJson())) as Map);
    expect(back.widgetAccent, 'blue');
    expect(back.widgetOpacity, 70);
    expect(back.widgetSurfaces['streak'], 'paper');
    store.updateSettings((x) {
      x.widgetTheme = 'auto';
      x.widgetAccent = 'red';
      x.widgetCorners = 'round';
      x.widgetOpacity = 100;
      x.widgetSurfaces.clear();
      x.reducedMotion = false;
    });
  });

  test('the inbox keeps only answers newer than the watermark, oldest first', () {
    final raw = jsonEncode([
      {'card': 'b', 'deck': 'd', 'grade': 3, 'ts': 300},
      {'card': 'a', 'deck': 'd', 'grade': 1, 'ts': 200, 'verify': 1500},
      {'card': 'old', 'deck': 'd', 'grade': 3, 'ts': 100},
      {'nonsense': true},
    ]);
    final list = WidgetReview.parseInbox(raw, 150);
    expect([for (final r in list) r.cardId], ['a', 'b']);
    expect(list.first.grade, 1);
    expect(list.first.verifyMs, 1500);
    expect(WidgetReview.parseInbox('not json', 0), isEmpty);
    expect(WidgetReview.parseInbox(null, 0), isEmpty);
  });

  test('widget answers replay through the engine as mode "widget", Again or Good', () async {
    final q = widgetQueue(store, store.now());
    final good = store.data.cards[q[0]['id']]!, again = store.data.cards[q[1]['id']]!;
    final reps = good.reps, lapses = again.lapses, sBefore = good.s!;
    final done = store.today.done;
    final applied = store.applyWidgetReviews([
      WidgetReview(cardId: again.id, deckId: again.deckId, grade: 1, ts: realNow() - 1000),
      WidgetReview(cardId: good.id, deckId: good.deckId, grade: 3, ts: realNow() - 2000, verifyMs: 1200),
    ]);
    expect(applied, 2);
    expect(good.reps, reps + 1);
    expect(good.lastGrade, 3);
    expect(good.s!, greaterThan(sBefore));
    expect(again.lapses, lapses + 1);
    expect(again.lastGrade, 1);
    expect(store.today.done, done + 2);
    final logs = (await store.logs()).where((l) => l.mode == 'widget').toList();
    expect(logs.length, 2);
    expect(logs.every((l) => !l.automatic), isTrue, reason: 'the grade was picked, not read');
    // Answered cards leave the queue (their recall is fresh again).
    expect(widgetQueue(store, store.now()).first['id'], isNot(good.id));
  });

  test('an answer older than the card\'s last review is dropped; one from a day the app has left counts today', () {
    final latest = store.data.cards.values.where((c) => c.last != null).reduce((a, b) => a.last! > b.last! ? a : b);
    expect(
      store.applyWidgetReviews([
        WidgetReview(cardId: latest.id, deckId: latest.deckId, grade: 3, ts: latest.last! - store.data.clockOffset - 60000),
      ]),
      0,
    );

    final day = store.today.day;
    final stale = store.data.cardsOf(deck).firstWhere((c) => c.last != null && c.last! < store.today.startedAt - 3 * msPerDay);
    final applied = store.applyWidgetReviews([
      WidgetReview(cardId: stale.id, deckId: stale.deckId, grade: 3, ts: realNow() - 2 * msPerDay),
    ]);
    expect(applied, 1);
    expect(store.today.day, day, reason: 'the day never goes backwards');
    expect(stale.last, greaterThanOrEqualTo(store.today.startedAt));
  });

  test('answers for cards that no longer exist are skipped', () {
    expect(store.applyWidgetReviews([WidgetReview(cardId: 'gone', deckId: deck.id, grade: 3, ts: realNow())]), 0);
  });
}
