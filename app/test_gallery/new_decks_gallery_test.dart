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
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/ui/textures.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders two cards of each deck in [decks] (front, then revealed) and the home screen with them, to
/// build/gallery/new-*.png, for reviewing new shop decks as the app draws them. Not part of the regular suite:
///   flutter test test_gallery/new_decks_gallery_test.dart
/// The decks to review (missing ones are skipped).
const decks = [
  'flags-lookalike', 'country-silhouettes', 'road-signs', 'capitals-surprise',
  'paintings-details', 'kanji-pictographs', 'cognitive-biases', 'nato-alphabet',
  'anime-eyes', 'demonslayer-characters', 'jjk-characters', 'dragonball-characters', 'aot-characters',
];

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

  /// Bundled pictures decode on the real event loop, so give them time before the shot.
  Future<void> shot(WidgetTester tester, String name) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() async {
      final b = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.5);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  testWidgets('new decks gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    final dir = Directory.systemTemp.createTempSync('mc_new_decks_');
    final store = (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final f = s.createFolder('New decks');
      final ids = <String, String>{};
      for (final id in decks) {
        if (s.catalog.byId(id) != null) ids[id] = s.addCatalogDeck(id, f.id).id;
      }
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe', 'deck-swipe']) {
        s.markCoach(id);
      }
      s.touchFolder(f.id);
      await Future.wait([for (final d in Textures.all) Textures.i.load(d.id)]);
      return (s, ids);
    }))!;
    final (s, ids) = store;
    s.updateSettings((x) => x.reveal = RevealMode.tap);
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: s)));
    await settle(tester, 2500);
    await shot(tester, 'new-home');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
    await settle(tester, 900);
    await shot(tester, 'new-home-2');

    for (final e in ids.entries) {
      final d = s.data.decks[e.value]!;
      final forward = s.data.cardsOf(d).where((c) => !c.isReverse).toList();
      final picks = [forward.first, forward[forward.length ~/ 2]];
      for (var k = 0; k < picks.length; k++) {
        d.stack = [picks[k].id, ...d.stack.where((c) => c != picks[k].id)];
        Shell.current!.study(d.id);
        await settle(tester, 1600);
        await shot(tester, 'new-${e.key}-$k-front');
        final reveal = find.text('Tap to reveal');
        if (reveal.evaluate().isNotEmpty) {
          await tester.tap(reveal.first);
          await settle(tester, 1800);
        }
        await shot(tester, 'new-${e.key}-$k-back');
        Shell.current!.goHome();
        await settle(tester, 900);
      }
    }

    debugDisableShadows = true;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
