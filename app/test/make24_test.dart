import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/catalog.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/engine/assessor.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/features/study/card_face.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';

/// Make 24: cards with several right answers (ways). A right swipe needs a way you tick as found, and when the
/// card comes back only a way not found before counts; once all are found they all count again.
void main() {
  late Directory tmp;
  late AppStore store;

  // One store for the whole file (Hive keeps its boxes open between tests).
  setUpAll(() async {
    T.googleFonts = false;
    tmp = Directory.systemTemp.createTempSync('mc_make24_');
    store = await AppStore.open(path: tmp.path);
    store.setOnboarded();
  });

  /// A card's ways evaluate to 24 and use its four numbers once each (read the usual way).
  Fraction value(String text) {
    final tokens = RegExp(r'\d+|[()+−×÷]').allMatches(text).map((m) => m[0]!).toList();
    var i = 0;
    late Fraction Function() sum;
    Fraction atom() {
      final t = tokens[i++];
      if (t == '(') {
        final v = sum();
        i++; // ')'
        return v;
      }
      return Fraction(int.parse(t), 1);
    }

    Fraction product() {
      var v = atom();
      while (i < tokens.length && (tokens[i] == '×' || tokens[i] == '÷')) {
        final op = tokens[i++];
        final r = atom();
        v = op == '×' ? v * r : v / r;
      }
      return v;
    }

    sum = () {
      var v = product();
      while (i < tokens.length && (tokens[i] == '+' || tokens[i] == '−')) {
        final op = tokens[i++];
        final r = product();
        v = op == '+' ? v + r : v - r;
      }
      return v;
    };
    return sum();
  }

  group('the decks', () {
    test('19 decks of 40 (the last 36): every set that can make 24 from 1 to 11, every way right', () {
      final decks = store.catalog.decks.where((d) => d.category == 'math').toList();
      expect(decks.length, 19);
      expect(decks.map((d) => d.name).take(3), ['Make 24 · Level 1', 'Make 24 · Level 2', 'Make 24 · Level 3']);
      expect([for (final d in decks) d.cards.length].fold(0, (a, b) => a + b), 756);
      final sets = <String>{};
      for (final d in decks) {
        expect(d.kind, 'make24');
        expect(d.skin, isNotNull, reason: '${d.id} has its own cover');
        expect(d.cards.length, d == decks.last ? 36 : 40);
        for (final c in d.cards) {
          final nums = c.front.split(' ').map(int.parse).toList()..sort();
          expect(nums.length, 4);
          expect(nums.every((n) => n >= 1 && n <= 11), isTrue);
          expect(sets.add(nums.join(',')), isTrue, reason: 'each set once');
          expect(c.ways, isNotEmpty);
          expect(c.back, c.ways.first);
          expect(c.ways.toSet().length, c.ways.length);
          for (final w in c.ways) {
            expect(value(w), Fraction(24, 1), reason: '${c.front}: $w');
            final used = RegExp(r'\d+').allMatches(w).map((m) => int.parse(m[0]!)).toList()..sort();
            expect(used, nums, reason: '${c.front}: $w');
          }
        }
      }
      // Some of the owner's examples.
      final byFront = {for (final d in decks) for (final c in d.cards) c.front: c};
      expect(byFront['4 5 6 7']!.ways, contains('(7 + 5 − 6) × 4'));
      expect(byFront['3 4 6 8']!.ways, contains('(8 − 6) × 4 × 3'));
      expect(byFront['3 3 8 8']!.ways, ['8 ÷ (3 − 8 ÷ 3)']);
    });

    test('names sort with their numbers', () {
      expect(Catalog.compareNames('Make 24 · Level 2', 'Make 24 · Level 10'), lessThan(0));
      expect(Catalog.compareNames('Anime', 'Make 24 · Level 1'), lessThan(0));
    });
  });

  group('finding ways', () {
    ReviewSignals signals() => const ReviewSignals(thinkMs: 4000, verifyMs: 900, dragMs: 300);

    test('a new way each turn; the round starts over once all are found; undo puts it back', () {
      final f = store.createFolder('Ways');
      final d = store.createDeck(name: 'Ways', folderId: f.id, kind: 'make24');
      final c = store.addCard(d.id, const CardDraft(front: '3 4 6 8', back: 'a', ways: ['a', 'b', 'c']));
      expect(c.ways, ['a', 'b', 'c']);
      expect(c.earns({}), isFalse);
      expect(c.earns({0}), isTrue);

      var out = store.swipe(deckId: d.id, cardId: c.id, recalled: true, signals: signals(), ways: {0});
      expect(c.found, [0]);
      expect(out.allWaysFound, isFalse);
      expect(c.earns({0}), isFalse, reason: 'found before');
      expect(c.earns({0, 2}), isTrue);

      // A left swipe finds nothing.
      store.swipe(deckId: d.id, cardId: c.id, recalled: false, signals: signals(), ways: {1});
      expect(c.found, [0]);

      final snap = store.snapshot(d.id, c.id);
      out = store.swipe(deckId: d.id, cardId: c.id, recalled: true, signals: signals(), ways: {1}, snapshot: snap);
      expect(c.found, [0, 1]);
      store.restore(snap);
      expect(store.data.cards[c.id]!.found, [0], reason: 'undo');

      final card = store.data.cards[c.id]!;
      store.swipe(deckId: d.id, cardId: c.id, recalled: true, signals: signals(), ways: {1});
      out = store.swipe(deckId: d.id, cardId: c.id, recalled: true, signals: signals(), ways: {0, 2});
      expect(out.allWaysFound, isTrue);
      expect(card.found, isEmpty, reason: 'all found: they all count again');
      expect(CardItem.fromJson(card.toJson()).ways, ['a', 'b', 'c']);
    });

    test('a shop deck brings its ways', () {
      final d = store.addCatalogDeck('make24-01', store.createFolder('Make 24').id);
      final cards = [for (final id in d.cardIds) store.data.cards[id]!];
      expect(cards.length, 40);
      expect(cards.every((c) => c.hasWays && c.back == c.ways.first), isTrue);
      expect(store.skinOf(d), isNotNull);
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

    Future<void> finish(WidgetTester tester) async {
      Toaster.i.hide();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }

    /// A Make 24 deck whose top card is 3 4 6 8, with [found] already found on earlier turns.
    String deckWith(List<int> found) {
      final f = store.createFolder('Play');
      final d = store.createDeck(name: 'Make 24 · Play', folderId: f.id, kind: 'make24');
      final cd = store.catalog.decks.expand((x) => x.cards).firstWhere((c) => c.front == '3 4 6 8');
      final c = store.addCard(d.id, CardDraft(front: cd.front, back: cd.back, label: 'make 24', ways: cd.ways));
      c.found.addAll(found);
      return d.id;
    }

    Future<void> openStudy(WidgetTester tester, String deckId) async {
      await tester.pumpWidget(MemoryCardApp(store: store));
      await settle(tester);
      tester.state<ShellState>(find.byType(Shell)).study(deckId);
      await settle(tester, 1500);
    }

    Future<void> swipeRight(WidgetTester tester) async {
      await tester.dragFrom(tester.getCenter(find.byType(NumberTiles)), const Offset(300, 0));
      await settle(tester, 1200);
    }

    testWidgets('tiles, then the ways; a right swipe needs a ticked way', (tester) async {
      phone(tester);
      store.updateSettings((s) => s
        ..reveal = RevealMode.tap
        ..revealScope = RevealScope.all);
      final deckId = deckWith([]);
      final card = store.data.cards[store.data.decks[deckId]!.cardIds.single]!;
      await openStudy(tester, deckId);
      expect(find.byType(NumberTiles), findsOneWidget);
      expect(find.text('${card.ways.length} ways · use each number once'), findsOneWidget);

      await tester.tap(find.text('Tap to reveal'));
      await settle(tester, 600);
      expect(find.text('TICK THE WAYS YOU FOUND'), findsOneWidget);
      expect(find.text(card.ways.first), findsOneWidget);

      await swipeRight(tester);
      expect(find.text('Tick the way you found first'), findsOneWidget);
      expect(card.reps, 0);

      await tester.tap(find.text(card.ways[1]));
      await tester.pump(const Duration(milliseconds: 300));
      await swipeRight(tester);
      expect(card.reps, 1);
      expect(card.found, [1]);
      await finish(tester);
    });

    testWidgets('when it comes back, only a way not found before counts', (tester) async {
      phone(tester);
      store.updateSettings((s) => s.reveal = RevealMode.tap);
      final deckId = deckWith([0]);
      final card = store.data.cards[store.data.decks[deckId]!.cardIds.single]!;
      await openStudy(tester, deckId);
      expect(find.text('You found 1 of ${card.ways.length} · find a new one'), findsOneWidget);
      await tester.tap(find.text('Tap to reveal'));
      await settle(tester, 600);
      expect(find.text('FOUND'), findsOneWidget);

      await tester.tap(find.text(card.ways[0]));
      await tester.pump(const Duration(milliseconds: 300));
      await swipeRight(tester);
      expect(find.text('Found before · find a new way, or swipe left'), findsOneWidget);
      expect(card.reps, 0);

      await tester.tap(find.text(card.ways[2]));
      await tester.pump(const Duration(milliseconds: 300));
      await swipeRight(tester);
      expect(card.reps, 1);
      expect(card.found, [0, 2]);
      await finish(tester);
    });

    testWidgets('scratch mode: the ways wait under the foil, then tick as usual', (tester) async {
      phone(tester);
      store.updateSettings((s) => s.reveal = RevealMode.scratch);
      final deckId = deckWith([]);
      final card = store.data.cards[store.data.decks[deckId]!.cardIds.single]!;
      await openStudy(tester, deckId);
      expect(find.bySemanticsLabel('Scratch to reveal the answer'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester, 1500);
      expect(find.bySemanticsLabel('Scratch to reveal the answer'), findsNothing);
      await tester.tap(find.text(card.ways[0]));
      await tester.pump(const Duration(milliseconds: 300));
      await swipeRight(tester);
      expect(card.found, [0]);
      store.updateSettings((s) => s.reveal = RevealMode.tap);
      await finish(tester);
    });

    testWidgets('flip mode: the back face lists the ways to tick', (tester) async {
      phone(tester);
      store.updateSettings((s) => s.reveal = RevealMode.flip);
      final deckId = deckWith([]);
      await openStudy(tester, deckId);
      await tester.tapAt(tester.getCenter(find.byType(NumberTiles)));
      await settle(tester, 1200);
      expect(find.text('WAYS TO MAKE 24'), findsOneWidget);
      expect(find.text('TICK THE WAYS YOU FOUND'), findsOneWidget);
      store.updateSettings((s) => s.reveal = RevealMode.tap);
      await finish(tester);
    });
  });
}

/// Exact fractions for checking the printed ways.
class Fraction {
  Fraction(int n, int d)
      : n = (d < 0 ? -n : n) ~/ _g(n.abs(), d.abs()),
        d = d.abs() ~/ _g(n.abs(), d.abs());
  final int n, d;
  static int _g(int a, int b) => b == 0 ? (a == 0 ? 1 : a) : _g(b, a % b);
  Fraction operator +(Fraction o) => Fraction(n * o.d + o.n * d, d * o.d);
  Fraction operator -(Fraction o) => Fraction(n * o.d - o.n * d, d * o.d);
  Fraction operator *(Fraction o) => Fraction(n * o.n, d * o.d);
  Fraction operator /(Fraction o) => Fraction(n * o.d, d * o.n);
  @override
  bool operator ==(Object o) => o is Fraction && o.n == n && o.d == d;
  @override
  int get hashCode => Object.hash(n, d);
  @override
  String toString() => '$n/$d';
}
