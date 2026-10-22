import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/engine/assessor.dart';
import 'package:memory_card/engine/days.dart';
import 'package:memory_card/features/browse/card_detail.dart';
import 'package:memory_card/features/browse/deck_browser.dart';
import 'package:memory_card/features/help/help_screen.dart';
import 'package:memory_card/features/lab/memory_lab.dart';
import 'package:memory_card/features/profile/profile_screen.dart';
import 'package:memory_card/features/search/search_screen.dart';
import 'package:memory_card/features/settings/settings_screen.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/features/shop/shop_tile.dart';
import 'package:memory_card/features/study/card_face.dart';
import 'package:memory_card/features/onboarding/tutorial_deck.dart';
import 'package:memory_card/features/study/celebrate.dart';
import 'package:memory_card/features/today/today_screen.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders every screen after two weeks of use to build/gallery/*.png for visual review, light and dark, with real fonts
/// (Roboto Condensed stands in for Barlow Semi Condensed; Bernard is the local design font).
/// Not part of the regular suite:  flutter test test_gallery/gallery_test.dart
void main() {
  final shotKey = GlobalKey();
  final out = Directory('build/gallery');

  Future<void> loadFonts() async {
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent.path;
    final cache = Directory(artifacts).parent.path;
    Future<void> family(String name, List<String> files) async {
      final loader = FontLoader(name);
      var any = false;
      for (final f in files) {
        final file = File(f);
        if (!file.existsSync()) continue;
        any = true;
        loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
      }
      if (any) await loader.load();
    }

    await family('GalleryText', [
      for (final w in ['light', 'regular', 'bold']) '$artifacts/material_fonts/robotocondensed-$w.ttf',
    ]);
    await family('GalleryMono', [
      for (final w in ['Regular', 'Medium', 'Bold']) '$cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto_Mono/RobotoMono-$w.ttf',
    ]);
    await family('Bernard', ['assets/fonts/BernardMTCondensed.ttf']);
    await family('MaterialIcons', ['$artifacts/material_fonts/materialicons-regular.otf']);
  }

  setUpAll(() async {
    T.googleFonts = false;
    T.testFamily = 'GalleryText';
    T.testMono = 'GalleryMono';
    await loadFonts();
    out.createSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester, [int ms = 900]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() async {
      final b = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.5);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  /// [days] days of study in every active deck, with signals shaped like real answers.
  Future<void> simulate(AppStore store, int days, math.Random rnd) async {
    for (var day = 0; day < days; day++) {
      for (final d in store.data.activeDecks.toList()) {
        if (rnd.nextDouble() < 0.25) continue;
        store.prepare(d.id, notify: false);
        final n = 10 + rnd.nextInt(20);
        for (var i = 0; i < n; i++) {
          final id = store.top(d.id);
          if (id == null) break;
          final c = store.data.cards[id]!;
          final p = c.reps == 0 ? 0.5 : (store.engine.recall(c, store.now()) ?? 0.8).clamp(0.25, 0.97);
          final ok = rnd.nextDouble() < p;
          store.swipe(
            deckId: d.id,
            cardId: id,
            recalled: ok,
            signals: ReviewSignals(
              thinkMs: (ok ? 1500 : 3800) + rnd.nextInt(4000),
              verifyMs: 500 + rnd.nextInt(1600),
              dragMs: 160 + rnd.nextInt(220),
              velocity: 0.8 + rnd.nextDouble(),
              reversals: rnd.nextDouble() < 0.15 ? 1 : 0,
              promptChars: c.front.length,
            ),
          );
        }
      }
      store.shiftClock(msPerDay);
    }
    await store.flush();
  }

  testWidgets('gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Real, blurred shadows (tests draw them solid by default).
    debugDisableShadows = false;
    final dir = Directory.systemTemp.createTempSync('mc_gallery_');
    // The library and two weeks of history are built before the UI starts: disk writes begun under the
    // widget-test clock would otherwise never finish.
    final store = (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final start = s.createFolder('Start here');
      final tut = s.createDeck(name: tutorialDeckName, folderId: start.id, mono: '?', category: 'custom', description: 'Learn the app by using it.');
      s.importRows(tut.id, tutorialCards, newDeck: true);
      final lang = s.createFolder('Languages', atTop: false);
      for (final id in ['es-basics', 'it-basics', 'fr-essentials']) {
        s.addCatalogDeck(id, lang.id);
      }
      final coding = s.createFolder('Coding', atTop: false);
      s.addCatalogDeck('python-syntax', coding.id);
      s.addCatalogDeck('git-commands', coding.id);
      s.addCatalogDeck('world-capitals', s.createFolder('Knowledge', atTop: false).id);
      s.updateSettings((x) => x.name = 'Sam Rivera');
      await simulate(s, 14, math.Random(4));
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe']) {
        s.markCoach(id);
      }
      s.touchFolder(lang.id);
      await s.logs();
      await s.flush();
      return s;
    }))!;
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: store)));
    await settle(tester, 3000);
    await shot(tester, '12-home');

    Shell.current!.openDrawer();
    await settle(tester, 1400);
    await shot(tester, '13-drawer');
    Shell.current!.closeDrawer();
    await settle(tester);

    // ---------------------------------------------------------------- studying
    final deckId = store.data.shopAdded['es-basics'] ?? store.data.decks.keys.first;
    Shell.current!.study(deckId);
    await settle(tester, 1500);
    await shot(tester, '14-study-front');
    if (find.text('Tap to reveal').evaluate().isNotEmpty) {
      await tester.tap(find.text('Tap to reveal'));
      await settle(tester, 600);
    }
    await shot(tester, '15-study-revealed');
    final g = await tester.startGesture(tester.getCenter(find.byType(CardFront).first));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(22, 2));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester, 300);
    await shot(tester, '16-study-drag-right');
    await g.moveBy(const Offset(60, 0));
    await g.up();
    await settle(tester, 900);
    await shot(tester, '17-study-after-swipe');
    final cardDone = store.data.today?.done ?? 0;
    showGoalDialog(tester.element(find.byType(Shell)),
        done: math.max(cardDone, store.settings.goal), streak: 7, seals: const ['first-stack', 'week']);
    await settle(tester, 2600);
    await shot(tester, '18-goal-dialog');
    Navigator.of(tester.element(find.byType(Shell)), rootNavigator: true).pop();
    await settle(tester);
    showMasteredDialog(tester.element(find.byType(Shell)), deckName: 'Spanish · Basics', cards: 24);
    await settle(tester, 2400);
    await shot(tester, '18b-mastered-dialog');
    Navigator.of(tester.element(find.byType(Shell)), rootNavigator: true).pop();
    await settle(tester);
    Shell.current!.goHome();
    await settle(tester, 1200);

    // ---------------------------------------------------------------- the rest of the app
    final nav = Navigator.of(tester.element(find.byType(Shell)), rootNavigator: true);
    Future<void> page(Route<void> r, String name, {Future<void> Function()? extra}) async {
      nav.push(r);
      await settle(tester, 1600);
      await shot(tester, name);
      if (extra != null) await extra();
      nav.pop();
      await settle(tester, 700);
    }

    await page(TodayScreen.route(), '19-today');
    await page(ProfileScreen.route(), '20-profile', extra: () async {
      await tester.tap(find.textContaining('TIER').first);
      await settle(tester, 1200);
      await shot(tester, '21-profile-back');
    });
    await page(MemoryLab.route(), '22-lab', extra: () async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await settle(tester, 800);
      await shot(tester, '23-lab-more');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await settle(tester, 800);
      await shot(tester, '24-lab-end');
    });
    await page(SettingsScreen.route(), '25-settings', extra: () async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await settle(tester, 600);
      await shot(tester, '26-settings-more');
    });
    await page(DeckBrowser.route(deckId), '27-deck-browser');
    final studied = store.data.cardsOf(store.data.decks[deckId]!).firstWhere((c) => c.reps > 2, orElse: () => store.data.cardsOf(store.data.decks[deckId]!).first);
    await page(CardDetail.route(studied.id), '28-card-detail');
    await page(SearchScreen.route(), '29-search', extra: () async {
      await tester.enterText(find.byType(TextField).first, 'ca');
      await settle(tester, 600);
      await shot(tester, '30-search-results');
    });
    await page(HelpScreen.route(), '31-help');

    // Shop, hold menu, preview.
    Shell.current!.openShop();
    await settle(tester, 1600);
    await shot(tester, '32-shop');
    final visible = find.byType(ShopTile).evaluate().map((e) => e.renderObject! as RenderBox).firstWhere((b) {
      final y = b.localToGlobal(b.size.center(Offset.zero)).dy;
      return y > 260 && y < 600;
    });
    await tester.longPressAt(visible.localToGlobal(visible.size.center(Offset.zero)));
    await settle(tester, 900);
    await shot(tester, '33-shop-hold');
    await tester.tapAt(const Offset(30, 820));
    await settle(tester, 700);
    await tester.tap(find.text('Preview').first);
    await settle(tester, 1500);
    await shot(tester, '34-preview');
    nav.pop();
    await settle(tester, 800);

    // Editor.
    Shell.current!.create();
    await settle(tester, 1400);
    await shot(tester, '35-editor');
    await tester.tap(find.text('Import CSV'));
    await settle(tester, 800);
    await shot(tester, '36-editor-import');
    nav.pop();
    await settle(tester, 800);
    Shell.current!.goHome();
    await settle(tester, 800);

    // ---------------------------------------------------------------- dark
    store.updateSettings((s) => s.theme = 'dark');
    await settle(tester, 1200);
    await shot(tester, '40-dark-home');
    Shell.current!.study(deckId);
    await settle(tester, 1500);
    if (find.text('Tap to reveal').evaluate().isNotEmpty) {
      await tester.tap(find.text('Tap to reveal'));
      await settle(tester, 600);
    }
    await shot(tester, '41-dark-study');
    Shell.current!.goHome();
    await settle(tester, 1000);
    Shell.current!.openDrawer();
    await settle(tester, 1400);
    await shot(tester, '42-dark-drawer');
    Shell.current!.closeDrawer();
    await settle(tester);
    await page(TodayScreen.route(), '43-dark-today');
    await page(ProfileScreen.route(), '44-dark-profile');
    await page(MemoryLab.route(), '45-dark-lab');
    await page(SettingsScreen.route(), '46-dark-settings');
    Shell.current!.openShop();
    await settle(tester, 1600);
    await shot(tester, '47-dark-shop');

    debugDisableShadows = true;
    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
