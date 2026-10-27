import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/data/card_layout.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/engine/assessor.dart';
import 'package:memory_card/engine/baselines.dart';
import 'package:memory_card/features/layout/layout_face.dart';

/// Voices and videos on cards: what is stored, how reverse cards swap them, backups, and the hint rule.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late AppStore store;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('mc_media_');
    store = await AppStore.open(path: tmp.path);
  });

  String file(String name, List<int> bytes) => (File('${tmp.path}/$name')..writeAsBytesSync(bytes)).path;

  ImageEl video({bool hint = false, bool blur = false, int ms = 4200}) => ImageEl(
        x: 0.1,
        y: 0.2,
        w: 0.8,
        h: 0.4,
        src: file('poster.jpg', [0xFF, 0xD8, 0xFF]),
        aspect: 16 / 9,
        video: file('clip.mp4', [0, 0, 0, 24, 102, 116, 121, 112]),
        videoMs: ms,
        sound: false,
        loop: true,
        hint: hint,
        blur: blur,
      );

  group('stored shapes', () {
    test('a video element keeps its file, length, sound, loop and hint through JSON', () {
      final el = video(hint: true);
      final back = ImageEl.fromJson(jsonDecode(jsonEncode(el.toJson())) as Map)!;
      expect(back.isVideo, isTrue);
      expect(back.video, el.video);
      expect(back.src, el.src, reason: 'the poster stays the picture every still view draws');
      expect(back.videoMs, 4200);
      expect(back.sound, isFalse);
      expect(back.loop, isTrue);
      expect(back.hint, isTrue);
      // A plain picture writes none of the new keys (old cards stay byte-for-byte the same).
      final pic = ImageEl(x: 0, y: 0, w: 1, h: 1, src: 'a.png');
      expect(pic.toJson().keys, isNot(contains('v')));
      expect(pic.toJson().keys, isNot(contains('mu')));
      expect(ImageEl.fromJson(pic.toJson())!.sound, isTrue);
    });

    test('templates carry the video into their picture slot', () {
      final l = SideLayout.forPicture(Tpl.above, back: false, src: 'p.jpg', video: 'v.mp4', videoMs: 900, hint: true);
      expect(l.hasVideo, isTrue);
      expect(l.firstImage!.video, 'v.mp4');
      expect(l.firstImage!.hint, isTrue);
      l.applyTemplate(Tpl.full, back: false);
      expect(l.firstImage!.video, 'v.mp4', reason: 'switching template keeps the video');
      expect(l.promptVideoMs, 0, reason: 'a hint is not part of the question');
    });

    test('a card sound round-trips, and lists name a side that is only media', () {
      final c = CardItem(
        id: 'c1',
        deckId: 'd',
        front: '',
        back: '',
        created: 0,
        soundF: CardSound(src: 'q.m4a', ms: 2500, recorded: true),
        backLayout: SideLayout.forPicture(Tpl.only, back: true, src: 'p.jpg', video: 'v.mp4', videoMs: 7000),
      );
      final r = CardItem.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map);
      expect(r.soundF!.src, 'q.m4a');
      expect(r.soundF!.ms, 2500);
      expect(r.soundF!.recorded, isTrue);
      expect(r.soundB, isNull);
      expect(r.frontText, 'Sound');
      expect(r.backText, 'Video');
      expect(r.promptMediaMs, 2500);
      expect(CardSound.fromJson({'s': ''}), isNull);
    });

    test('a question video counts toward the time the prompt takes to play', () {
      final c = CardItem(
        id: 'c2',
        deckId: 'd',
        front: 'What happens next?',
        back: 'It falls',
        created: 0,
        frontLayout: SideLayout(els: [video(ms: 9000)]),
        soundF: CardSound(src: 'q.m4a', ms: 2000),
      );
      expect(c.promptMediaMs, 9000);
    });

    test('settings: sounds and videos play by themselves unless turned off', () {
      expect(Settings().autoPlay, isTrue);
      expect(Settings.fromJson({}).autoPlay, isTrue);
      expect(Settings.fromJson((Settings()..autoPlay = false).toJson()).autoPlay, isFalse);
    });

    test('hints stay covered even when waiting pictures are set to show', () {
      final s = Settings()..imageReveal = 'show';
      final p = PreReveal.of(s);
      expect(p.sigma, 0);
      expect(p.hintSigma, greaterThan(5));
      expect(PreReveal.of(Settings()..imageReveal = 'blur').hintSigma, Settings().blurSigma);
      expect(PreReveal.none.hintSigma, 0, reason: 'previews show hints plainly');
    });
  });

  group('cards with sounds and videos', () {
    test('a reverse card swaps the sounds; videos move with their side and lose the hint flag', () {
      final f = store.createFolder('Media');
      final d = store.createDeck(name: 'Birds', folderId: f.id);
      final c = store.addCard(
        d.id,
        CardDraft(
          front: '',
          back: 'Robin',
          soundF: CardSound(src: file('song.m4a', [1, 2, 3]), ms: 3100, recorded: true),
          soundB: CardSound(src: file('name.m4a', [4, 5]), ms: 900),
          frontLayout: SideLayout(els: [video(hint: true)]),
        ),
        reverse: true,
      );
      final rev = store.data.cards[c.siblingId]!;
      expect(rev.soundF!.src, c.soundB!.src);
      expect(rev.soundB!.src, c.soundF!.src);
      final moved = rev.backLayout!.firstImage!;
      expect(moved.isVideo, isTrue);
      expect(moved.blur, isTrue, reason: 'on the answer side it waits for the reveal');
      expect(moved.hint, isFalse);

      // Editing the original keeps the reverse in step.
      store.updateCard(c.id, CardDraft(front: 'Which bird?', back: 'Robin', soundF: c.soundF));
      final rev2 = store.data.cards[c.siblingId]!;
      expect(rev2.soundB!.src, c.soundF!.src);
      expect(rev2.soundF, isNull);
      expect(rev2.backLayout, isNull);
    });

    test('a backup carries recordings and videos inline and brings them back', () async {
      final f = store.createFolder('Backup');
      final d = store.createDeck(name: 'Clips', folderId: f.id);
      final c = store.addCard(
        d.id,
        CardDraft(
          front: 'Listen',
          back: 'A',
          soundF: CardSound(src: file('a.m4a', [9, 8, 7, 6]), ms: 400),
          backLayout: SideLayout(els: [video(blur: true)]),
        ),
      );
      final raw = await store.exportBackup();
      final cards = (jsonDecode(raw) as Map)['cards'] as List;
      final j = cards.firstWhere((e) => (e as Map)['id'] == c.id) as Map;
      expect((j['sf'] as Map)['s'], startsWith('data:audio/mp4;base64,'));
      final el = ((j['bl'] as Map)['e'] as List).first as Map;
      expect(el['v'], startsWith('data:video/mp4;base64,'));
      expect(el['s'], startsWith('data:image/jpeg;base64,'));

      await store.importBackup(raw);
      final back = store.data.cards[c.id]!;
      expect(back.soundF, isNotNull);
      expect(back.soundF!.ms, 400);
      expect(back.backLayout!.firstImage!.isVideo, isTrue);
    });
  });

  group('hints and grading', () {
    final baselines = PersonalBaselines();
    final tuner = GradeTuner();
    Assessment assess(bool hint) => const Assessor().assess(
          recalled: true,
          s: ReviewSignals(thinkMs: 900, verifyMs: 300, velocity: 2200, promptChars: 8, hintUsed: hint),
          baselines: baselines,
          tuner: tuner,
          deckId: 'd',
          firstExposure: false,
        );

    test('remembering with a hint is Hard, however clean the swipe', () {
      expect(assess(false).grade, greaterThanOrEqualTo(3));
      final a = assess(true);
      expect(a.grade, 2);
      expect(a.kind, RecallKind.effortful);
      expect(const ReviewSignals(thinkMs: 1, hintUsed: true).toJson()['hint'], isTrue);
      expect(const ReviewSignals(thinkMs: 1).toJson().containsKey('hint'), isFalse);
    });
  });
}
