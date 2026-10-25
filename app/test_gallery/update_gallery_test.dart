// ignore_for_file: use_build_context_synchronously, invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/features/settings/updates_screen.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/services/updates.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/textures.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders the update card in the real app, frame by frame, to build/gallery/upd-*.png:
///   flutter test test_gallery/update_gallery_test.dart
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

  String release(String tag) => jsonEncode({
        'tag_name': tag,
        'body': '- **Smarter reminders** say the real minutes and back off when you are away\n- A Today strip on Home, plus a session timer\n- Fix: widgets keep their size after an update',
        'html_url': 'https://github.com/${Updates.repo}/releases/tag/$tag',
        'assets': [
          {'name': 'MemoryCard.apk', 'size': 150123456, 'browser_download_url': 'https://github.com/${Updates.repo}/releases/download/$tag/MemoryCard.apk'},
        ],
      });

  Future<AppStore> openStore(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('mc_update_gallery_');
    return (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final f = s.createFolder('Languages');
      for (final id in ['pt-everyday', 'fr-essentials', 'it-basics', 'es-basics']) {
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
  }

  testWidgets('update card gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    final store = await openStore(tester);
    Updates.i.fetcher = (uri) async => release('v1.6.0');
    store.updateSettings((s) => s.updateCheck = false);
    await tester.runAsync(() async {
      await Updates.i.attach(store, installedVersion: '1.5.0', buildNumber: '10');
      await Updates.i.check();
    });
    store.updateSettings((x) => x.theme = 'dark');
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: store)));
    // The first time: the gold 1 on the + card, then at 0.9 s the card deals itself (0.95 s in the air).
    await advance(tester, 0.5);
    await shot(tester, 'upd-dark-1-badge');
    await advance(tester, 0.3);
    for (var i = 0; i < 13; i++) {
      await advance(tester, 0.1);
      await shot(tester, 'upd-dark-2-seq-${i.toString().padLeft(2, '0')}');
    }
    await advance(tester, 0.6);

    for (final theme in ['dark', 'light']) {
      store.updateSettings((x) => x.theme = theme);
      await advance(tester, 0.7);

      if (theme == 'light') {
        // Later on, the same card from Settings › Updates › Preview, or the + fan.
        await tester.tap(find.bySemanticsLabel('Create, one update waiting'));
        await advance(tester, 1.4);
        await shot(tester, 'upd-$theme-5-fan');
        await tester.tap(find.text('Update'));
        await advance(tester, 1.6);
      }
      await shot(tester, 'upd-$theme-3-open');

      await tester.tap(find.text('Update now'));
      await advance(tester, 0.5);
      await shot(tester, 'upd-$theme-4-steps');
      await tester.tap(find.text('Back'));
      await advance(tester, 0.3);
      await tester.tap(find.text('Later'));
      await advance(tester, 0.25);
      if (theme == 'dark') await shot(tester, 'upd-$theme-4b-returning');
      await advance(tester, 1.0);

      if (theme == 'dark') {
        await tester.tap(find.bySemanticsLabel('Create, one update waiting'));
        await advance(tester, 1.4);
        await shot(tester, 'upd-$theme-5-fan');
        await tester.tap(find.bySemanticsLabel('Close'));
        await advance(tester, 1.0);
      }

      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(UpdatesScreen.route());
      await advance(tester, 1.0);
      await shot(tester, 'upd-$theme-6-settings');
      Navigator.of(Shell.current!.context).pop();
      await advance(tester, 0.8);
    }

    debugDisableShadows = true;
    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
