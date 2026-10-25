import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/features/settings/updates_screen.dart';
import 'package:memory_card/services/updates.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';

String release(String tag) => jsonEncode({
      'tag_name': tag,
      'body': '- **Smarter reminders** that say the real minutes\n- A Today strip on Home\n- Fix: widgets keep their size',
      'html_url': 'https://github.com/${Updates.repo}/releases/tag/$tag',
      'assets': [
        {'name': 'MemoryCard.apk', 'size': 150123456, 'browser_download_url': 'https://github.com/${Updates.repo}/releases/download/$tag/MemoryCard.apk'},
      ],
    });

/// The update card in the app: a new version deals the card out of the + once, Later parks it in the + fan with a
/// gold 1, the fan's Update card brings it back, and Settings › Updates reports, checks and skips.
void main() {
  setUpAll(() => T.googleFonts = false);

  testWidgets('a new version deals the card once, Later parks it in the + fan, and Settings › Updates follows', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final dir = Directory.systemTemp.createTempSync('mc_updates_ui_');
    final store = (await tester.runAsync(() => AppStore.open(path: dir.path)))!;
    store.setOnboarded();
    for (final id in ['drawer', 'shop-hold', 'study-swipe', 'deck-swipe']) {
      store.markCoach(id);
    }
    var asked = 0;
    Updates.i.fetcher = (uri) async {
      asked++;
      return release('v1.6.0');
    };
    store.updateSettings((s) => s.updateCheck = false);
    await tester.runAsync(() async {
      await Updates.i.attach(store, installedVersion: '1.5.0', buildNumber: '10');
      await Updates.i.check();
    });
    expect(Updates.i.available, isTrue);
    expect(asked, 1);

    Future<void> run(double seconds) async {
      for (var i = 0; i < (seconds * 30).round(); i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    await tester.pumpWidget(MemoryCardApp(store: store));
    await run(0.5);
    // Not dealt yet, but the + card already wears the gold 1.
    expect(find.text('Update now'), findsNothing);
    expect(find.bySemanticsLabel('Create, one update waiting'), findsOneWidget);
    expect(find.text('1'), findsOneWidget, reason: 'the gold 1 on the + card');

    // It deals itself out of the + a moment later, once.
    await run(2.4);
    expect(find.text('1.6.0'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Smarter reminders that say the real minutes'), findsOneWidget);
    expect(find.text('You have 1.5.0 · 150 MB · Wi-Fi is kind'), findsOneWidget);
    expect(store.settings.updateDealt, '1.6.0');

    // Update now: three taps in the browser, and back.
    await tester.tap(find.text('Update now'));
    await run(0.3);
    expect(find.text('Three taps, then done'), findsOneWidget);
    expect(find.text('Open GitHub'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await run(0.3);
    expect(find.text('Update now'), findsOneWidget);

    // Later: the card goes back into the + card.
    await tester.tap(find.text('Later'));
    await run(1.2);
    expect(find.text('Update now'), findsNothing);
    expect(Updates.i.available, isTrue, reason: 'Later does not skip');

    // The + fan now deals three cards: New deck, Update, New card.
    await tester.tap(find.bySemanticsLabel('Create, one update waiting'));
    await run(1.5);
    expect(find.text('New deck'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('1.6.0 · 150 MB'), findsOneWidget);
    expect(find.text('New card'), findsOneWidget);

    // The Update card brings the notes back, and it does not deal itself a second time.
    await tester.tap(find.text('Update'));
    await run(1.5);
    expect(find.text('Update now'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await run(1.2);
    expect(find.text('Update now'), findsNothing);
    expect(Updates.i.dealPending, isFalse);

    // Settings › Updates.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(UpdatesScreen.route());
    await run(1.0);
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Memory Card 1.5.0'), findsOneWidget);
    expect(find.text('1.6.0 is available · 150 MB'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('HOW YOU HEAR ABOUT IT'), findsOneWidget);

    await tester.tap(find.text('Check now'));
    await tester.pump(const Duration(milliseconds: 50));
    await run(0.4);
    expect(asked, 2);

    await tester.tap(find.text('Skip this version'));
    await run(0.4);
    expect(store.settings.updateSkipped, '1.6.0');
    expect(find.text('1.6.0 is out, and you skipped it.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('SKIPPED VERSION'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Undo'));
    await run(0.4);
    expect(store.settings.updateSkipped, isEmpty);
    await tester.scrollUntilVisible(find.text('WHAT IT SENDS'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Nothing downloads without your tap'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await run(0.4);
    expect(find.text('1.6.0 is available · 150 MB'), findsOneWidget);

    semantics.dispose();
    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  test('the date line under the version', () {
    final now = DateTime(2026, 11, 7, 12);
    expect(UpdatesScreen.when(DateTime(2026, 11, 7, 9, 5).millisecondsSinceEpoch, now), 'today, 09:05');
    expect(UpdatesScreen.when(DateTime(2026, 11, 6, 23, 59).millisecondsSinceEpoch, now), 'yesterday, 23:59');
    expect(UpdatesScreen.when(DateTime(2026, 11, 3, 8).millisecondsSinceEpoch, now), '3 Nov');
  });
}
