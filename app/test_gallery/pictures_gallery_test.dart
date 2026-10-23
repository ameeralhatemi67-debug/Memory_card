// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/card_layout.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/features/editor/editor_sheet.dart';
import 'package:memory_card/features/layout/layout_editor.dart';
import 'package:memory_card/features/layout/layout_face.dart';
import 'package:memory_card/features/settings/settings_screen.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/ui/textures.dart';
import 'package:memory_card/ui/theme.dart';

/// Renders the picture features to build/gallery/pic-*.png for visual review (real fonts, real bundled
/// pictures, light and dark). Not part of the regular suite:
///   flutter test test_gallery/pictures_gallery_test.dart
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

  testWidgets('pictures gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    final dir = Directory.systemTemp.createTempSync('mc_pic_gallery_');
    final store = (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final f = s.createFolder('Pictures');
      final ids = <String, String>{};
      for (final id in ['flags-africa', 'onepiece-characters', 'onepiece-powers', 'car-brands', 'naruto-characters']) {
        if (s.catalog.byId(id) != null) ids[id] = s.addCatalogDeck(id, f.id).id;
      }
      // A free-canvas card: text over a picture, a see-through flag (Nepal) beside it.
      final own = s.createDeck(name: 'My canvas', folderId: f.id);
      final canvas = SideLayout(mode: LayoutMode.canvas);
      final bg = ImageEl(
          x: 0, y: 0, w: 1, h: 0.62, src: 'asset:assets/content/img/onepiece-characters/monkey-d-luffy.jpg', aspect: 0.478, radius: 0, panY: 0.1);
      canvas.els.add(bg);
      canvas.els.add(ImageEl(
          x: 0.58, y: 0.5, w: 0.34, h: 0.3, src: 'asset:assets/content/img/flags-asia/np.png', aspect: 0.82, contain: true, alpha: true, radius: 0));
      canvas.els.add(TextEl(x: 0.07, y: 0.08, w: 0.86, h: 0.12, source: 'main', size: 30, color: 'light', bg: 'dark', align: 1));
      canvas.els.add(TextEl(x: 0.07, y: 0.82, w: 0.5, h: 0.1, source: 'custom', text: 'Captain of the Straw Hats', size: 20, font: 'plain', color: 'dark', bg: 'peach'));
      s.addCard(own.id, CardDraft(front: 'Who is this?', back: 'Monkey D. Luffy', hook: 'Rubber body', frontLayout: canvas));
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe']) {
        s.markCoach(id);
      }
      s.touchFolder(f.id);
      await Future.wait([for (final d in Textures.all) Textures.i.load(d.id)]);
      ids['own'] = own.id;
      s.data.lastDeckId = ids.values.first;
      return (s, ids);
    }))!;
    final (s, ids) = store;
    s.updateSettings((x) => x.reveal = RevealMode.tap);
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: s)));
    await settle(tester, 2500);

    for (final theme in ['light', 'dark']) {
      s.updateSettings((x) => x.theme = theme);
      await settle(tester, 600);
      Future<void> study(String id, String name, {bool flip = false, bool reveal = true, String? firstCard}) async {
        s.updateSettings((x) => x.reveal = flip ? RevealMode.flip : RevealMode.tap);
        final d = s.data.decks[ids[id]!]!;
        if (firstCard != null) d.stack = [firstCard, ...d.stack.where((c) => c != firstCard)];
        Shell.current!.study(d.id);
        await settle(tester, 1600);
        await shot(tester, 'pic-$theme-$name-front');
        if (reveal) {
          await tester.tap(find.text(flip ? 'Tap the card to flip it' : 'Tap to reveal'));
          await settle(tester, 1800);
          await shot(tester, 'pic-$theme-$name-back');
        }
        Shell.current!.goHome();
        await settle(tester, 900);
      }

      if (ids.containsKey('flags-africa')) {
        await study('flags-africa', 'flag', flip: true);
        final rev = s.data.cardsOf(s.data.decks[ids['flags-africa']!]!).firstWhere((c) => c.isReverse);
        await study('flags-africa', 'flag-reverse', firstCard: rev.id);
      }
      if (ids.containsKey('onepiece-characters')) await study('onepiece-characters', 'character');
      if (ids.containsKey('onepiece-powers')) await study('onepiece-powers', 'power', flip: true);
      if (ids.containsKey('car-brands')) {
        await study('car-brands', 'logo', flip: true);
        final rev = s.data.cardsOf(s.data.decks[ids['car-brands']!]!).firstWhere((c) => c.isReverse);
        await study('car-brands', 'logo-reverse', firstCard: rev.id);
      }
      await study('own', 'canvas');
    }

    // The layout editor, structured then free canvas (light).
    s.updateSettings((x) => x.theme = 'light');
    await settle(tester, 600);
    final nav = Navigator.of(tester.element(find.byType(Shell)), rootNavigator: true);
    final main = TextEditingController(text: 'Which country is this?');
    final example = TextEditingController(), hook = TextEditingController();
    final sample = SideLayout.forPicture(Tpl.above, back: false, src: 'asset:assets/content/img/flags-asia/np.png', aspect: 0.82, contain: true, alpha: true);
    showLayoutEditor(nav.context, back: false, initial: sample, main: main, example: example, hook: hook, label: 'flag');
    await settle(tester, 1200);
    await shot(tester, 'pic-editor-structured');
    await tester.tap(find.text('Free canvas'));
    await settle(tester, 700);
    await tester.tap(find.text('+ Text'));
    await settle(tester, 600);
    await shot(tester, 'pic-editor-canvas-text');
    await tester.tap(find.text('Picture 1').first);
    await settle(tester, 600);
    await shot(tester, 'pic-editor-canvas-picture');
    await tester.tap(find.text('Crop'));
    await settle(tester, 500);
    await tester.drag(find.byType(LayoutFace), const Offset(30, 20));
    await settle(tester, 400);
    await shot(tester, 'pic-editor-crop');
    nav.pop();
    await settle(tester, 800);

    // The card form with its two sides, and Settings › blur.
    showEditor(nav.context, deckId: ids['own']);
    await settle(tester, 1200);
    await shot(tester, 'pic-card-form');
    nav.pop();
    await settle(tester, 800);
    nav.push(SettingsScreen.route());
    await settle(tester, 1200);
    await shot(tester, 'pic-settings');
    s.updateSettings((x) => x.theme = 'dark');
    await settle(tester, 600);
    await shot(tester, 'pic-settings-dark');
    debugDisableShadows = true;
  });
}
