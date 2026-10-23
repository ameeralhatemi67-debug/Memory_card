import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memory_card/app.dart';
import 'package:memory_card/data/card_layout.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/data/store_scope.dart';
import 'package:memory_card/features/layout/layout_editor.dart';
import 'package:memory_card/features/layout/layout_face.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';

/// The study screen with picture cards, and the layout editor, on a phone-sized surface.
void main() {
  late Directory tmp;
  late AppStore store;

  // One store for the whole file (Hive keeps its boxes open between tests).
  setUpAll(() async {
    T.googleFonts = false;
    tmp = Directory.systemTemp.createTempSync('mc_layout_ui_');
    store = await AppStore.open(path: tmp.path);
  });

  String writePng(String name, {int w = 120, int h = 80, bool transparent = false}) {
    final im = img.Image(width: w, height: h, numChannels: 4);
    for (final p in im) {
      final inside = p.x > w ~/ 4 && p.x < w * 3 ~/ 4 && p.y > h ~/ 4 && p.y < h * 3 ~/ 4;
      if (transparent && !inside) {
        p.setRgba(0, 0, 0, 0);
      } else {
        p.setRgba(40 + p.x % 200, 90, 160, 255);
      }
    }
    final f = File('${tmp.path}/$name')..writeAsBytesSync(img.encodePng(im));
    return f.path;
  }

  group('on screen', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<void> settle(WidgetTester tester, [int ms = 900]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<String> studyDeck(RevealMode mode) async {
      final f = store.createFolder('Pictures');
      final d = store.createDeck(name: 'Faces', folderId: f.id);
      store.addCard(
        d.id,
        CardDraft(
          front: 'Who is this?',
          back: 'Ada Lovelace',
          hook: 'First programmer',
          frontLayout: SideLayout.forPicture(Tpl.above, back: false, src: writePng('front.png', w: 90, h: 120)),
          backLayout: SideLayout.forPicture(Tpl.full, back: true, src: writePng('back.png', w: 90, h: 120), blur: true),
        ),
      );
      store
        ..setOnboarded()
        ..updateSettings((s) => s.reveal = mode);
      return d.id;
    }

    Future<void> openStudy(WidgetTester tester, String deckId) async {
      await tester.pumpWidget(MemoryCardApp(store: store));
      await settle(tester);
      final shell = tester.state<ShellState>(find.byType(Shell));
      shell.study(deckId);
      await settle(tester, 1500);
    }

    Future<void> finish(WidgetTester tester) async {
      Toaster.i.hide();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }

    testWidgets('tap mode: the answer picture replaces the front on reveal, with a peek before', (tester) async {
      phone(tester);
      final deckId = await studyDeck(RevealMode.tap);
      await openStudy(tester, deckId);
      expect(find.byType(LayoutFace), findsWidgets);
      expect(find.text('Tap to reveal'), findsOneWidget);
      expect(find.byType(PictureView), findsWidgets);
      expect(find.text('ANSWER'), findsNothing);

      await tester.tap(find.text('Tap to reveal'));
      await settle(tester, 900);
      expect(find.text('ANSWER'), findsOneWidget);
      expect(find.text('Tap to reveal'), findsNothing);
      await finish(tester);
    });

    testWidgets('flip mode: the back face carries the picture', (tester) async {
      phone(tester);
      final deckId = await studyDeck(RevealMode.flip);
      await openStudy(tester, deckId);
      expect(find.text('Tap the card to flip it'), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byType(LayoutFace).first));
      await settle(tester, 1200);
      expect(find.text('ANSWER'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('the layout editor: free canvas, add text, drag it, Done returns it', (tester) async {
      phone(tester);
      LayoutResult? result;
      final main = TextEditingController(text: 'What is this?');
      final example = TextEditingController(), hook = TextEditingController();
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          theme: Mc.theme(Mc.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => result = await showLayoutEditor(context, back: false, initial: null, main: main, example: example, hook: hook, label: 'card'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester, 1000);
      expect(find.text('Front side'), findsOneWidget);
      expect(find.text('Add a picture'), findsOneWidget);

      await tester.tap(find.text('Free canvas'));
      await settle(tester, 500);
      await tester.tap(find.text('+ Text'));
      await settle(tester, 400);
      expect(find.text('Edit the words'), findsOneWidget);

      final face = find.byType(LayoutFace);
      final before = tester.getCenter(face);
      await tester.dragFrom(before, const Offset(0, 70));
      await settle(tester, 400);

      await tester.tap(find.text('Done'));
      await settle(tester, 800);
      expect(result, isNotNull);
      final layout = result!.layout!;
      expect(layout.mode, LayoutMode.canvas);
      final text = layout.texts.firstWhere((t) => t.isCustom);
      expect(text.y, greaterThan(0.42), reason: 'dragged downwards');
      expect(text.y + text.h, lessThanOrEqualTo(1.0001));
      await finish(tester);
    });

    testWidgets('the layout editor: dragging inside a picture crops it, the slider zooms it', (tester) async {
      phone(tester);
      LayoutResult? result;
      final main = TextEditingController(text: 'Pan me');
      final example = TextEditingController(), hook = TextEditingController();
      final start = SideLayout.forPicture(Tpl.above, back: false, src: writePng('wide.png', w: 200, h: 100), aspect: 2);
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          theme: Mc.theme(Mc.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => result = await showLayoutEditor(context, back: false, initial: start, main: main, example: example, hook: hook, label: 'card'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester, 1000);
      final face = find.byType(LayoutFace);
      final origin = tester.getTopLeft(face);
      final size = tester.getSize(face);
      final onPicture = origin + Offset(size.width * 0.5, size.height * 0.325);
      await tester.dragFrom(onPicture, const Offset(-40, 0));
      await settle(tester, 400);
      await tester.drag(find.byType(Slider), const Offset(60, 0));
      await settle(tester, 400);
      await tester.tap(find.text('Done'));
      await settle(tester, 800);
      final pic = result!.layout!.firstImage!;
      expect(pic.panX, greaterThan(0.8), reason: 'the picture moved behind its frame');
      expect(pic.zoom, greaterThan(1.0));
      expect(pic.y, closeTo(0.115, 0.001), reason: 'the frame itself did not move');
      await finish(tester);
    });
  });
}
