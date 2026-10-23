import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/data/store_scope.dart';
import 'package:memory_card/features/decks/deck_row.dart';
import 'package:memory_card/ui/motion.dart';
import 'package:memory_card/ui/theme.dart';

/// The deck bar's swipe: it follows the finger, hands the finger's speed to one spring, lands on a detent
/// with at most a soft overshoot (never a wobble), closes without undershooting, and never rebuilds the bar
/// while it moves (that was the hitch at the start of every swipe).
void main() {
  late AppStore store;
  late Deck deck;

  setUpAll(() async {
    T.googleFonts = false;
    final dir = Directory.systemTemp.createTempSync('mc_swipe_');
    store = await AppStore.open(path: dir.path);
    final f = store.createFolder('Languages');
    deck = store.addCatalogDeck('es-basics', f.id);
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: Mc.theme(Mc.light),
        home: Scaffold(
          body: Center(
            child: DeckRow(
              deck: deck,
              stats: store.stats(deck),
              onOpen: () {},
              onDelete: () {},
              onArchive: () {},
              onMove: () {},
              onPin: () {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  Finder bar() => find.byKey(ValueKey('deck-bar-${deck.id}'));

  /// The bar's left edge, sampled every 8 ms (a 120 Hz screen) until it has rested for a while.
  Future<List<double>> trace(WidgetTester tester, {int frames = 160}) async {
    final xs = <double>[];
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      xs.add(tester.getTopLeft(bar()).dx);
    }
    return xs;
  }

  /// Drags the bar like a finger: [dx] pixels over [steps] events, 8 ms apart, then lets go.
  Future<void> swipe(WidgetTester tester, double dx, {int steps = 14, bool release = true}) async {
    final g = await tester.startGesture(tester.getCenter(bar()));
    for (var i = 0; i < steps; i++) {
      await g.moveBy(Offset(dx / steps, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    if (release) await g.up();
  }

  int reversals(List<double> xs) {
    var n = 0, last = 0.0;
    for (var i = 1; i < xs.length; i++) {
      final d = xs[i] - xs[i - 1];
      if (d.abs() < 0.02) continue;
      if (last != 0 && d.sign != last.sign) n++;
      last = d;
    }
    return n;
  }

  testWidgets('swiping never rebuilds the bar: its state and its text stay the same', (tester) async {
    phone(tester);
    await mount(tester);
    final pulse = tester.state(find.byType(Pulse));
    final title = tester.element(find.text(deck.name));
    await swipe(tester, -90, release: false);
    expect(tester.getTopLeft(bar()).dx, lessThan(0), reason: 'the bar followed the finger');
    expect(identical(tester.state(find.byType(Pulse)), pulse), isTrue, reason: 'the fan was not rebuilt when the swipe began');
    expect(identical(tester.element(find.text(deck.name)), title), isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a left swipe lands on the first detent with a soft overshoot at most, then rests', (tester) async {
    phone(tester);
    await mount(tester);
    final start = tester.getTopLeft(bar()).dx;
    await swipe(tester, -100);
    final xs = await trace(tester);
    final shift = [for (final x in xs) x - start];
    final rest = shift.last;
    // The detent is 65 px of opening; the bar settles a little short of it (it keeps a gap from the tile).
    expect(rest, inInclusiveRange(-62, -50));
    // Once the bar has arrived at its resting place it stays there: it may overshoot by a pixel or two,
    // but never swings away again. (The first samples are the bar easing back from where the finger
    // left it, which is not an overshoot.)
    final arrived = shift.indexWhere((v) => (v - rest).abs() < 1);
    final overshoot = shift.sublist(arrived).map((v) => (v - rest).abs()).reduce(math.max);
    expect(overshoot, lessThan(4), reason: 'at most one soft overshoot, not a wobble');
    expect(reversals(xs), lessThanOrEqualTo(2));
    // It has stopped: the last 30 samples are identical.
    expect(xs.sublist(xs.length - 30).toSet().length, 1);
    // Smooth: the speed never jumps from one frame to the next by more than a few pixels.
    var worst = 0.0;
    for (var i = 2; i < xs.length; i++) {
      worst = math.max(worst, ((xs[i] - xs[i - 1]) - (xs[i - 1] - xs[i - 2])).abs());
    }
    expect(worst, lessThan(6), reason: 'no abrupt start or stop');
  });

  testWidgets('closing glides back without undershooting the resting place', (tester) async {
    phone(tester);
    await mount(tester);
    final start = tester.getTopLeft(bar()).dx;
    await swipe(tester, -100);
    await trace(tester, frames: 120);
    // Tap the bar: it closes.
    await tester.tap(bar());
    final xs = await trace(tester);
    final shift = [for (final x in xs) x - start];
    expect(shift.last.abs(), lessThan(0.6));
    expect(shift.every((v) => v <= 0.5), isTrue, reason: 'it never swings past closed');
    expect(reversals(xs), 0, reason: 'one smooth glide');
  });

  testWidgets('a right swipe opens the other side and a long pull reaches the second detent', (tester) async {
    phone(tester);
    await mount(tester);
    final start = tester.getTopLeft(bar()).dx;
    await swipe(tester, 190, steps: 20);
    final xs = await trace(tester);
    final rest = xs.last - start;
    expect(rest, greaterThan(100), reason: 'past the first detent, at the second');
    expect(reversals(xs), lessThanOrEqualTo(2));
    await tester.tap(bar());
    await trace(tester, frames: 120);
    expect((tester.getTopLeft(bar()).dx - start).abs(), lessThan(0.6));
  });

  testWidgets('a drag the system cancels still settles', (tester) async {
    phone(tester);
    await mount(tester);
    final start = tester.getTopLeft(bar()).dx;
    final g = await tester.startGesture(tester.getCenter(bar()));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(-8, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await g.cancel();
    final xs = await trace(tester);
    // Not stuck half-dragged: it either opened to a detent or closed, and then held still.
    expect(xs.sublist(xs.length - 30).toSet().length, 1);
    expect((xs.last - start).abs() < 0.6 || (xs.last - start) < -40, isTrue);
  });
}
