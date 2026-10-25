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
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/textures.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders Delete A, Archive B and Pin A in the real app, frame by frame, to build/gallery/act-*.png:
///   flutter test test_gallery/deck_actions_gallery_test.dart
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

  Future<AppStore> openStore(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('mc_actions_gallery_');
    return (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final f = s.createFolder('Languages');
      for (final id in ['pt-everyday', 'fr-essentials', 'it-basics', 'es-basics']) {
        s.addCatalogDeck(id, f.id);
      }
      for (final name in ['Anime', 'Football', 'Knowledge', 'Cooking', 'Travel', 'Music', 'Science', 'History']) {
        s.createFolder(name, atTop: false);
      }
      s.addCatalogDeck('python-syntax', s.data.folders.firstWhere((x) => x.name == 'Knowledge').id);
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe', 'deck-swipe']) {
        s.markCoach(id);
      }
      s.touchFolder(f.id);
      await Future.wait([for (final d in Textures.all) Textures.i.load(d.id)]);
      return s;
    }))!;
  }

  Future<void> swipeRow(WidgetTester tester, Finder row, double dx) async {
    final g = await tester.startGesture(tester.getCenter(row));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(Offset(dx / 20, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await g.up();
    await advance(tester, 1.0);
  }

  testWidgets('deck actions gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    final store = await openStore(tester);
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: store)));
    await advance(tester, 2.5);

    for (final theme in ['dark', 'light']) {
      store.updateSettings((x) => x.theme = theme);
      await advance(tester, 0.7);

      // ------------------------------------------------------------------ Delete A
      if (theme == 'dark') {
        var rows = find.byType(DeckRow);
        await swipeRow(tester, rows.at(1), -100);
        final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('tile-delete'))));
        await advance(tester, 0.45);
        await shot(tester, 'act-$theme-delete-1-hold-0.45');
        await advance(tester, 0.5);
        await shot(tester, 'act-$theme-delete-2-hold-0.95');
        await advance(tester, 0.3); // 1.25: bursting
        await shot(tester, 'act-$theme-delete-3-burst');
        await advance(tester, 0.2);
        await shot(tester, 'act-$theme-delete-4-gap');
        await g.up();
        await advance(tester, 1.2);
        await shot(tester, 'act-$theme-delete-5-after');
      }

      // ------------------------------------------------------------------ Archive B
      var rows = find.byType(DeckRow);
      await swipeRow(tester, rows.at(0), -190);
      await tester.tap(find.byKey(const ValueKey('tile-archive')));
      await advance(tester, 0.3);
      await shot(tester, 'act-$theme-archive-1-pop');
      await advance(tester, 0.3);
      await shot(tester, 'act-$theme-archive-2-fall');
      await advance(tester, 0.2);
      await shot(tester, 'act-$theme-archive-3-land');
      await advance(tester, 0.4);
      await shot(tester, 'act-$theme-archive-4-in');
      await advance(tester, 1.5);
      await shot(tester, 'act-$theme-archive-5-after');

      // ------------------------------------------------------------------ Pin A
      rows = find.byType(DeckRow);
      final last = rows.last;
      await swipeRow(tester, last, 190);
      await tester.tap(find.byKey(const ValueKey('tile-pin')));
      await advance(tester, 0.3);
      await shot(tester, 'act-$theme-pin-1-lift');
      await advance(tester, 0.4);
      await shot(tester, 'act-$theme-pin-2-travel');
      await advance(tester, 0.4);
      await shot(tester, 'act-$theme-pin-3-pin');
      await advance(tester, 0.25);
      await shot(tester, 'act-$theme-pin-4-press');
      await advance(tester, 1.2);
      await shot(tester, 'act-$theme-pin-5-after');
      // put the deck back so the next theme starts the same
      store.togglePin(store.decksIn(store.currentFolder!).first.id);
      await advance(tester, 1.0);
    }

    // ---------------------------------------------------------------------- Move D with the folder card
    for (final theme in ['dark', 'light']) {
      store.updateSettings((x) => x.theme = theme);
      await advance(tester, 0.7);
      final rows = find.byType(DeckRow);
      await swipeRow(tester, rows.first, 100);
      await tester.tap(find.byKey(const ValueKey('tile-move')));
      await advance(tester, 0.2);
      await shot(tester, 'act-$theme-move-1-deal');
      await advance(tester, 0.2);
      await shot(tester, 'act-$theme-move-2-flip');
      await advance(tester, 1.0);
      await shot(tester, 'act-$theme-move-3-card');
      await tester.drag(find.byType(ListView).last, const Offset(0, -220));
      await advance(tester, 0.6);
      await shot(tester, 'act-$theme-move-4-scrolled');
      await tester.tap(find.text('Travel'));
      await advance(tester, 0.3);
      await shot(tester, 'act-$theme-move-5-chosen');
      await advance(tester, 0.7);
      await shot(tester, 'act-$theme-move-6-hook');
      await advance(tester, 0.4);
      await shot(tester, 'act-$theme-move-7-tug');
      await advance(tester, 0.5);
      await shot(tester, 'act-$theme-move-8-yank');
      await advance(tester, 0.3);
      await shot(tester, 'act-$theme-move-9-gone');
      await advance(tester, 1.6);
      await shot(tester, 'act-$theme-move-10-after');
      // undo, so that the next theme starts the same
      Toaster.i.current.value?.action?.call();
      Toaster.i.hide();
      await advance(tester, 1.0);
    }
    debugDisableShadows = true;
  });
}
