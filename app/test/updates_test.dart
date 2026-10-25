import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/services/updates.dart';

/// What the GitHub latest-release address answers, cut down to what the code reads.
String release({String tag = 'v1.6.0', String body = '- **One** thing\n- Two things', bool draft = false, bool pre = false, String? apk, int size = 150123456}) =>
    jsonEncode({
      'tag_name': tag,
      'draft': draft,
      'prerelease': pre,
      'body': body,
      'html_url': 'https://github.com/${Updates.repo}/releases/tag/$tag',
      'assets': [
        {'name': 'MemoryCard.apk.sha256', 'size': 90, 'browser_download_url': 'https://github.com/${Updates.repo}/releases/download/$tag/MemoryCard.apk.sha256'},
        {
          'name': 'MemoryCard.apk',
          'size': size,
          'browser_download_url': apk ?? 'https://github.com/${Updates.repo}/releases/download/$tag/MemoryCard.apk',
        },
      ],
    });

void main() {
  group('versions', () {
    test('a tag becomes numbers, with or without the v and the build', () {
      expect(Updates.parseVersion('v1.6.0'), [1, 6, 0, 0]);
      expect(Updates.parseVersion('1.5.0+10'), [1, 5, 0, 10]);
      expect(Updates.parseVersion('release 7'), isNull);
      expect(Updates.parseVersion(''), isNull);
    });

    test('newer by version first, and by build only when the tag names one', () {
      expect(Updates.isNewer('1.6.0', 0, '1.5.0', 10), isTrue);
      expect(Updates.isNewer('1.5.1', 0, '1.5.0', 10), isTrue);
      expect(Updates.isNewer('2.0.0', 0, '1.99.99', 0), isTrue);
      expect(Updates.isNewer('1.10.0', 0, '1.9.9', 0), isTrue);
      expect(Updates.isNewer('1.5.0', 0, '1.5.0', 10), isFalse, reason: 'the same version, the tag names no build');
      expect(Updates.isNewer('1.5.0', 11, '1.5.0', 10), isTrue);
      expect(Updates.isNewer('1.5.0', 10, '1.5.0', 10), isFalse);
      expect(Updates.isNewer('1.4.1', 0, '1.5.0', 10), isFalse);
      expect(Updates.isNewer('nightly', 0, '1.5.0', 10), isFalse);
      expect(Updates.isNewer('1.6.0', 0, '', 0), isFalse, reason: 'the running version is unknown');
    });
  });

  group('release notes', () {
    test('the first three bullets of a real release, as plain short lines', () {
      final body = File('../docs/releases/1.4.1.md').readAsStringSync();
      final notes = Updates.notesFrom(body);
      expect(notes, hasLength(3));
      expect(notes[0], 'A hand of cards for navigation: Home, Memory Lab, a smart +, Shop and Account.');
      expect(notes[1], startsWith('90 ready-made decks, 2,507 cards in the shop'));
      expect(notes[2], startsWith('Pictures on cards: structured layouts or a free canvas'));
      for (final n in notes) {
        expect(n.length, lessThanOrEqualTo(82), reason: n);
        expect(n, isNot(contains('*')));
      }
    });

    test('links lose their address, empty bullets and prose are skipped, and nothing is invented', () {
      expect(Updates.notesFrom('Intro\n\n- See [the guide](https://x.y/z) now\n-\n* `Code` change'), ['See the guide now', 'Code change']);
      expect(Updates.notesFrom('Just a paragraph.'), isEmpty);
    });
  });

  group('the release answer', () {
    test('becomes the card\'s facts', () {
      final info = UpdateInfo.fromRelease(jsonDecode(release(body: 'Important: widgets were blank.\n\n- **Fix:** widgets keep their size\n- B\n- C\n- D')))!;
      expect(info.version, '1.6.0');
      expect(info.important, isTrue);
      expect(info.notes, ['Fix: widgets keep their size', 'B', 'C']);
      expect(info.size, 150123456);
      expect(info.megabytes, '150 MB');
      expect(info.downloadUrl, endsWith('/releases/download/v1.6.0/MemoryCard.apk'));
      expect(info.pageUrl, endsWith('/releases/tag/v1.6.0'));
      final again = UpdateInfo.fromJson(info.toJson())!;
      expect(again.version, info.version);
      expect(again.notes, info.notes);
      expect(again.size, info.size);
      expect(again.important, isTrue);
    });

    test('a draft, a pre-release or a tag that is not a version is no update', () {
      expect(UpdateInfo.fromRelease(jsonDecode(release(draft: true))), isNull);
      expect(UpdateInfo.fromRelease(jsonDecode(release(pre: true))), isNull);
      expect(UpdateInfo.fromRelease(jsonDecode(release(tag: 'nightly'))), isNull);
      expect(UpdateInfo.fromRelease(const ['not', 'a', 'map']), isNull);
    });

    test('a link that leaves this project falls back to the fixed one', () {
      final info = UpdateInfo.fromRelease(jsonDecode(release(apk: 'https://evil.example/MemoryCard.apk')))!;
      expect(info.downloadUrl, Updates.downloadUrl);
    });
  });

  group('the service', () {
    late AppStore store;
    late DateTime now;
    var asked = 0;
    var answer = release();

    setUpAll(() async {
      final dir = Directory.systemTemp.createTempSync('mc_updates_');
      store = await AppStore.open(path: dir.path);
      // Attaching checks when a day has passed: not here, where nothing may reach the network.
      store.updateSettings((s) => s.updateCheck = false);
      await Updates.i.attach(store, installedVersion: '1.5.0', buildNumber: '10');
    });

    setUp(() {
      now = DateTime(2026, 11, 7, 10, 20);
      asked = 0;
      answer = release();
      store.updateSettings((s) {
        s
          ..updateCheck = true
          ..updateRemind = false
          ..updateSkipped = ''
          ..updateDealt = ''
          ..updateDealtAt = 0
          ..updateChecked = 0
          ..updateLatest = {};
      });
      Updates.i
        ..clearPreview()
        ..forgetTries()
        ..lastOk = null
        ..clock = (() => now)
        ..fetcher = (uri) async {
          asked++;
          expect(uri, Updates.api);
          return answer;
        };
    });

    test('a newer release shows once, dealt once, and Later keeps it waiting', () async {
      expect(Updates.i.available, isFalse);
      await Updates.i.check();
      expect(asked, 1);
      expect(Updates.i.lastOk, isTrue);
      expect(Updates.i.available, isTrue);
      expect(Updates.i.dealPending, isTrue);
      expect(Updates.i.latest!.version, '1.6.0');
      Updates.i.markDealt();
      expect(Updates.i.dealPending, isFalse, reason: 'dealt once per version');
      expect(Updates.i.available, isTrue, reason: 'it still waits in the + fan');
      // The next version deals again.
      answer = release(tag: 'v1.6.1');
      await Updates.i.check();
      expect(Updates.i.dealPending, isTrue);
    });

    test('the version you run is not an update, and neither is an older one', () async {
      answer = release(tag: 'v1.5.0');
      await Updates.i.check();
      expect(Updates.i.available, isFalse);
      answer = release(tag: 'v1.4.1');
      await Updates.i.check();
      expect(Updates.i.available, isFalse);
    });

    test('Skip this version hides it until you undo, and the next version comes back', () async {
      await Updates.i.check();
      Updates.i.skip();
      expect(Updates.i.available, isFalse);
      expect(Updates.i.skipped, isTrue);
      Updates.i.unskip();
      expect(Updates.i.available, isTrue);
      Updates.i.skip();
      answer = release(tag: 'v1.7.0');
      await Updates.i.check();
      expect(Updates.i.available, isTrue);
      expect(Updates.i.skipped, isFalse);
    });

    test('once a day: not again within 20 hours, not at all when switched off, and not within 30 minutes of a failure', () async {
      await Updates.i.maybeCheck();
      expect(asked, 1);
      now = now.add(const Duration(hours: 19));
      await Updates.i.maybeCheck();
      expect(asked, 1, reason: '19 hours is not a day yet');
      now = now.add(const Duration(hours: 2));
      await Updates.i.maybeCheck();
      expect(asked, 2);

      Updates.i.setCheck(false);
      now = now.add(const Duration(days: 3));
      await Updates.i.maybeCheck();
      expect(asked, 2, reason: 'switched off');
      Updates.i.setCheck(true);
      // setCheck(true) checks at once because three days have passed.
      await Future<void>.delayed(Duration.zero);
      expect(asked, 3);

      Updates.i.fetcher = (uri) async {
        asked++;
        throw const SocketException('offline');
      };
      now = now.add(const Duration(days: 2));
      await Updates.i.maybeCheck();
      expect(asked, 4);
      expect(Updates.i.lastOk, isFalse);
      expect(Updates.i.available, isTrue, reason: 'the last answer is kept while offline');
      now = now.add(const Duration(minutes: 10));
      await Updates.i.maybeCheck();
      expect(asked, 4, reason: 'no hammering after a failure');
      now = now.add(const Duration(minutes: 40));
      await Updates.i.maybeCheck();
      expect(asked, 5);
    });

    test('a project with no release yet answers 404: nothing newer, and that counts as a check', () async {
      await Updates.i.check();
      expect(Updates.i.available, isTrue);
      Updates.i.fetcher = (uri) async => throw UpdateHttpException(404);
      await Updates.i.check();
      expect(Updates.i.lastOk, isTrue);
      expect(Updates.i.available, isFalse);
      expect(store.settings.updateChecked, now.millisecondsSinceEpoch);
      Updates.i.fetcher = (uri) async => throw UpdateHttpException(403);
      await Updates.i.check();
      expect(Updates.i.lastOk, isFalse);
    });

    test('the reminder is due 4 days after the card first appeared, at your reminder time, and only once', () async {
      await Updates.i.check();
      expect(Updates.i.reminderAt(), isNull, reason: 'no card yet');
      Updates.i.markDealt();
      expect(Updates.i.reminderAt(), DateTime(2026, 11, 11, 19, 0));
      store.updateSettings((s) => s.remindMinutes = 20 * 60 + 15);
      expect(Updates.i.reminderAt(), DateTime(2026, 11, 11, 20, 15));
      now = DateTime(2026, 11, 12);
      expect(Updates.i.reminderAt(), isNull, reason: 'four days have passed');
      store.updateSettings((s) => s.remindMinutes = 19 * 60);
    });

    test('the preview is never saved and goes away', () {
      expect(Updates.i.available, isFalse);
      Updates.i.startPreview();
      expect(Updates.i.available, isTrue);
      expect(Updates.i.previewing, isTrue);
      expect(Updates.i.latest!.version, '1.6.0');
      expect(Updates.i.dealPending, isFalse);
      Updates.i.markDealt();
      Updates.i.skip();
      expect(store.settings.updateDealt, isEmpty);
      expect(store.settings.updateSkipped, isEmpty);
      Updates.i.clearPreview();
      expect(Updates.i.available, isFalse);
    });

    test('everything survives a restart of the settings', () async {
      await Updates.i.check();
      Updates.i.markDealt();
      Updates.i.skip();
      store.updateSettings((s) => s.updateRemind = true);
      final back = Settings.fromJson(jsonDecode(jsonEncode(store.settings.toJson())) as Map);
      expect(back.updateCheck, isTrue);
      expect(back.updateRemind, isTrue);
      expect(back.updateSkipped, '1.6.0');
      expect(back.updateDealt, '1.6.0');
      expect(back.updateDealtAt, now.millisecondsSinceEpoch);
      expect(back.updateChecked, now.millisecondsSinceEpoch);
      expect(back.updateLatest['v'], '1.6.0');
      expect(UpdateInfo.fromJson(back.updateLatest)!.megabytes, '150 MB');
      // A settings file from before updates existed loads with the defaults.
      final old = Settings.fromJson({'goal': 20});
      expect(old.updateCheck, isTrue);
      expect(old.updateRemind, isFalse);
      expect(old.updateLatest, isEmpty);
    });
  });
}
