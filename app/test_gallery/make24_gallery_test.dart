import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/features/study/card_face.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/textures.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders the Make 24 decks in the real app: the library bar with its cover, a card's four numbers, the ways
/// ticked after the reveal, a card coming back with a way already found, and the shop's Math shelf, to
/// build/gallery/m24-*.png:
///   flutter test test_gallery/make24_gallery_test.dart
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

    await family('GalleryText', [for (final w in ['light', 'regular', 'bold']) '$artifacts/material_fonts/robotocondensed-$w.ttf']);
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

  Future<void> advance(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final b = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.0);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  testWidgets('make 24 gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    final dir = Directory.systemTemp.createTempSync('mc_make24_gallery_');
    final store = (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final f = s.createFolder('Make 24');
      for (final id in ['make24-03', 'make24-02', 'make24-01']) {
        s.addCatalogDeck(id, f.id);
      }
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe', 'deck-swipe']) {
        s.markCoach(id);
      }
      s.touchFolder(f.id);
      s.updateSettings((x) => x.reveal = RevealMode.tap);
      await Future.wait([for (final d in Textures.all) Textures.i.load(d.id)]);
      return s;
    }))!;
    final first = store.data.decks.values.firstWhere((d) => d.catalogId == 'make24-01');
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: store)));
    await advance(tester, 2.5);
    // Pictures decode on real time.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 900)));
    await advance(tester, 0.3);
    await shot(tester, 'm24-dark-1-library');

    for (final theme in ['dark', 'light']) {
      store.updateSettings((x) => x.theme = theme);
      final top = store.data.cards[store.top(first.id)]!;
      top.found.clear();
      if (theme == 'light') top.found.add(0);
      tester.state<ShellState>(find.byType(Shell)).study(first.id);
      await advance(tester, 1.6);
      await shot(tester, 'm24-$theme-2-front');
      await tester.tap(find.text('Tap to reveal'));
      await advance(tester, 0.6);
      await tester.tap(find.text(top.ways[top.ways.length > 2 ? 2 : 0]));
      await advance(tester, 0.4);
      await shot(tester, 'm24-$theme-3-ways');
      if (theme == 'light') {
        await tester.tap(find.text(top.ways[top.ways.length > 2 ? 2 : 0]));
        await tester.tap(find.text(top.ways[0]));
        await advance(tester, 0.3);
        await tester.dragFrom(tester.getCenter(find.byType(NumberTiles)), const Offset(300, 0));
        await advance(tester, 0.5);
        await shot(tester, 'm24-$theme-4-found-before');
      }
      tester.state<ShellState>(find.byType(Shell)).goHome();
      await advance(tester, 1.0);
    }

    // The shop's Math shelf.
    tester.state<ShellState>(find.byType(Shell)).openShop();
    await advance(tester, 1.2);
    await tester.enterText(find.byType(EditableText).first, 'Make 24');
    await advance(tester, 0.8);
    FocusManager.instance.primaryFocus?.unfocus();
    await advance(tester, 0.8);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 900)));
    await advance(tester, 0.3);
    await shot(tester, 'm24-light-5-shop');

    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    debugDisableShadows = true;
  });
}
