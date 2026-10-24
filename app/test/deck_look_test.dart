import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/data/catalog.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/engine/assessor.dart';
import 'package:memory_card/engine/days.dart';
import 'package:memory_card/engine/deck_seals.dart';

/// Deck skins and deck seals: how they are stored, read from the shop, earned and carried by a backup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late AppStore store;

  // One store for the whole file (Hive keeps its boxes open between tests).
  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('mc_deck_look_');
    store = await AppStore.open(path: tmp.path);
  });

  test('a skin and seals round-trip through JSON', () {
    final d = Deck(
      id: 'd1',
      name: 'Look',
      created: 1,
      skin: DeckSkin(src: '/x/skin.jpg', x: 0.2, y: 0.8, zoom: 1.5, shade: 0.4, light: false),
      seals: [DeckSeal(id: 's', title: 'Ten', when: 'start', shape: 'wide', color: 'teal', text: '10', image: '/x/s.png', art: 'color')],
      sealsEarned: {'s': 42},
    );
    final back = Deck.fromJson(d.toJson());
    expect(back.skin!.src, '/x/skin.jpg');
    expect(back.skin!.x, 0.2);
    expect(back.skin!.zoom, 1.5);
    expect(back.skin!.light, isFalse);
    final s = back.seals.single;
    expect([s.id, s.title, s.when, s.shape, s.color, s.text, s.image, s.art], ['s', 'Ten', 'start', 'wide', 'teal', '10', '/x/s.png', 'color']);
    expect(back.sealsEarned, {'s': 42});
    // Unknown values fall back to safe ones; a deck without a look stays without one.
    final odd = DeckSeal.fromJson({'id': 'o', 'title': 'O', 'when': 'never', 'shape': 'round', 'color': 'pink', 'art': 'x'});
    expect([odd.when, odd.shape, odd.color, odd.art], ['mastered', 'square', 'red', 'stamp']);
    expect(Deck.fromJson(Deck(id: 'p', name: 'P', created: 1).toJson()).skin, isNull);
  });

  test('catalogue skins and seals point at the deck folder; plain overrides the shop skin', () {
    final cd = CatalogDeck.fromJson({
      'id': 'demo-deck',
      'name': 'Demo',
      'cards': [
        {'front': 'a', 'back': 'b'},
      ],
      'skin': {'img': 'skin.jpg', 'x': 0.3, 'shade': 0.6, 'text': 'dark'},
      'seals': [
        {'id': 'leaf', 'title': 'Leaf', 'when': 'seen', 'img': 'seal-leaf.png'},
      ],
    });
    expect(cd.skin!.src, 'asset:assets/content/img/demo-deck/skin.jpg');
    expect(cd.skin!.light, isFalse);
    expect(cd.seals.single.image, 'asset:assets/content/img/demo-deck/seal-leaf.png');

    final shop = store.catalog.decks.where((d) => d.skin != null).firstOrNull;
    if (shop == null) return; // no bundled deck has a skin yet
    final f = store.createFolder('Skins');
    final d = store.addCatalogDeck(shop.id, f.id);
    expect(store.skinOf(d)!.src, shop.skin!.src, reason: 'a shop deck shows the shop skin by default');
    store.saveLook(d.id, skin: DeckSkin.none());
    expect(store.skinOf(d), isNull, reason: 'plain, chosen on purpose');
    store.saveLook(d.id, skin: null);
    expect(store.skinOf(d), isNotNull);
  });

  test('milestones press seals once, on the swipe that reaches them', () {
    final f = store.createFolder('Seals');
    final d = store.createDeck(name: 'Ten swipes', folderId: f.id, seals: [
      DeckSeal(id: 'go', title: 'Go', when: 'start', text: 'GO'),
      DeckSeal(id: 'all', title: 'All', when: 'seen', text: 'ALL'),
      DeckSeal(id: 'hundred', title: 'Hundred', when: 'reviews', text: '100'),
    ]);
    store.importRows(d.id, [for (var i = 0; i < 4; i++) CardDraft(front: 'q$i', back: 'a$i')], newDeck: true);
    final pressed = <String>[];
    for (var i = 0; i < 12; i++) {
      store.prepare(d.id, notify: false);
      final id = store.top(d.id)!;
      final out = store.swipe(
        deckId: d.id,
        cardId: id,
        recalled: true,
        signals: const ReviewSignals(thinkMs: 1500, verifyMs: 600, dragMs: 200, velocity: 1.2, promptChars: 2),
      );
      pressed.addAll(out.deckSeals.map((s) => s.id));
    }
    expect(pressed, containsAll(['go', 'all']));
    expect(pressed.where((p) => p == 'go').length, 1, reason: 'a seal is pressed once');
    expect(pressed, isNot(contains('hundred')));
    expect(d.sealsEarned.keys, containsAll(['go', 'all']));
    expect(DeckMilestones.reached('half', d, store.stats(d)), isTrue, reason: 'every card was just remembered');

    // Removing a seal forgets that it was pressed.
    store.saveLook(d.id, skin: null, seals: d.seals.where((s) => s.id != 'go').toList());
    expect(d.sealsEarned.containsKey('go'), isFalse);
    expect(d.sealsEarned.containsKey('all'), isTrue);
  });

  test('a backup carries the skin and seal pictures inline and restores them', () async {
    final pic = File('${tmp.path}/skin.png')..writeAsBytesSync(_png);
    final f = store.createFolder('Backup');
    final d = store.createDeck(
      name: 'Backed up',
      folderId: f.id,
      skin: DeckSkin(src: pic.path, x: 0.1),
      seals: [DeckSeal(id: 'b', title: 'B', when: 'mastered', image: pic.path)],
    );
    final raw = await store.exportBackup();
    expect(raw, contains('data:image/png;base64,'));
    store.shiftClock(msPerDay);
    await store.importBackup(raw);
    final back = store.data.decks[d.id]!;
    expect(back.skin!.x, 0.1);
    // Restored to files again (or kept as data URIs where there is no storage plugin).
    expect(back.skin!.src.isNotEmpty, isTrue);
    expect(back.seals.single.image, isNotNull);
  });
}

/// A 1×1 transparent PNG.
const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00, 0x00, 0x05, 0x00, 0x01, 0xE9, 0xFA, 0xDC, 0xD8, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
