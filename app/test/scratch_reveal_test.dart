import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/catalog.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/features/study/scratch_foil.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';

/// Scratch to reveal (silver foil) and the reveal each deck gets: Settings' choice for all decks, for the
/// decks you pick, or each deck's own default.
void main() {
  late Directory tmp;
  late AppStore store;

  // One store for the whole file (Hive keeps its boxes open between tests).
  setUpAll(() async {
    T.googleFonts = false;
    tmp = Directory.systemTemp.createTempSync('mc_scratch_');
    store = await AppStore.open(path: tmp.path);
    store.setOnboarded();
  });

  group('which reveal a deck gets', () {
    test('all decks: the setting wins over every default', () {
      final f = store.createFolder('Scope');
      final own = store.createDeck(name: 'Own', folderId: f.id, reveal: RevealMode.flip);
      final plain = store.createDeck(name: 'Plain', folderId: f.id);
      store.updateSettings((s) => s
        ..reveal = RevealMode.scratch
        ..revealScope = RevealScope.all);
      expect(store.revealFor(own), RevealMode.scratch);
      expect(store.revealFor(plain), RevealMode.scratch);
      expect(store.revealFor(null), RevealMode.scratch);
    });

    test('decks I pick: ticked decks use the setting, the rest their own (or the setting without one)', () {
      final f = store.createFolder('Picked');
      final ticked = store.createDeck(name: 'Ticked', folderId: f.id, reveal: RevealMode.flip);
      final free = store.createDeck(name: 'Free', folderId: f.id, reveal: RevealMode.front);
      final plain = store.createDeck(name: 'Plain', folderId: f.id);
      store.updateSettings((s) => s
        ..reveal = RevealMode.scratch
        ..revealScope = RevealScope.picked
        ..revealDecks = {ticked.id});
      expect(store.revealFor(ticked), RevealMode.scratch);
      expect(store.revealFor(free), RevealMode.front);
      expect(store.revealFor(plain), RevealMode.scratch);
    });

    test('deck defaults: each deck its own, else the setting; a saved look keeps or changes it', () {
      final f = store.createFolder('Defaults');
      final d = store.createDeck(name: 'Mine', folderId: f.id, reveal: RevealMode.icon);
      final plain = store.createDeck(name: 'Plain', folderId: f.id);
      store.updateSettings((s) => s
        ..reveal = RevealMode.tap
        ..revealScope = RevealScope.deck);
      expect(store.revealFor(d), RevealMode.icon);
      expect(store.revealFor(plain), RevealMode.tap);
      store.saveLook(d.id, skin: null);
      expect(d.reveal, RevealMode.icon, reason: 'left out, the reveal stays');
      store.saveLook(d.id, skin: null, reveal: (null,));
      expect(store.revealFor(d), RevealMode.tap);
    });

    test('a shop deck brings its own default from the catalogue', () {
      final cd = CatalogDeck.fromJson({'id': 'x-scratch', 'name': 'X', 'reveal': 'scratch', 'cards': []});
      expect(cd.reveal, RevealMode.scratch);
      expect(CatalogDeck.fromJson({'id': 'x', 'name': 'X', 'reveal': 'nope', 'cards': []}).reveal, isNull);
    });

    test('settings and decks keep it all through JSON', () {
      final s = Settings()
        ..reveal = RevealMode.scratch
        ..revealScope = RevealScope.picked
        ..revealDecks = {'a', 'b'}
        ..scratchBuzz = 0.35;
      final back = Settings.fromJson(s.toJson());
      expect(back.reveal, RevealMode.scratch);
      expect(back.revealScope, RevealScope.picked);
      expect(back.revealDecks, {'a', 'b'});
      expect(back.scratchBuzz, 0.35);
      final old = Settings.fromJson({'reveal': 'flip'});
      expect(old.revealScope, RevealScope.all, reason: 'an older save keeps one reveal for every deck');
      expect(old.scratchBuzz, 0.6);
      final d = Deck(id: 'd1', name: 'D', created: 0, reveal: RevealMode.front);
      expect(Deck.fromJson(d.toJson()).reveal, RevealMode.front);
      expect(Deck.fromJson(Deck(id: 'd2', name: 'D', created: 0).toJson()).reveal, isNull);
    });
  });

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

    String textDeck(String name, {RevealMode? reveal}) {
      final f = store.createFolder(name);
      final d = store.createDeck(name: name, folderId: f.id, reveal: reveal);
      for (final (q, a) in [('la mela', 'the apple'), ('il pane', 'the bread'), ('la casa', 'the house')]) {
        store.addCard(d.id, CardDraft(front: q, back: a, hook: 'A hook to read'));
      }
      return d.id;
    }

    Future<void> openStudy(WidgetTester tester, String deckId) async {
      await tester.pumpWidget(MemoryCardApp(store: store));
      await settle(tester);
      tester.state<ShellState>(find.byType(Shell)).study(deckId);
      await settle(tester, 1500);
    }

    Future<void> finish(WidgetTester tester) async {
      Toaster.i.hide();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }

    /// Back-and-forth sweeps down the panel, like a thumb on a ticket.
    Future<void> scratch(WidgetTester tester, {int rows = 5}) async {
      final r = tester.getRect(find.byType(ScratchFoil));
      final g = await tester.startGesture(Offset(r.left + 8, r.top + 12));
      for (var row = 0; row < rows; row++) {
        final y = r.top + 12 + row * (r.height - 24) / 4;
        final from = row.isEven ? r.left + 8 : r.right - 8, to = row.isEven ? r.right - 8 : r.left + 8;
        await g.moveTo(Offset(from, y));
        for (var i = 1; i <= 16; i++) {
          await g.moveTo(Offset(from + (to - from) * i / 16, y));
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      await g.up();
    }

    testWidgets('scratching the foil reveals the answer; flakes fall, then the card swipes', (tester) async {
      phone(tester);
      store.updateSettings((s) => s
        ..reveal = RevealMode.scratch
        ..revealScope = RevealScope.all);
      final deckId = textDeck('Italian');
      await openStudy(tester, deckId);
      expect(find.byType(ScratchFoil), findsOneWidget);
      expect(find.bySemanticsLabel('Scratch to reveal the answer'), findsOneWidget);
      final before = store.data.decks[deckId]!.reviews;

      // A swipe before scratching is turned back.
      final card = tester.getCenter(find.text('la mela'));
      await tester.dragFrom(card, const Offset(260, 0));
      await settle(tester, 400);
      expect(find.text('Scratch the answer to check first'), findsOneWidget);
      expect(store.data.decks[deckId]!.reviews, before);

      // A drag on the panel scratches instead of moving the card.
      await scratch(tester, rows: 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('Scratch to reveal the answer'), findsOneWidget, reason: 'one sweep is not enough');
      await scratch(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('Scratch to reveal the answer'), findsNothing);
      await settle(tester, 1500);

      // Revealed: the card can be swiped away now.
      await tester.dragFrom(tester.getCenter(find.text('la mela')), const Offset(300, 0));
      await settle(tester, 1200);
      expect(store.data.decks[deckId]!.reviews, before + 1);
      await finish(tester);
    });

    testWidgets('the keyboard reveals at once, and reduced motion fades the foil', (tester) async {
      phone(tester);
      store.updateSettings((s) => s
        ..reveal = RevealMode.scratch
        ..revealScope = RevealScope.all
        ..reducedMotion = true);
      addTearDown(() => store.updateSettings((s) => s.reducedMotion = false));
      await openStudy(tester, textDeck('Keys'));
      expect(find.bySemanticsLabel('Scratch to reveal the answer'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester, 600);
      expect(find.bySemanticsLabel('Scratch to reveal the answer'), findsNothing);
      await finish(tester);
    });

    testWidgets("deck defaults: a deck's own scratch, and the setting for one without", (tester) async {
      phone(tester);
      store.updateSettings((s) => s
        ..reveal = RevealMode.tap
        ..revealScope = RevealScope.deck);
      await openStudy(tester, textDeck('Scratchy', reveal: RevealMode.scratch));
      expect(find.byType(ScratchFoil), findsOneWidget);
      expect(find.text('Tap to reveal'), findsNothing);
      await finish(tester);

      await openStudy(tester, textDeck('Tappy'));
      expect(find.byType(ScratchFoil), findsNothing);
      expect(find.text('Tap to reveal'), findsOneWidget);
      await finish(tester);
    });
  });
}
