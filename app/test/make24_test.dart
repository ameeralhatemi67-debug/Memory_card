import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/catalog.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/engine/assessor.dart';
import 'package:memory_card/features/shell/shell.dart';
import 'package:memory_card/engine/make24.dart';
import 'package:memory_card/features/study/make_board.dart';
import 'package:memory_card/features/study/scratch_foil.dart';
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
    test('12 decks of 63: every set that can make 24 from 1 to 11, every way right', () {
      final decks = store.catalog.decks.where((d) => d.category == 'math').toList();
      expect(decks.length, 12);
      expect(decks.map((d) => d.name).take(3), ['Make 24 · Level 1', 'Make 24 · Level 2', 'Make 24 · Level 3']);
      expect([for (final d in decks) d.cards.length].fold(0, (a, b) => a + b), 756);
      final sets = <String>{};
      for (final d in decks) {
        expect(d.kind, 'make24');
        expect(d.skin, isNotNull, reason: '${d.id} has its own cover');
        expect(d.cards.length, 63);
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
      expect(cards.length, 63);
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

    /// A deck whose top card is 3 4 6 8, with [found] already found on earlier turns: a Make 24 deck, or
    /// ([kind] 'text') an ordinary deck holding the same card with several answers.
    String deckWith(List<int> found, {String kind = 'make24'}) {
      final f = store.createFolder('Play');
      final d = store.createDeck(name: 'Make 24 · Play', folderId: f.id, kind: kind);
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

    Future<void> swipe(WidgetTester tester, Finder from, {bool right = true}) async {
      await tester.dragFrom(tester.getCenter(from), Offset(right ? 300 : -300, 0));
      await settle(tester, 1200);
    }

    Finder tile(String v) => find.descendant(of: find.byType(MakeBoard), matching: find.text(v));

    /// Builds [way] on the board: each step picks a card, a sign and another card.
    Future<void> build(WidgetTester tester, String way) async {
      String? selected;
      Future<void> walk(Expr e) async {
        if (e.isNum) return;
        await walk(e.l!);
        await walk(e.r!);
        final a = '${e.l!.value}', b = '${e.r!.value}';
        if (selected != a) await tester.tap(tile(a).first);
        await tester.pump(const Duration(milliseconds: 120));
        await tester.tap(find.text(opSign(e.op!)));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.tap(tile(b).last);
        await tester.pump(const Duration(milliseconds: 400));
        selected = '${e.value}';
      }

      await walk(Expr.parse(way));
    }

    testWidgets('make 24: build a way on the card; a right swipe needs one', (tester) async {
      phone(tester);
      store.updateSettings((s) => s
        ..reveal = RevealMode.tap
        ..revealScope = RevealScope.all);
      final deckId = deckWith([]);
      final card = store.data.cards[store.data.decks[deckId]!.cardIds.single]!;
      await openStudy(tester, deckId);
      expect(find.byType(MakeBoard), findsOneWidget);
      expect(find.text('${card.ways.length} ways · each number once'), findsOneWidget);
      expect(find.text(card.ways.first), findsNothing, reason: 'no answer shows');

      await swipe(tester, find.byType(MakeBoard));
      expect(find.text('Build a way first, or tap Stuck?'), findsOneWidget);
      expect(card.reps, 0);

      // A move below zero is refused; a total that is not 24 says so.
      await tester.tap(tile('3'));
      await tester.tap(find.text(opSign('-')));
      await tester.tap(tile('8'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('That goes below zero. Take the bigger number first.'), findsOneWidget);
      await build(tester, '3 + 4 + 6 + 8');
      expect(find.text('That makes 21, not 24. Undo a step, or start over.'), findsOneWidget);
      await tester.tap(find.text('Start over'));
      await tester.pump(const Duration(milliseconds: 300));

      await build(tester, card.ways[1]);
      expect(find.textContaining('NEW WAY · 1 OF ${card.ways.length} FOUND'), findsOneWidget);
      expect(find.text(card.ways[1]), findsOneWidget);
      await swipe(tester, find.byType(MakeBoard));
      expect(card.reps, 1);
      expect(card.found, [1]);
      await finish(tester);
    });

    testWidgets('make 24: when it comes back, a way found before does not count', (tester) async {
      phone(tester);
      final deckId = deckWith([0]);
      final card = store.data.cards[store.data.decks[deckId]!.cardIds.single]!;
      await openStudy(tester, deckId);
      expect(find.text('1 of ${card.ways.length} found · build a new one'), findsOneWidget);

      await build(tester, card.ways[0]);
      expect(find.text('FOUND ON AN EARLIER TURN · BUILD ANOTHER'), findsOneWidget);
      await swipe(tester, find.byType(MakeBoard));
      expect(find.text('Build a new way first, or swipe left'), findsOneWidget);
      expect(card.reps, 0);

      await tester.tap(find.text('Another'));
      await tester.pump(const Duration(milliseconds: 300));
      await build(tester, card.ways[2]);
      await swipe(tester, find.byType(MakeBoard));
      expect(card.reps, 1);
      expect(card.found, [0, 2]);
      await finish(tester);
    });

    testWidgets('make 24: Stuck? shows a way a step at a time; a way shown whole does not count', (tester) async {
      phone(tester);
      final deckId = deckWith([]);
      final card = store.data.cards[store.data.decks[deckId]!.cardIds.single]!;
      final steps = Expr.parse(card.ways[0]).steps;
      await openStudy(tester, deckId);

      await tester.tap(find.text('Stuck?'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('STUCK? · STEP 1 OF 3'), findsOneWidget);
      expect(find.text(steps[0]), findsOneWidget);
      expect(find.text(steps[1]), findsNothing);
      await tester.tap(find.text('More'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(steps[1]), findsOneWidget);
      expect(find.text(card.ways[0]), findsNothing);
      await tester.tap(find.text('Show all'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('STUCK? · THE WHOLE WAY · NOT COUNTED'), findsOneWidget);
      expect(find.text(card.ways[0]), findsOneWidget);

      await build(tester, card.ways[0]);
      expect(find.text('STUCK? SHOWED THIS ONE · NOT COUNTED'), findsOneWidget);
      await swipe(tester, find.byType(MakeBoard));
      expect(card.reps, 0, reason: 'nothing found');

      // Giving up is a left swipe.
      await swipe(tester, find.byType(MakeBoard), right: false);
      expect(card.reps, 1);
      expect(card.found, isEmpty);
      await finish(tester);
    });

    testWidgets('make 24: played on the card whatever the reveal', (tester) async {
      phone(tester);
      for (final mode in [RevealMode.scratch, RevealMode.flip, RevealMode.front]) {
        store.updateSettings((s) => s.reveal = mode);
        await openStudy(tester, deckWith([]));
        expect(find.byType(MakeBoard), findsOneWidget, reason: '$mode');
        expect(find.byType(ScratchFoil), findsNothing);
        await finish(tester);
      }
      store.updateSettings((s) => s.reveal = RevealMode.tap);
    });

    testWidgets('other cards with several answers: tick the ways after the reveal', (tester) async {
      phone(tester);
      store.updateSettings((s) => s.reveal = RevealMode.tap);
      final deckId = deckWith([0], kind: 'text');
      final card = store.data.cards[store.data.decks[deckId]!.cardIds.single]!;
      await openStudy(tester, deckId);
      expect(find.byType(MakeBoard), findsNothing);
      await tester.tap(find.text('Tap to reveal'));
      await settle(tester, 600);
      expect(find.text('TICK THE NEW WAY YOU FOUND'), findsOneWidget);

      await tester.tap(find.text(card.ways[0]));
      await tester.pump(const Duration(milliseconds: 300));
      await swipe(tester, find.text('3 4 6 8'));
      expect(find.text('Found before · find a new way, or swipe left'), findsOneWidget);
      await tester.tap(find.text(card.ways[2]));
      await tester.pump(const Duration(milliseconds: 300));
      await swipe(tester, find.text('3 4 6 8'));
      expect(card.reps, 1);
      expect(card.found, [0, 2]);
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
