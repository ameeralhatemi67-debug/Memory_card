// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/features/decks/deck_row.dart';
import 'package:memory_card/ui/textures.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders the deck list with a bar mid-swipe and at rest on each detent, both ways, to build/gallery/swipe-*.png. Not part of the regular suite:
///   flutter test test_gallery/swipe_gallery_test.dart
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

  testWidgets('swipe gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    final dir = Directory.systemTemp.createTempSync('mc_swipe_gallery_');
    final store = (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final f = s.createFolder('Languages');
      for (final id in ['es-basics', 'fr-essentials', 'it-basics', 'pt-everyday']) {
        s.addCatalogDeck(id, f.id);
      }
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe', 'deck-swipe']) {
        s.markCoach(id);
      }
      s.touchFolder(f.id);
      await Future.wait([for (final d in Textures.all) Textures.i.load(d.id)]);
      return s;
    }))!;
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: store)));
    await settle(tester, 2500);

    for (final theme in ['dark', 'light']) {
      store.updateSettings((x) => x.theme = theme);
      await settle(tester, 700);
      final row = find.byType(DeckRow).at(1);
      for (final side in [-1, 1]) {
        final tag = '$theme-${side < 0 ? 'left' : 'right'}';
        final g = await tester.startGesture(tester.getCenter(row));
        // Part way: the bar follows the finger with its edge sinking into the wall.
        for (var i = 0; i < 6; i++) {
          await g.moveBy(Offset(side * 12.0, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }
        await shot(tester, 'swipe-$tag-drag-a');
        for (var i = 0; i < 6; i++) {
          await g.moveBy(Offset(side * 12.0, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }
        await shot(tester, 'swipe-$tag-drag-b');
        await g.up();
        await settle(tester, 900);
        await shot(tester, 'swipe-$tag-detent1');
        // Pull on to the second detent.
        final g2 = await tester.startGesture(tester.getCenter(row));
        for (var i = 0; i < 10; i++) {
          await g2.moveBy(Offset(side * 10.0, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }
        await g2.up();
        await settle(tester, 900);
        await shot(tester, 'swipe-$tag-detent2');
        // Close it with a tap on the bar.
        await tester.tapAt(tester.getCenter(row) + Offset(side * -60.0 + (side < 0 ? 40 : -40), 0));
        await settle(tester, 700);
      }
    }
    debugDisableShadows = true;
  });
}
