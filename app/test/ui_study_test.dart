import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';

/// Drives the real screens on a phone-sized surface. Any layout or build error fails the test.
void main() {
  setUpAll(() => T.googleFonts = false);

  Future<AppStore> openStore(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('mc_ui_');
    return (await tester.runAsync(() => AppStore.open(path: dir.path)))!;
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester, [int ms = 900]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> finish(WidgetTester tester, AppStore store) async {
    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('onboarding → first stack → swipes, chip, undo', (tester) async {
    phone(tester);
    final store = await openStore(tester);
    await tester.pumpWidget(MemoryCardApp(store: store));
    await settle(tester);
    expect(find.text('Memory Card'), findsWidgets);

    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(find.text('What do you want to remember?'), findsOneWidget);
    await tester.tap(find.textContaining('Continue'));
    await settle(tester);
    expect(find.text('A small daily goal'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('A nudge each day?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await settle(tester);
    expect(find.text('Your card'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await settle(tester, 1500);
    expect(find.text('Your library is ready'), findsOneWidget);
    await tester.tap(find.text('Start my first stack'));
    await settle(tester, 2500);

    expect(store.data.onboarded, isTrue);
    expect(store.data.decks.length, greaterThanOrEqualTo(3));
    expect(find.text('Tap to reveal'), findsOneWidget);

    // Reveal, then swipe right.
    await tester.tap(find.text('Tap to reveal'));
    await settle(tester, 400);
    final card = find.textContaining('Which way do you swipe').first;
    await tester.drag(card, const Offset(260, 0));
    await settle(tester, 700);
    expect(store.data.today!.done, 1);
    expect(find.text('Undo'), findsOneWidget);

    // Swipe left without revealing: the card refuses and asks to check first.
    final next = find.textContaining('?').first;
    await tester.drag(next, const Offset(-260, 0));
    await settle(tester, 600);
    expect(store.data.today!.done, 1);
    expect(find.textContaining('check first'), findsOneWidget);

    // Reveal and swipe left this time.
    await tester.tap(find.text('Tap to reveal'));
    await settle(tester, 400);
    await tester.drag(find.textContaining('?').first, const Offset(-260, 0));
    await settle(tester, 700);
    expect(store.data.today!.done, 2);
    // A hesitant miss in a 10-card stack goes 9 cards back: the very end.
    expect(find.textContaining('Back '), findsOneWidget);

    // Undo puts the card back.
    await tester.tap(find.text('Undo'));
    await settle(tester, 500);
    expect(store.data.today!.done, 1);

    await finish(tester, store);
  });
}
