// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/engine/assessor.dart';
import 'package:memory_card/engine/days.dart';

/// Two simulated weeks of study through the real store, timed, to catch slow paths or hangs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('two weeks of study', () async {
    final dir = Directory.systemTemp.createTempSync('mc_sim_');
    final store = await AppStore.open(path: dir.path);
    final f = store.createFolder('Languages');
    store.addCatalogDeck('es-basics', f.id);
    store.addCatalogDeck('it-basics', f.id);
    store.addCatalogDeck('python-syntax', store.createFolder('Coding', atTop: false).id);
    final rnd = math.Random(4);
    final sw = Stopwatch()..start();
    var swipes = 0;
    for (var day = 0; day < 14; day++) {
      for (final d in store.data.activeDecks.toList()) {
        store.prepare(d.id, notify: false);
        final n = 10 + rnd.nextInt(20);
        for (var i = 0; i < n; i++) {
          final t0 = sw.elapsedMilliseconds;
          final id = store.top(d.id);
          final t1 = sw.elapsedMilliseconds;
          if (t1 - t0 > 200) print('slow top(): ${t1 - t0} ms on day $day');
          if (id == null) break;
          final c = store.data.cards[id]!;
          final p = c.reps == 0 ? 0.5 : (store.engine.recall(c, store.now()) ?? 0.8).clamp(0.25, 0.97);
          final ok = rnd.nextDouble() < p;
          store.swipe(
            deckId: d.id,
            cardId: id,
            recalled: ok,
            signals: ReviewSignals(thinkMs: (ok ? 1500 : 3800) + rnd.nextInt(4000), verifyMs: 900, dragMs: 200, velocity: 1.2),
          );
          final t2 = sw.elapsedMilliseconds;
          if (t2 - t1 > 200) print('slow swipe(): ${t2 - t1} ms on day $day');
          swipes++;
        }
      }
      store.shiftClock(msPerDay);
      print('day $day done: $swipes swipes, ${sw.elapsedMilliseconds} ms');
    }
    await store.flush();
    print('flushed at ${sw.elapsedMilliseconds} ms');
    expect(swipes, greaterThan(100));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
