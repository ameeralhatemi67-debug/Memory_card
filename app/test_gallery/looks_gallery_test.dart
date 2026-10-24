import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/engine/assessor.dart';
import 'package:memory_card/engine/days.dart';
import 'package:memory_card/features/decks/deck_maker.dart';
import 'package:memory_card/features/profile/profile_screen.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/features/shop/preview_sheet.dart';
import 'package:memory_card/features/study/celebrate.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/textures.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders the nav tabs, the create menu, deck skins, the deck maker and deck seals to build/gallery/looks-*.png.
/// Not part of the regular suite:  flutter test test_gallery/looks_gallery_test.dart
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
    // Pictures decode off the test clock.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() async {
      final b = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.5);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/looks-$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  testWidgets('looks gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    final dir = Directory.systemTemp.createTempSync('mc_looks_');
    late String ownId;
    final store = (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final f = s.createFolder('Library');
      final seals = [
        DeckSeal(id: 'a', title: 'First steps', when: 'start', shape: 'square', color: 'red', text: 'KANJI'),
        DeckSeal(id: 'b', title: 'Road trip', when: 'seen', shape: 'wide', color: 'gold', text: 'GT', image: 'asset:assets/content/img/car-brands/audi.png'),
        DeckSeal(id: 'c', title: 'Master', when: 'mastered', shape: 'square', color: 'teal', text: '', image: 'asset:assets/content/img/car-brands/bmw.png', art: 'color'),
        DeckSeal(id: 'd', title: 'Hundred', when: 'reviews', shape: 'wide', color: 'ink', text: '100'),
      ];
      final own = s.createDeck(
        name: 'Haki · My notes',
        folderId: f.id,
        skin: DeckSkin(src: 'asset:assets/content/img/hxh-characters/cand-a.jpg', x: 0.5, y: 0.35, shade: 0.6),
        seals: seals,
      );
      ownId = own.id;
      s.importRows(own.id, [for (var i = 0; i < 12; i++) CardDraft(front: 'Prompt $i', back: 'Answer $i')], newDeck: true);
      for (final id in ['es-basics', 'naruto-characters', 'car-brands', 'football-world-cup', 'onepiece-characters', 'football-crests-england']) {
        s.addCatalogDeck(id, f.id);
      }
      s.createDeck(
        name: 'Dark skin test',
        folderId: f.id,
        skin: DeckSkin(src: 'asset:assets/content/img/hxh-characters/ikalgo.jpg', x: 0.6, y: 0.5, shade: 0.7, light: false),
      );
      // A little history so the bars have fans and the seals some milestones.
      final rnd = math.Random(3);
      for (var day = 0; day < 4; day++) {
        for (final d in s.data.activeDecks.toList()) {
          s.prepare(d.id, notify: false);
          for (var i = 0; i < 14; i++) {
            final id = s.top(d.id);
            if (id == null) break;
            s.swipe(
              deckId: d.id,
              cardId: id,
              recalled: rnd.nextDouble() < 0.8,
              signals: ReviewSignals(thinkMs: 1800 + rnd.nextInt(2000), verifyMs: 700, dragMs: 200, velocity: 1.1, promptChars: 8),
            );
          }
        }
        s.shiftClock(msPerDay);
      }
      // A long name wraps the greeting to two lines, as on the owner's phone.
      s.updateSettings((x) => x.name = 'Amir Alhatemi');
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe', 'deck-swipe']) {
        s.markCoach(id);
      }
      await s.flush();
      await Future.wait([for (final d in Textures.all) Textures.i.load(d.id)]);
      return s;
    }))!;
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: store)));
    await settle(tester, 3000);
    await shot(tester, '01-home');

    // The + on Home asks: deck or card.
    await tester.tap(find.bySemanticsLabel('Create'));
    await settle(tester, 300);
    await shot(tester, '02-create-menu-opening');
    await settle(tester, 900);
    await shot(tester, '03-create-menu');
    await tester.tap(find.text('New deck'));
    await settle(tester, 1400);
    await shot(tester, '04-deck-maker-new');
    final nav = Navigator.of(tester.element(find.byType(Shell)), rootNavigator: true);
    nav.pop();
    await settle(tester, 800);

    // The deck maker on a deck with a picture skin and four seals.
    openDeckMaker(tester.element(find.byType(Shell)), deckId: ownId);
    await settle(tester, 1600);
    await shot(tester, '05-deck-maker-skin');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await settle(tester, 800);
    await shot(tester, '06-deck-maker-seals');
    await tester.tap(find.text('Road trip'));
    await settle(tester, 1800);
    await shot(tester, '07-seal-maker');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await settle(tester, 800);
    await shot(tester, '08-seal-maker-more');
    nav.pop();
    await settle(tester, 700);
    nav.pop();
    await settle(tester, 700);

    // A shop deck in the deck maker (Shop / Plain / Picture).
    final narutoId = store.data.shopAdded['naruto-characters']!;
    openDeckMaker(tester.element(find.byType(Shell)), deckId: narutoId);
    await settle(tester, 1600);
    await shot(tester, '09-deck-maker-shop-deck');
    nav.pop();
    await settle(tester, 700);

    // The new tabs.
    Shell.current!.openLab();
    await settle(tester, 1600);
    await shot(tester, '10-lab-tab');
    Shell.current!.openAccount();
    await settle(tester, 1600);
    await shot(tester, '11-account-tab');
    await tester.tap(find.bySemanticsLabel('Create'));
    await settle(tester, 1200);
    await shot(tester, '12-create-from-account');
    Shell.current!.closeCreate();
    await settle(tester, 600);

    // Seals: pressed, and the gallery.
    final own = store.data.decks[ownId]!;
    showDeckSealsDialog(tester.element(find.byType(Shell)), deckName: own.name, seals: [own.seals[1]]);
    await settle(tester, 2600);
    await shot(tester, '13-deck-seal-dialog');
    nav.pop();
    await settle(tester, 700);
    showDeckSealsDialog(tester.element(find.byType(Shell)), deckName: own.name, seals: own.seals.take(3).toList());
    await settle(tester, 3200);
    await shot(tester, '14-deck-seals-dialog-3');
    nav.pop();
    await settle(tester, 700);
    showSealGallery(tester.element(find.byType(Shell)), store);
    await settle(tester, 1400);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await settle(tester, 800);
    await shot(tester, '15-seal-gallery-decks');
    nav.pop();
    await settle(tester, 700);

    // Shop.
    Shell.current!.openShop();
    await settle(tester, 1600);
    await shot(tester, '16-shop');
    // The football decks, found through the shop's search.
    await tester.enterText(find.byType(TextField).first, 'Football');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 1400);
    await shot(tester, '16b-shop-football');
    await tester.dragFrom(const Offset(195, 600), const Offset(0, -500));
    await settle(tester, 900);
    await shot(tester, '16c-shop-football-more');
    await tester.enterText(find.byType(TextField).first, '');
    await settle(tester, 900);
    await tester.tap(find.bySemanticsLabel('Create'));
    await settle(tester, 1200);
    await shot(tester, '17-create-from-shop');
    Shell.current!.closeCreate();
    await settle(tester, 600);
    showPreview(tester.element(find.byType(Shell)), 'football-legends');
    await settle(tester, 1500);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await settle(tester, 800);
    await shot(tester, '18-preview-look');
    nav.pop();
    await settle(tester, 700);

    // Studying a deck: + goes straight to a card for it.
    Shell.current!.study(ownId);
    await settle(tester, 1500);
    await tester.tap(find.bySemanticsLabel('Create'));
    await settle(tester, 1400);
    await shot(tester, '19-create-in-deck');
    nav.pop();
    await settle(tester, 700);
    Shell.current!.goHome();
    await settle(tester, 1000);

    // Dark.
    store.updateSettings((s) => s.theme = 'dark');
    await settle(tester, 1200);
    await shot(tester, '20-dark-home');
    await tester.tap(find.bySemanticsLabel('Create'));
    await settle(tester, 350);
    await shot(tester, '20b-dark-create-dealing');
    await settle(tester, 900);
    await shot(tester, '20c-dark-create');
    Shell.current!.closeCreate();
    await settle(tester, 700);
    openDeckMaker(tester.element(find.byType(Shell)), deckId: ownId);
    await settle(tester, 1600);
    await shot(tester, '21-dark-deck-maker');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await settle(tester, 800);
    await shot(tester, '22-dark-deck-maker-seals');
    nav.pop();
    await settle(tester, 700);
    Shell.current!.openAccount();
    await settle(tester, 1600);
    await shot(tester, '23-dark-account');
    Shell.current!.openLab();
    await settle(tester, 1600);
    await shot(tester, '24-dark-lab');

    debugDisableShadows = true;
    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
