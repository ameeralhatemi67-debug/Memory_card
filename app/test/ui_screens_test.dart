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
import 'package:memory_card/ui/widgets.dart';

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
      // The whole hero opens the preview (its small "Preview" button can sit past the card's edge in the
      // test font, whose letters are far wider than the real ones).
      await tester.tap(find.text('DECK OF THE DAY'));
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

      // Settings › Texture: the tab opens, a swatch and the master switch change the stored settings.
      nav.push(SettingsScreen.route());
      await settle(tester, 1200);
      await tester.tap(find.text('Texture'));
      await settle(tester, 900);
      expect(find.text('Wall · light mode'), findsOneWidget);
      await tester.tap(find.text('Limewash').first);
      await settle(tester, 400);
      expect(store.settings.texture.layer('wallLight').style, 'limewash');
      await tester.tap(find.byType(McSwitch).first);
      await settle(tester, 400);
      expect(store.settings.texture.enabled, isFalse);
      nav.pop();
      await settle(tester, 700);

      // The nav bar's tabs: Memory Lab and Account open inside the shell, Home goes back.
      Shell.current!.openLab();
      await settle(tester, 1200);
      expect(Shell.current!.tab, ShellTab.lab);
      expect(find.text('Memory Lab'), findsOneWidget);
      Shell.current!.openAccount();
      await settle(tester, 1200);
      expect(Shell.current!.tab, ShellTab.account);
      expect(find.text('Account'), findsOneWidget);
      Shell.current!.openLab();
      await settle(tester, 900);
      expect(Shell.current!.tab, ShellTab.lab, reason: 'a tab further down comes back to the top');
      Shell.current!.goHome();
      await settle(tester, 900);
      expect(Shell.current!.tab, ShellTab.decks);

      // The + on Home asks deck or card; a card opens the editor sheet.
      Shell.current!.create();
      await settle(tester, 1200);
      expect(find.text('New deck'), findsOneWidget);
      await tester.tap(find.text('New card'));
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
