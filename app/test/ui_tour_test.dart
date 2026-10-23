import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';

/// The first-run tour is learned by swiping: this drives every tour card with real drags.
void main() {
  setUpAll(() => T.googleFonts = false);

  Future<void> settle(WidgetTester tester, [int ms = 900]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('tour: swipe right, recall, miss, re-insertion, then setup', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('mc_tour_');
    final store = (await tester.runAsync(() => AppStore.open(path: dir.path)))!;
    await tester.pumpWidget(MemoryCardApp(store: store));
    await settle(tester, 3000);

    // Welcome: swipe right.
    expect(find.text('Swipe the card right to begin'), findsOneWidget);
    await tester.drag(find.text('Remember anything,\none swipe at a time.'), const Offset(300, 0));
    await settle(tester);

    // A real recall card: swiping before checking is refused.
    expect(find.text('The capital of Australia?'), findsOneWidget);
    await tester.drag(find.text('The capital of Australia?'), const Offset(300, 0));
    await settle(tester, 500);
    expect(find.textContaining('Tap the card first'), findsOneWidget);
    await tester.tap(find.text('Tap to reveal'));
    await settle(tester, 400);
    expect(find.text('Canberra'), findsOneWidget);
    await tester.drag(find.text('The capital of Australia?'), const Offset(300, 0));
    await settle(tester);

    // The new German word: the wrong direction gets a hint, a left swipe shows where the card went.
    expect(find.text('der Schmetterling'), findsOneWidget);
    await tester.tap(find.text('Tap to reveal'));
    await settle(tester, 400);
    await tester.drag(find.text('der Schmetterling'), const Offset(300, 0));
    await settle(tester, 500);
    expect(find.textContaining('swipe left'), findsOneWidget);
    await tester.drag(find.text('der Schmetterling'), const Offset(-300, 0));
    await settle(tester, 700);
    expect(find.text('It comes back\nin 8 cards'), findsOneWidget);
    expect(find.text('Swipe right to continue'), findsOneWidget);
    await settle(tester, 2200);
    await tester.drag(find.text('It comes back\nin 8 cards'), const Offset(300, 0));
    await settle(tester);

    expect(find.text('We read how\nyou answer'), findsOneWidget);
    await tester.drag(find.text('We read how\nyou answer'), const Offset(300, 0));
    await settle(tester);
    expect(find.text('Cards come back just in time'), findsOneWidget);
    await tester.tap(find.text('or tap here'));
    await settle(tester);

    // Setup: the decks chosen by default are on screen, featured first. (A tall screen: the test font is so
    // wide that the topic chips fill several rows and would push the decks out of view.)
    tester.view.physicalSize = const Size(360 * 3, 1700 * 3);
    await settle(tester, 400);
    expect(find.text('What do you want to remember?'), findsOneWidget);
    expect(find.text('Spanish · Basics'), findsOneWidget);
    expect(find.text('Italian · Basics'), findsOneWidget);
    expect(find.textContaining('2 decks'), findsOneWidget);
    // Hiding the topic drops its decks.
    await tester.tap(find.text('Languages').first);
    await settle(tester, 400);
    expect(find.text('Spanish · Basics'), findsNothing);
    expect(find.text('Start with the tutorial'), findsOneWidget);

    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
