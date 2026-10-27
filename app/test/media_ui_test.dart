import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memory_card/data/card_layout.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/data/store_scope.dart';
import 'package:memory_card/features/editor/editor_sheet.dart';
import 'package:memory_card/features/study/study_screen.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';

/// Hints, sound-only questions and the editor's media controls, on the real screens.
void main() {
  setUpAll(() => T.googleFonts = false);

  Future<void> settle(WidgetTester tester, [int ms = 900]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<(AppStore, String)> openStore(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('mc_media_ui_');
    return (await tester.runAsync(() async {
      final s = await AppStore.open(path: dir.path);
      s.setOnboarded();
      for (final id in ['drawer', 'shop-hold', 'study-swipe', 'deck-swipe']) {
        s.markCoach(id);
      }
      final pic = img.Image(width: 160, height: 100);
      for (final p in pic) {
        p.setRgb(30 + p.x, 120, 200 - p.y);
      }
      final png = File('${dir.path}/hint.png')..writeAsBytesSync(img.encodePng(pic));
      return (s, png.path);
    }))!;
  }

  Future<void> finish(WidgetTester tester) async {
    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('a hint stays covered until tapped, and remembering with it is graded Hard', (tester) async {
    phone(tester);
    final (store, png) = await openStore(tester);
    final f = store.createFolder('Hints');
    final d = store.createDeck(name: 'Capitals', folderId: f.id);
    final hint = SideLayout(els: [
      TextEl(x: 0.07, y: 0.1, w: 0.86, h: 0.2, source: 'main'),
      ImageEl(x: 0.07, y: 0.35, w: 0.86, h: 0.3, src: png, aspect: 1.6, hint: true),
    ], tpl: Tpl.below);
    store.addCard(d.id, CardDraft(front: 'Capital of Peru?', back: 'Lima', frontLayout: hint));
    store.updateSettings((s) => s.autoPlay = false);

    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(theme: Mc.theme(Mc.light), home: Stack(children: [StudyScreen(deckId: d.id), const ToastHost(bottom: 40)])),
    ));
    await settle(tester, 1500);
    expect(find.text('Hint · tap to see'), findsOneWidget);

    await tester.tap(find.text('Hint · tap to see'), warnIfMissed: false); // the label itself lets taps through to the frame
    await settle(tester);
    expect(find.text('Hint · tap to see'), findsNothing, reason: 'the hint opened (and the card did not reveal)');
    expect(find.text('Tap to reveal'), findsOneWidget);

    await tester.tap(find.text('Tap to reveal'));
    await settle(tester);
    await tester.fling(find.text('Lima'), const Offset(420, 0), 2400);
    await settle(tester, 1200);
    final card = store.data.cardsOf(d).single;
    expect(card.reps, 1);
    expect(card.lastGrade, 2, reason: 'remembered with the hint');
    await finish(tester);
  });

  testWidgets('a question that is only a sound shows "Listen" and the sound button', (tester) async {
    phone(tester);
    final (store, _) = await openStore(tester);
    final f = store.createFolder('Sounds');
    final d = store.createDeck(name: 'Birdsong', folderId: f.id);
    store.addCard(d.id, CardDraft(front: '', back: 'Blackbird', soundF: CardSound(src: '/nowhere/song.m4a', ms: 3200, recorded: true)));
    store.updateSettings((s) => s.autoPlay = false);
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(theme: Mc.theme(Mc.light), home: Stack(children: [StudyScreen(deckId: d.id), const ToastHost(bottom: 40)])),
    ));
    await settle(tester, 1500);
    expect(find.text('Listen · 3.2 s'), findsOneWidget);
    expect(find.text('Hear it'), findsOneWidget, reason: 'a deck with no language still gets the button for its own sound');
    await tester.tap(find.text('Hear it'));
    await settle(tester, 300);
    expect(find.text('Playing…'), findsOneWidget);
    // No audio engine in tests: playing gives up and the button comes back.
    await settle(tester, 7000);
    expect(find.text('Hear it'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the editor offers a picture, a video and a voice for each side, and a side can be only a sound', (tester) async {
    phone(tester);
    final (store, _) = await openStore(tester);
    final f = store.createFolder('Edit');
    final d = store.createDeck(name: 'Voices', folderId: f.id);
    final c = store.addCard(d.id, CardDraft(front: '', back: 'Hello', soundF: CardSound(src: '/nowhere/hi.m4a', ms: 1500)));
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: Mc.theme(Mc.light),
        home: Stack(children: [
          Builder(builder: (context) => Center(child: TextButton(onPressed: () => showEditor(context, editCardId: c.id), child: const Text('edit')))),
          const ToastHost(bottom: 40),
        ]),
      ),
    ));
    await tester.tap(find.text('edit'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Pictures, video & voice'), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 300);
    expect(find.text('+ Video'), findsNWidgets(2));
    expect(find.text('Voice 0:02'), findsOneWidget, reason: 'the front has its sound');
    expect(find.text('+ Voice'), findsOneWidget, reason: 'the back has none');
    expect(find.textContaining('Text · sound 0:02'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(store.data.cards[c.id]!.soundF!.ms, 1500, reason: 'a front that is only a sound is a valid card');
    await finish(tester);
  });
}
