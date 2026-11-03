// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/features/decks/deck_maker.dart';
import 'package:memory_card/features/settings/settings_screen.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/features/study/scratch_foil.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/textures.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders Scratch to reveal (silver foil) in the real study screen, frame by frame, plus Settings › Study
/// and the deck sheet's Reveal section, to build/gallery/scr-*.png:
///   flutter test test_gallery/scratch_gallery_test.dart
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

  testWidgets('scratch gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    final dir = Directory.systemTemp.createTempSync('mc_scratch_gallery_');
    final store = (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final f = s.createFolder('Languages');
      s.addCatalogDeck('it-basics', f.id);
      s.addCatalogDeck('es-basics', f.id);
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe', 'deck-swipe']) {
        s.markCoach(id);
      }
      s.updateSettings((x) => x
        ..reveal = RevealMode.scratch
        ..revealScope = RevealScope.picked);
      s.updateSettings((x) => x.revealDecks = {s.data.decks.values.first.id});
      await Future.wait([for (final d in Textures.all) Textures.i.load(d.id)]);
      return s;
    }))!;
    final it = store.data.decks.values.firstWhere((d) => d.catalogId == 'it-basics');
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: store)));
    await advance(tester, 2.5);

    for (final theme in ['dark', 'light']) {
      store.updateSettings((x) => x.theme = theme);
      tester.state<ShellState>(find.byType(Shell)).study(it.id);
      await advance(tester, 1.6);
      await shot(tester, 'scr-$theme-1-rest');

      final r = tester.getRect(find.byType(ScratchFoil));
      final g = await tester.startGesture(Offset(r.left + 10, r.top + 14));
      var row = 0, done = false;
      while (!done && row < 8) {
        final y = r.top + 14 + (row % 5) * (r.height - 28) / 4;
        final from = row.isEven ? r.left + 10 : r.right - 10, to = row.isEven ? r.right - 10 : r.left + 10;
        for (var i = 1; i <= 14 && !done; i++) {
          await g.moveTo(Offset(from + (to - from) * i / 14, y + (i.isEven ? 3 : -3)));
          await tester.pump(const Duration(milliseconds: 16));
          done = find.bySemanticsLabel('Scratch to reveal the answer').evaluate().isEmpty;
        }
        if (row == 1 && !done) await shot(tester, 'scr-$theme-2-scratching');
        row++;
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 16));
      await shot(tester, 'scr-$theme-3-break');
      await advance(tester, 0.2);
      await shot(tester, 'scr-$theme-4-flakes');
      await advance(tester, 0.35);
      await shot(tester, 'scr-$theme-5-falling');
      await advance(tester, 1.2);
      await shot(tester, 'scr-$theme-6-answer');
      tester.state<ShellState>(find.byType(Shell)).goHome();
      await advance(tester, 1.0);
    }

    // Settings › Study, with the picked decks and the vibration slider showing.
    Navigator.of(tester.element(find.byType(Shell))).push(SettingsScreen.route());
    await advance(tester, 1.0);
    await shot(tester, 'scr-light-7-settings');
    Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
    await advance(tester, 0.8);

    // The deck sheet's Reveal section.
    openDeckMaker(tester.element(find.byType(Shell)), deckId: it.id);
    await advance(tester, 1.0);
    await tester.drag(find.byType(ListView).last, const Offset(0, -420));
    await advance(tester, 0.8);
    await shot(tester, 'scr-light-8-deck-sheet');

    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    debugDisableShadows = true;
  });
}
