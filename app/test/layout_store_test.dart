import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memory_card/data/card_layout.dart';
import 'package:memory_card/data/store.dart';

/// Adding picture decks and editing cards with pictures: the reverse cards stay in step.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late AppStore store;

  // One store for the whole file (Hive keeps its boxes open between tests).
  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('mc_layout_store_');
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

  group('picture decks and reverse cards', () {
    test('adding a picture deck makes picture cards and reverse cards that answer with the picture', () async {
      final id = store.catalog.decks.where((d) => d.hasPictures).map((d) => d.id).firstOrNull;
      if (id == null) {
        // No picture deck bundled yet: build one by hand through the same path.
        final f = store.createFolder('Pictures');
        final d = store.createDeck(name: 'Flags', folderId: f.id);
        store.importRows(d.id, [
          CardDraft(front: '', back: 'Nigeria', frontLayout: SideLayout.forPicture(Tpl.only, back: false, src: writePng('ng.png'), contain: true)),
        ], reverse: true, newDeck: true);
        final cards = store.data.cardsOf(d).toList();
        expect(cards.length, 2);
        final fwd = cards.firstWhere((c) => !c.isReverse), rev = cards.firstWhere((c) => c.isReverse);
        expect(fwd.hasFrontPicture, isTrue);
        expect(rev.frontLayout, isNull);
        expect(rev.hasRichBack, isTrue);
        expect(rev.backLayout!.firstImage!.src, fwd.frontLayout!.firstImage!.src);
        expect(rev.front, 'Nigeria');
        expect(rev.back, '');
        return;
      }
      final f = store.createFolder('Pictures');
      final d = store.addCatalogDeck(id, f.id);
      final cards = store.data.cardsOf(d).toList();
      expect(cards.any((c) => c.hasFrontPicture), isTrue);
      if (store.catalog.byId(id)!.style.reverse) expect(cards.any((c) => c.isReverse && c.hasRichBack), isTrue);
    });

    test('editing a card keeps its reverse in step, pictures included', () async {
      final f = store.createFolder('Pictures');
      final d = store.createDeck(name: 'Faces', folderId: f.id);
      final pic = SideLayout.forPicture(Tpl.full, back: false, src: writePng('a.png'));
      final c = store.addCard(d.id, CardDraft(front: 'Who?', back: 'Ada', frontLayout: pic), reverse: true);
      final rev = store.data.cards[c.siblingId]!;
      expect(rev.back, 'Who?');
      expect(rev.hasRichBack, isTrue);
      // Every picture that moved to the answer side is flagged to blur until revealed.
      expect(rev.backLayout!.images.every((i) => i.blur), isTrue);

      // Take the picture away: the reverse loses its answer picture too.
      store.updateCard(c.id, const CardDraft(front: 'Who?', back: 'Ada'));
      expect(store.data.cards[c.id]!.frontLayout, isNull);
      expect(store.data.cards[c.siblingId]!.backLayout, isNull);

      // Put a different picture on the back of the original: the reverse shows it on its front.
      final onBack = SideLayout.forPicture(Tpl.above, back: true, src: writePng('b.png'));
      store.updateCard(c.id, CardDraft(front: 'Who?', back: 'Ada', backLayout: onBack));
      final r2 = store.data.cards[c.siblingId]!;
      expect(r2.frontLayout!.firstImage!.src, onBack.firstImage!.src);
      expect(r2.frontLayout, isNot(same(onBack)), reason: 'copied, not shared');
    });

    test('a backup carries the pictures inside layouts, and restoring keeps them', () async {
      final f = store.createFolder('Backup');
      final d = store.createDeck(name: 'Pics', folderId: f.id);
      final path = writePng('backup.png', transparent: true);
      final layout = SideLayout.forPicture(Tpl.above, back: false, src: path, aspect: 1.5, alpha: true);
      final c = store.addCard(d.id, CardDraft(front: 'Q', back: 'A', frontLayout: layout));
      final raw = await store.exportBackup();
      expect(raw, contains('data:image/png;base64,'));
      expect(raw, isNot(contains(path.replaceAll(r'\', r'\\'))), reason: 'the file path is replaced by the picture itself');

      await store.importBackup(raw);
      final back = store.data.cards[c.id]!;
      final pic = back.frontLayout!.firstImage!;
      expect(pic.alpha, isTrue);
      expect(pic.src.startsWith('data:image/png') || File(pic.src).existsSync(), isTrue);
    });
  });
}
