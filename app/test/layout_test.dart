import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memory_card/data/card_layout.dart';
import 'package:memory_card/data/catalog.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/features/layout/layout_face.dart';
import 'package:memory_card/services/image_ingest.dart';

/// Pictures on cards: the layout model, the blur settings, PNG transparency, the catalogue's layouts.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mc_layout_'));

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

  group('layout model', () {
    test('every template round-trips through JSON and keeps its shape', () {
      for (final back in [false, true]) {
        for (final t in Tpl.values) {
          final pic = ImageEl(x: 0, y: 0, w: 1, h: 1, src: 'asset:a.png', aspect: 1.5, contain: t == Tpl.only);
          final l = SideLayout.template(t, back: back, image: t == Tpl.text ? null : pic);
          final again = SideLayout.fromJson(jsonDecode(jsonEncode(l.toJson())))!;
          expect(again.tpl, t);
          expect(again.els.length, l.els.length);
          expect(again.hasImage, t != Tpl.text);
          expect(again.mode, LayoutMode.structured);
          for (final e in again.els) {
            expect(e.x, inInclusiveRange(0, 1));
            expect(e.x + e.w, lessThanOrEqualTo(1.0001));
            expect(e.y + e.h, lessThanOrEqualTo(1.0001), reason: '${t.name} ${e.runtimeType}');
          }
        }
      }
    });

    test('a plain text layout counts as no layout; a picture or a canvas does not', () {
      final plain = SideLayout.template(Tpl.text, back: false);
      expect(plain.isPlain, isTrue);
      final canvas = plain.copy()..toCanvas();
      expect(canvas.isPlain, isFalse);
      expect(SideLayout.forPicture(Tpl.below, back: false, src: 'p.png').isPlain, isFalse);
    });

    test('switching template keeps the picture and its crop', () {
      final l = SideLayout.forPicture(Tpl.below, back: false, src: 'p.png', aspect: 2);
      l.firstImage!
        ..zoom = 2.5
        ..panX = 0.2
        ..blur = true;
      l.applyTemplate(Tpl.full, back: false);
      expect(l.tpl, Tpl.full);
      final i = l.firstImage!;
      expect((i.zoom, i.panX, i.blur, i.aspect), (2.5, 0.2, true, 2.0));
      expect((i.x, i.y, i.w, i.h), (0, 0, 1, 1));
    });

    test('a dropped picture is sized to its own shape and stays inside the face', () {
      for (final a in [0.4, 1.0, 1.5, 3.0]) {
        final l = SideLayout(mode: LayoutMode.canvas);
        final e = l.dropImage(src: 'p.png', aspect: a, faceAspect: 276 / 384);
        expect(e.x, greaterThanOrEqualTo(0));
        expect(e.x + e.w, lessThanOrEqualTo(1.0001));
        expect(e.y + e.h, lessThanOrEqualTo(1.0001), reason: 'aspect $a');
        // The frame's shape (in pixels on the face) matches the picture.
        expect((e.w * 276) / (e.h * 384), closeTo(a, 0.05));
      }
    });

    test('z-order helpers', () {
      final l = SideLayout(mode: LayoutMode.canvas);
      final a = l.dropText(), b = l.dropText(), c = l.dropText();
      l.step(a, 1);
      expect(l.els.map((e) => e.id).toList(), [b.id, a.id, c.id]);
      l.reorder(a, toFront: false);
      expect(l.els.first, a);
      l.reorder(a, toFront: true);
      expect(l.els.last, a);
    });

    test('a card made before layouts still loads, and one with layouts keeps them', () {
      final old = CardItem.fromJson({'id': 'c1', 'deck': 'd', 'f': 'hello', 'b': 'hi', 'img': '/x/y.jpg', 'created': 1});
      expect(old.frontLayout, isNull);
      expect(old.hasFrontPicture, isTrue);
      expect(old.thumbSrc, '/x/y.jpg');
      final card = CardItem(
        id: 'c2',
        deckId: 'd',
        front: '',
        back: 'Nigeria',
        frontLayout: SideLayout.forPicture(Tpl.only, back: false, src: 'asset:ng.png', aspect: 1.5, contain: true),
        created: 1,
      );
      final copy = CardItem.fromJson(jsonDecode(jsonEncode(card.toJson())));
      expect(copy.frontLayout!.tpl, Tpl.only);
      expect(copy.frontText, 'Picture');
      expect(copy.hasRichBack, isFalse);
    });
  });

  group('settings and the blur', () {
    test('blur settings round-trip and drive the strength', () {
      final s = Settings()
        ..imageReveal = 'blur'
        ..blurAmount = 1;
      final copy = Settings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map);
      expect((copy.imageReveal, copy.blurAmount), ('blur', 1.0));
      expect(copy.blurSigma, greaterThan(Settings().blurSigma));
      expect(Settings.fromJson({'imgReveal': 'bogus'}).imageReveal, 'blur');
      expect((Settings()..imageReveal = 'show').blurSigma, 0);
      expect(PreReveal.of(Settings()..imageReveal = 'hide').hide, isTrue);
      expect(PreReveal.of(Settings()..imageReveal = 'show').active, isFalse);
    });
  });

  group('bringing pictures in', () {
    test('a PNG with a see-through background stays a PNG and stays see-through', () {
      final bytes = File(writePng('cutout.png', transparent: true)).readAsBytesSync();
      final out = ImageIngest.prepare(bytes);
      expect((out.ext, out.alpha), ('png', true));
      final back = img.decodePng(out.bytes)!;
      expect(back.getPixel(1, 1).a, 0, reason: 'corner is still transparent');
      expect(back.getPixel(60, 40).a, 255);
      expect(out.aspect, closeTo(120 / 80, 0.001));
    });

    test('a flat PNG is kept as it is; a big photo is shrunk and becomes a JPEG', () {
      final small = File(writePng('flat.png')).readAsBytesSync();
      final a = ImageIngest.prepare(small);
      expect((a.ext, a.alpha, a.bytes.length), ('png', false, small.length));

      final photo = img.Image(width: 3200, height: 2400);
      for (final p in photo) {
        p.setRgb(p.x % 256, p.y % 256, (p.x + p.y) % 256);
      }
      final big = ImageIngest.prepare(Uint8List.fromList(img.encodePng(photo)));
      expect(big.ext, 'jpg');
      final shown = img.decodeJpg(big.bytes)!;
      expect(shown.width, ImageIngest.maxSide);
      expect(big.aspect, closeTo(4 / 3, 0.001));
    });

    test('a large see-through PNG is shrunk without losing the transparency', () {
      final im = img.Image(width: 2400, height: 1200, numChannels: 4);
      for (final p in im) {
        if (p.x < 600) {
          p.setRgba(0, 0, 0, 0);
        } else {
          p.setRgba(200, 30, 30, 255);
        }
      }
      final out = ImageIngest.prepare(Uint8List.fromList(img.encodePng(im)));
      expect((out.ext, out.alpha), ('png', true));
      expect(img.decodePng(out.bytes)!.width, ImageIngest.maxSide);
    });

    test('rubbish bytes are refused', () {
      expect(() => ImageIngest.prepare(Uint8List.fromList([1, 2, 3, 4])), throwsFormatException);
    });
  });


  group('the shop catalogue', () {
    CatalogDeck deck(Map<String, Object?> style) => CatalogDeck.fromJson({
          'id': 'flags-x',
          'name': 'Flags',
          'category': 'knowledge',
          'style': style,
          'cards': [
            {'front': '', 'back': 'Nigeria', 'img': 'ng.png', 'a': 1.5, 'hook': 'Capital: Abuja'},
            {'front': 'Plain', 'back': 'Card'},
          ],
        });

    test('a picture card becomes a front picture layout; a plain card stays plain', () {
      final d = deck({'front': 'only', 'fit': 'contain', 'reverse': true, 'plate': 'paper'});
      expect(d.hasPictures, isTrue);
      expect(d.style.reverse, isTrue);
      final (fl, bl) = d.layoutsFor(d.cards[0]);
      expect(bl, isNull);
      final pic = fl!.firstImage!;
      expect((fl.tpl, pic.contain, pic.plate, pic.outline), (Tpl.only, true, 'paper', true));
      expect(pic.src, 'asset:assets/content/img/flags-x/ng.png');
      expect(pic.aspect, 1.5);
      final (pf, pb) = d.layoutsFor(d.cards[1]);
      expect((pf, pb), (null, null));
    });
  });
}
