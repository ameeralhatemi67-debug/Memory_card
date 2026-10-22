import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders the first-run tour to build/gallery/*.png for visual review, light and dark, with real fonts
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

  testWidgets('gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Real, blurred shadows (tests draw them solid by default).
    debugDisableShadows = false;
    final dir = Directory.systemTemp.createTempSync('mc_gallery_');
    final store = (await tester.runAsync(() => AppStore.open(path: dir.path)))!;
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: store)));
    await settle(tester, 3000);

    // ---------------------------------------------------------------- the tour
    await shot(tester, '01-tour-welcome');
    await tester.drag(find.text('Remember anything,\none swipe at a time.'), const Offset(300, 0));
    await settle(tester);
    await tester.tap(find.text('Tap to reveal'));
    await settle(tester, 500);
    await shot(tester, '02-tour-recall');
    await tester.drag(find.text('The capital of Australia?'), const Offset(300, 0));
    await settle(tester);
    await tester.tap(find.text('Tap to reveal'));
    await settle(tester, 400);
    await tester.drag(find.text('der Schmetterling'), const Offset(-300, 0));
    await settle(tester, 2600);
    await shot(tester, '03-tour-reinsert');
    await tester.drag(find.text('It comes back\nin 8 cards'), const Offset(300, 0));
    await settle(tester, 1200);
    await shot(tester, '04-tour-grades');
    await tester.tap(find.text('or tap here'));
    await settle(tester, 1500);
    await shot(tester, '05-tour-fsrs');
    await tester.tap(find.text('or tap here'));
    await settle(tester);
    await shot(tester, '06-setup-decks');
    await tester.tap(find.textContaining('Continue'));
    await settle(tester);
    await shot(tester, '07-setup-goal');
    await tester.tap(find.text('Continue'));
    await settle(tester);
    await shot(tester, '08-setup-remind');
    await tester.tap(find.text('Not now'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Sam Rivera');
    await settle(tester, 400);
    await shot(tester, '09-setup-card');
    await tester.tap(find.text('Continue'));
    await settle(tester, 1800);
    await shot(tester, '10-setup-ready');
    await tester.tap(find.text('Look around first'));
    await settle(tester, 2200);
    await shot(tester, '11-home-coach');
    await tester.tapAt(const Offset(200, 700));
    await settle(tester, 400);

    debugDisableShadows = true;
    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
