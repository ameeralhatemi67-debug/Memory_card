import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/data/store_scope.dart';
import 'package:memory_card/features/decks/deck_flights.dart';
import 'package:memory_card/features/decks/deck_motion.dart';
import 'package:memory_card/features/decks/deck_row.dart';
import 'package:memory_card/features/decks/move_flight.dart';
import 'package:memory_card/ui/motion.dart';
import 'package:memory_card/ui/theme.dart';

/// The three animated deck actions picked from the canvas: Delete A (hold to delete, the deck shivers and bursts),
/// Archive B (the deck is picked up and snaps into a tray) and Pin A (a pin is pressed into the deck at the top), and
/// the list reorganising around them. With reduced motion the old fade-and-collapse paths are used.
void main() {
  late AppStore store;
  late Deck deck;

  setUpAll(() async {
    T.googleFonts = false;
    final dir = Directory.systemTemp.createTempSync('mc_actions_');
    store = await AppStore.open(path: dir.path);
    final f = store.createFolder('Languages');
    deck = store.addCatalogDeck('es-basics', f.id);
    store.createFolder('Anime', atTop: false);
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  var deleted = 0, archived = 0, pinned = 0;
  final moved = <String>[];

  Future<void> mount(WidgetTester tester, {bool reduced = false}) async {
    deleted = archived = pinned = 0;
    moved.clear();
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MotionPrefs(
        reduced: reduced,
        child: MaterialApp(
          theme: Mc.theme(Mc.light),
          home: Scaffold(
            body: Align(
              alignment: const Alignment(0, -0.4),
              child: DeckRow(
                deck: deck,
                stats: store.stats(deck),
                onOpen: () {},
                onDelete: () => deleted++,
                onArchive: () => archived++,
                onMove: () {},
                onPin: () => pinned++,
                onMoveTo: moved.add,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  Finder bar() => find.byKey(ValueKey('deck-bar-${deck.id}'));
  Finder tile(String id) => find.byKey(ValueKey('tile-$id'));

  Future<void> run(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> swipe(WidgetTester tester, double dx) async {
    final g = await tester.startGesture(tester.getCenter(bar()));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(Offset(dx / 20, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await g.up();
    await run(tester, 1.0);
  }

  testWidgets('Delete A: holding the red chip makes the deck shiver, then it bursts and is deleted', (tester) async {
    phone(tester);
    await mount(tester);
    await swipe(tester, -100);
    final rest = tester.getTopLeft(bar()).dy;
    final g = await tester.startGesture(tester.getCenter(tile('delete')));
    var widest = 0.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      widest = math.max(widest, (tester.getTopLeft(bar()).dy - rest).abs());
    }
    expect(widest, greaterThan(2), reason: 'the bar rocks while it is held');
    expect(deleted, 0, reason: 'not deleted before the hold is over');
    await run(tester, 0.5);
    expect(deleted, 1, reason: 'the hold went through');
    await g.up();
    await run(tester, 1.3);
    expect(deleted, 1, reason: 'once');
  });

  testWidgets('Delete A: letting go early cancels, and the deck settles back', (tester) async {
    phone(tester);
    await mount(tester);
    await swipe(tester, -100);
    final rest = tester.getTopLeft(bar());
    final g = await tester.startGesture(tester.getCenter(tile('delete')));
    await run(tester, 0.7);
    await g.up();
    await run(tester, 1.4);
    expect(deleted, 0);
    expect((tester.getTopLeft(bar()) - rest).distance, lessThan(0.6), reason: 'back to rest');
    // And it can be held again.
    final g2 = await tester.startGesture(tester.getCenter(tile('delete')));
    await run(tester, 1.4);
    await g2.up();
    await run(tester, 0.3);
    expect(deleted, 1);
  });

  testWidgets('Delete A: a quick tap on the red chip does not delete', (tester) async {
    phone(tester);
    await mount(tester);
    await swipe(tester, -100);
    await tester.tap(tile('delete'));
    await run(tester, 2.0);
    expect(deleted, 0);
  });

  testWidgets('Archive B: the deck is lifted off the row and snaps into the tray; the others are told when it leaves', (tester) async {
    phone(tester);
    await mount(tester);
    await swipe(tester, -190);
    await tester.tap(tile('archive'));
    await run(tester, 0.25);
    expect(archived, 0);
    expect(find.byType(ArchiveFlight), findsOneWidget, reason: 'the flight carries the bar');
    await run(tester, 0.4);
    expect(archived, 1, reason: 'released a moment after the drop begins');
    await run(tester, 2.0);
    expect(find.byType(ArchiveFlight), findsNothing, reason: 'the tray slid away');
    expect(archived, 1);
  });

  testWidgets('Pin A: the deck lifts, the store pins it, a pin is pressed in, and the flight ends', (tester) async {
    phone(tester);
    await mount(tester);
    await swipe(tester, 190);
    await tester.tap(tile('pin'));
    await run(tester, 0.2);
    expect(pinned, 0);
    expect(find.byType(PinFlight), findsOneWidget);
    await run(tester, 0.3);
    expect(pinned, 1, reason: 'pinned when the deck has been lifted');
    await run(tester, 2.0);
    expect(find.byType(PinFlight), findsNothing);
    expect(pinned, 1);
  });

  testWidgets('with reduced motion archive uses the old fade: no flight, the callback runs after it', (tester) async {
    phone(tester);
    await mount(tester, reduced: true);
    await swipe(tester, -190);
    await tester.tap(tile('archive'));
    await run(tester, 0.6);
    expect(find.byType(ArchiveFlight), findsNothing);
    expect(archived, 1);
  });

  testWidgets('with reduced motion pin is instant: no flight, the callback runs at once', (tester) async {
    phone(tester);
    await mount(tester, reduced: true);
    await swipe(tester, 190);
    await tester.tap(tile('pin'));
    await run(tester, 0.2);
    expect(find.byType(PinFlight), findsNothing);
    expect(pinned, 1);
  });

  testWidgets('Move D: the Move chip deals the folder card, picking one hauls the deck off and moves it', (tester) async {
    phone(tester);
    await mount(tester);
    await swipe(tester, 100);
    await tester.tap(tile('move'));
    await run(tester, 0.3);
    expect(find.byType(MoveFlight), findsOneWidget);
    expect(moved, isEmpty);
    await run(tester, 1.0);
    expect(find.text('Anime'), findsOneWidget, reason: 'the folders are on the card');
    expect(find.text('+ New folder'), findsOneWidget);
    await tester.tap(find.text('Anime'));
    await run(tester, 1.0);
    expect(moved, isEmpty, reason: 'the deck is still on its way');
    await run(tester, 0.8);
    expect(moved.length, 1, reason: 'released when the deck is out of sight');
    await run(tester, 1.2);
    expect(find.byType(MoveFlight), findsNothing);
    expect(moved.length, 1);
  });

  testWidgets('Move D: tapping outside the card puts it back and moves nothing', (tester) async {
    phone(tester);
    await mount(tester);
    await swipe(tester, 100);
    await tester.tap(tile('move'));
    await run(tester, 1.2);
    await tester.tapAt(const Offset(195, 800));
    await run(tester, 1.0);
    expect(find.byType(MoveFlight), findsNothing);
    expect(moved, isEmpty);
  });

  testWidgets('with reduced motion Move keeps its old sheet', (tester) async {
    phone(tester);
    var asked = 0;
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MotionPrefs(
        reduced: true,
        child: MaterialApp(
          theme: Mc.theme(Mc.light),
          home: Scaffold(
            body: Align(
              alignment: const Alignment(0, -0.4),
              child: DeckRow(
                deck: deck,
                stats: store.stats(deck),
                onOpen: () {},
                onDelete: () {},
                onArchive: () {},
                onMove: () => asked++,
                onPin: () {},
                onMoveTo: moved.add,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await swipe(tester, 100);
    await tester.tap(tile('move'));
    await run(tester, 0.3);
    expect(asked, 1);
    expect(find.byType(MoveFlight), findsNothing);
  });

  group('the folder card', () {
    List<MoveFolderOption> options(int n) =>
        [for (var i = 0; i < n; i++) MoveFolderOption(id: 'f$i', name: 'Folder ${i + 1}', decks: i, tab: Colors.grey)];

    Future<void> show(WidgetTester tester, int n, {List<String>? log}) async {
      await tester.pumpWidget(MaterialApp(
        theme: Mc.theme(Mc.light),
        home: Scaffold(
          body: MoveFlight(
            deck: const FlightDeck(id: 'x', name: 'Spanish · Basics', meta: '24 cards · new', steps: 0, skin: null),
            rest: const Rect.fromLTWH(20, 300, 350, 72),
            start: const Rect.fromLTWH(-30, 300, 350, 72),
            options: options(n),
            onChosen: () => log?.add('chosen'),
            onNewFolder: () async => null,
            onRelease: (id) => log?.add('release $id'),
            onCancel: () => log?.add('cancel'),
            onDone: () => log?.add('done'),
          ),
        ),
      ));
    }

    testWidgets('keeps one height however many folders there are, and the list scrolls inside it', (tester) async {
      phone(tester);
      final heights = <int, double>{};
      for (final n in [2, 5, 12, 40]) {
        await show(tester, n);
        await run(tester, 1.2);
        heights[n] = tester.getSize(find.byType(FolderCardFace)).height;
      }
      expect(heights[2]!, lessThan(heights[5]!), reason: 'fewer folders: a shorter card');
      expect(heights[12], heights[40], reason: 'it stops growing');
      expect(heights[5], lessThanOrEqualTo(heights[12]!));
      await show(tester, 12);
      await run(tester, 1.2);
      expect(find.text('Folder 12'), findsNothing, reason: 'not built yet, it is below the fold');
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await run(tester, 0.5);
      expect(find.text('Folder 12'), findsOneWidget);
      expect(tester.getSize(find.byType(FolderCardFace)).height, heights[12]);
    });

    testWidgets('picking a folder: chosen at once, released when the deck is gone, done at the end', (tester) async {
      phone(tester);
      final log = <String>[];
      await show(tester, 4, log: log);
      await run(tester, 1.2);
      await tester.tap(find.text('Folder 2'));
      await run(tester, 0.1);
      expect(log, ['chosen']);
      await run(tester, 1.7);
      expect(log, ['chosen', 'release f1']);
      await run(tester, 1.0);
      expect(log, ['chosen', 'release f1', 'done']);
    });

    testWidgets('a tap before the card has turned over does nothing', (tester) async {
      phone(tester);
      final log = <String>[];
      await show(tester, 4, log: log);
      await run(tester, 0.2);
      await tester.tap(find.text('Folder 1'), warnIfMissed: false);
      await run(tester, 0.1);
      expect(log, isEmpty);
    });
  });

  testWidgets('FlipSlot: when the epoch changes a row that moved springs from where it was to where it is', (tester) async {
    phone(tester);
    var order = ['a', 'b', 'c'];
    var epoch = 0;
    late StateSetter set;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          set = setState;
          return ListView(
            children: [
              for (final id in order)
                FlipSlot(
                  key: ValueKey(id),
                  epoch: epoch,
                  spec: const FlipSpec(z: 0.8, w: 16),
                  child: SizedBox(height: 80, child: Text(id)),
                ),
            ],
          );
        }),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final yA = tester.getTopLeft(find.text('a')).dy;
    final yC = tester.getTopLeft(find.text('c')).dy;
    expect(yC - yA, 160);
    set(() {
      order = ['c', 'a', 'b'];
      epoch++;
    });
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.text('c')).dy, closeTo(yC, 8), reason: 'c still starts where it was');
    await tester.pump(const Duration(milliseconds: 150));
    final mid = tester.getTopLeft(find.text('c')).dy;
    expect(mid, lessThan(yC));
    expect(mid, greaterThan(yA));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(find.text('c')).dy, closeTo(yA, 0.5));
    expect(tester.getTopLeft(find.text('a')).dy, closeTo(yA + 80, 0.5));
    expect(tester.getTopLeft(find.text('b')).dy, closeTo(yA + 160, 0.5));
  });
}
