// ignore_for_file: use_build_context_synchronously, invalid_use_of_visible_for_testing_member
import 'dart:async';
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
import 'package:memory_card/features/account/sign_in_sheet.dart';
import 'package:memory_card/features/editor/editor_sheet.dart';
import 'package:memory_card/features/layout/layout_editor.dart';
import 'package:memory_card/features/media/voice_sheet.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/services/account.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/textures.dart';
import 'package:memory_card/ui/theme.dart';

import '../test/account_test.dart' show FakeAuth;

/// Renders voices, videos, hints and the sign-in screens to build/gallery/med-*.png:
///   flutter test test_gallery/media_gallery_test.dart
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

  /// Pictures decode on the real event loop, so give them time before the shot.
  Future<void> shot(WidgetTester tester, String name) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() async {
      final b = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await b.toImage(pixelRatio: 1.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  late String deckId, hintCard, soundCard;
  late CardItem editCard;

  Future<AppStore> openStore(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('mc_media_gallery_');
    return (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      final f = s.createFolder('My decks');
      final d = s.createDeck(name: 'Nature clips', folderId: f.id);
      deckId = d.id;
      // Bundled pictures stand in for video stills (files do not decode on the test clock).
      const poster = 'asset:assets/content/img/football-stadiums/anfield.jpg';
      const hint = 'asset:assets/content/img/paintings-details/american-gothic.jpg';
      // 1 · a hint picture kept back on the front
      final hintLayout = SideLayout.template(Tpl.below, back: false, image: ImageEl(x: 0, y: 0, w: 1, h: 1, src: hint, aspect: 0.82, hint: true));
      final c1 = s.addCard(d.id, CardDraft(front: 'Which bird sings at dusk?', back: 'Nightingale', frontLayout: hintLayout));
      hintCard = c1.id;
      // 2 · a question that is only a sound
      soundCard = s.addCard(d.id, CardDraft(front: '', back: 'Blackbird', soundF: CardSound(src: '${dir.path}/song.m4a', ms: 4300, recorded: true))).id;
      // 3 · a question video, an answer video and an answer recording
      editCard = s.addCard(
        d.id,
        CardDraft(
          front: 'What makes this wave break?',
          back: 'The seabed rises',
          frontLayout: SideLayout.forPicture(Tpl.above, back: false, src: poster, aspect: 16 / 9, video: '${dir.path}/wave.mp4', videoMs: 12400),
          backLayout: SideLayout.forPicture(Tpl.above, back: true, src: 'asset:assets/content/img/football-stadiums/camp-nou.jpg', aspect: 16 / 9, blur: true,
              video: '${dir.path}/answer.mp4', videoMs: 8200),
          soundB: CardSound(src: '${dir.path}/answer.m4a', ms: 2600, recorded: true),
        ),
      );
      // Keep the hint card on top of the stack.
      d.stack = [c1.id, ...d.stack.where((x) => x != c1.id)];
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe', 'deck-swipe']) {
        s.markCoach(id);
      }
      s.touchFolder(f.id);
      await Future.wait([for (final d in Textures.all) Textures.i.load(d.id)]);
      return s;
    }))!;
  }

  testWidgets('media and accounts gallery', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    final fake = FakeAuth()..served = const AuthProviders(email: true, google: true, apple: false);
    Account.i.useBackend(fake);
    await Account.i.init();
    final store = await openStore(tester);
    store.updateSettings((s) => s.autoPlay = false);
    Account.i.attach(store);
    await tester.pumpWidget(RepaintBoundary(key: shotKey, child: MemoryCardApp(store: store)));
    await advance(tester, 1.2);
    BuildContext ctx() => Shell.current!.context;

    for (final theme in ['light', 'dark']) {
      store.updateSettings((x) => x.theme = theme);
      await advance(tester, 0.6);

      // Study: the hint card, closed then open; then the sound-only and video cards.
      final d = store.data.decks[deckId]!;
      d.stack = [hintCard, soundCard, editCard.id];
      Shell.current!.study(deckId);
      await advance(tester, 1.4);
      await shot(tester, 'med-$theme-1-hint-closed');
      await tester.tap(find.text('Hint · tap to see'), warnIfMissed: false);
      await advance(tester, 0.8);
      await shot(tester, 'med-$theme-2-hint-open');
      await tester.tap(find.text('Tap to reveal'));
      await advance(tester, 0.8);
      await tester.fling(find.text('Nightingale'), const Offset(420, 0), 2400);
      await advance(tester, 1.6);
      await shot(tester, 'med-$theme-3-sound-question');
      await tester.tap(find.text('Tap to reveal'));
      await advance(tester, 0.8);
      await tester.fling(find.text('Blackbird'), const Offset(420, 0), 2400);
      await advance(tester, 1.6);
      await shot(tester, 'med-$theme-4-video-question');
      await tester.tap(find.text('Tap to reveal'));
      await advance(tester, 0.3);
      await shot(tester, 'med-$theme-5-video-answer-sharpening');
      await advance(tester, 1.0);
      await shot(tester, 'med-$theme-6-video-answer');
      Shell.current!.goHome();
      await advance(tester, 1.0);

      // The editor: pictures, video and voice for each side.
      unawaited(showEditor(ctx(), editCardId: editCard.id));
      await advance(tester, 1.0);
      await tester.dragUntilVisible(find.text('Pictures, video & voice'), find.byType(Scrollable).last, const Offset(0, -200));
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -260));
      await advance(tester, 0.6);
      await shot(tester, 'med-$theme-7-editor');
      Navigator.of(ctx(), rootNavigator: true).pop();
      await advance(tester, 0.8);

      // The layout editor with the video selected.
      final layout = editCard.frontLayout!;
      unawaited(showLayoutEditor(ctx(),
          back: false,
          initial: layout,
          main: TextEditingController(text: editCard.front),
          example: TextEditingController(),
          hook: TextEditingController(),
          label: 'card'));
      await advance(tester, 1.0);
      await tester.tap(find.text('Free canvas'));
      await advance(tester, 0.4);
      await tester.tap(find.text('Video 1'));
      await advance(tester, 0.4);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
      await advance(tester, 0.5);
      await shot(tester, 'med-$theme-8-layout-video');
      await tester.tap(find.text('Done'));
      await advance(tester, 0.8);

      // The voice sheet, with the answer's recording on it.
      unawaited(showVoiceSheet(ctx(), back: true, current: editCard.soundB));
      await advance(tester, 1.0);
      await shot(tester, 'med-$theme-9-voice');
      Navigator.of(ctx(), rootNavigator: true).pop();
      await advance(tester, 0.8);

      // Accounts: sign in, create, check your email, then signed in.
      unawaited(showSignInSheet(ctx()));
      await advance(tester, 1.2);
      await shot(tester, 'med-$theme-10-sign-in');
      await tester.tap(find.text('Continue with Apple'));
      await advance(tester, 0.5);
      await shot(tester, 'med-$theme-11-apple-off');
      await tester.tap(find.text('New here? Create an account'));
      await advance(tester, 0.6);
      await tester.enterText(find.byType(TextField).at(0), 'Rosalind');
      await tester.enterText(find.byType(TextField).at(1), 'rosalind.$theme@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'double-helix');
      FocusManager.instance.primaryFocus?.unfocus();
      await advance(tester, 0.4);
      await shot(tester, 'med-$theme-12-create');
      await tester.tap(find.text('Create my account'));
      await advance(tester, 0.8);
      await shot(tester, 'med-$theme-13-confirm');
      await tester.enterText(find.byType(TextField).first, '424242');
      await advance(tester, 0.2);
      await tester.tap(find.text('Confirm the code'));
      await advance(tester, 1.2);
      Shell.current!.openAccount();
      await advance(tester, 1.2);
      await shot(tester, 'med-$theme-14-account-tab');
      await tester.tap(find.text('Signed in'));
      await advance(tester, 1.0);
      await shot(tester, 'med-$theme-15-account-sheet');
      await tester.tap(find.text('Sign out'));
      await advance(tester, 1.2);
      store.updateSettings((x) => x.name = '');
      Shell.current!.goHome();
      await advance(tester, 0.8);
    }

    debugDisableShadows = true;
    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
