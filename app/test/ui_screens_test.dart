import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/engine/days.dart';
import 'package:memory_card/features/browse/card_detail.dart';
import 'package:memory_card/features/browse/deck_browser.dart';
import 'package:memory_card/features/help/help_screen.dart';
import 'package:memory_card/features/lab/memory_lab.dart';
import 'package:memory_card/features/profile/profile_screen.dart';
import 'package:memory_card/features/search/search_screen.dart';
import 'package:memory_card/features/settings/settings_screen.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/features/today/today_screen.dart';
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

  testWidgets(
    'every screen builds: decks, drawer, shop, preview, profile, settings, lab, today, detail',
    (tester) async {
      phone(tester);
      final store = await openStore(tester);
      final f = store.createFolder('Languages');
      store.addCatalogDeck('es-basics', f.id);
      store.addCatalogDeck(
        'python-syntax',
        store.createFolder('Coding', atTop: false).id,
      );
      store.touchFolder(f.id);
      store.setOnboarded();
      await tester.pumpWidget(MemoryCardApp(store: store));
      await settle(tester, 1500);

      expect(find.text('Spanish · Basics'), findsWidgets);

      // The first-visit coach mark: shown once, a tap outside the spotlight only dismisses it.
      await settle(tester, 600);
      expect(find.text('Your folders live here'), findsOneWidget);
      await tester.tapAt(const Offset(200, 600));
      await settle(tester, 400);
      expect(find.text('Your folders live here'), findsNothing);
      expect(store.coachSeen('drawer'), isTrue);
      store.markCoach('shop-hold');

      // Drawer.
      Shell.current!.openDrawer();
      await settle(tester, 1200);
      expect(find.text('Coding'), findsWidgets);
      await tester.tap(find.text('Coding').first);
      await settle(tester);
      Shell.current!.closeDrawer();
      await settle(tester);

      // Shop and a preview.
      Shell.current!.openShop();
      await settle(tester, 1200);
      expect(find.text('Shop'), findsOneWidget);
      // With decks in the library, the hero is the deck of the day.
      final hero = store.catalog.deckOfTheDay(dayNumber(store.data.now()), store.data.shopAdded.containsKey)!;
      expect(find.text('DECK OF THE DAY'), findsOneWidget);
      await tester.tap(find.text('Preview').first);
      await settle(tester, 1200);
      expect(find.textContaining('cards to'), findsWidgets);
      await tester.tap(find.textContaining('cards to').last);
      await settle(tester, 1200);
      expect(store.data.shopAdded.containsKey(hero.id), isTrue);

      // Full screens.
      final nav = Navigator.of(
        tester.element(find.byType(Shell)),
        rootNavigator: true,
      );
      for (final route in [
        ProfileScreen.route(),
        SettingsScreen.route(),
        MemoryLab.route(),
        TodayScreen.route(),
        HelpScreen.route(),
        SearchScreen.route(),
        DeckBrowser.route(store.data.shopAdded['es-basics']!),
        CardDetail.route(store.data.cards.keys.first),
      ]) {
        nav.push(route);
        await settle(tester, 1200);
        nav.pop();
        await settle(tester, 600);
      }

      // The editor sheet.
      Shell.current!.create();
      await settle(tester, 1200);
      expect(find.text('New card'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'el gato');
      await tester.enterText(find.byType(TextField).at(1), 'the cat');
      await tester.tap(find.text('Save & next'));
      await settle(tester, 600);
      expect(store.data.cards.values.any((c) => c.front == 'el gato'), isTrue);

      await finish(tester, store);
    },
  );
}
