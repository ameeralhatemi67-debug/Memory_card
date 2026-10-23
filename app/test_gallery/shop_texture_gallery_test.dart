// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/features/settings/settings_screen.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/features/shop/shop_tile.dart';
import 'package:memory_card/ui/textures.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders the shop (deck of the day, the long-press quick actions at several moments) and the Texture
/// tab to build/gallery/shop-*.png. Not part of the regular suite:
///   flutter test test_gallery/shop_texture_gallery_test.dart
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

  testWidgets('shop and texture gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    final dir = Directory.systemTemp.createTempSync('mc_shop_gallery_');
    final store = (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final f = s.createFolder('Languages');
      s.addCatalogDeck('es-basics', f.id);
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe']) {
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
      await settle(tester, 600);
      Shell.current!.openShop();
      await settle(tester, 1600);
      await shot(tester, 'shop-$theme-hero-0');
      await settle(tester, 1500); // the under-cards rock now and then
      await shot(tester, 'shop-$theme-hero-1');
      await settle(tester, 1500);
      await shot(tester, 'shop-$theme-hero-2');

      // The long-press quick actions, as the badges turn one after another.
      await tester.longPress(find.byType(ShopTile).first);
      await settle(tester, 700);
      await shot(tester, 'shop-$theme-hold-0');
      for (var i = 1; i <= 3; i++) {
        await settle(tester, 1100);
        await shot(tester, 'shop-$theme-hold-$i');
      }
      await tester.tapAt(const Offset(195, 800)); // dismiss
      await settle(tester, 700);
      Shell.current!.goHome();
      await settle(tester, 700);
    }

    // The Texture tab, top to bottom.
    store.updateSettings((x) => x.theme = 'dark');
    await settle(tester, 600);
    final nav = Navigator.of(tester.element(find.byType(Shell)), rootNavigator: true);
    nav.push(SettingsScreen.route());
    await settle(tester, 1200);
    await tester.tap(find.text('Texture'));
    await settle(tester, 900);
    await shot(tester, 'shop-texture-0');
    for (var i = 1; i <= 5; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -520));
      await settle(tester, 500);
      await shot(tester, 'shop-texture-$i');
    }
    debugDisableShadows = true;
  });
}
