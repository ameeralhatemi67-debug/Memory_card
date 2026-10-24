import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/app.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/features/settings/widgets_screen.dart';
import 'package:memory_card/services/home_widgets.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';

/// Settings › Widgets: the look controls change the settings the widgets are drawn from, and each widget row opens.
void main() {
  setUpAll(() => T.googleFonts = false);

  testWidgets('the look controls change the settings, and a widget row opens to its face and layout choices', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('mc_widgets_ui_');
    final store = (await tester.runAsync(() => AppStore.open(path: dir.path)))!;
    store.setOnboarded();
    await tester.pumpWidget(MemoryCardApp(store: store));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(WidgetsScreen.route());
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Widgets'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Accent'), findsOneWidget);

    // Theme, corners and accent land in the settings the snapshot reads.
    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.settings.widgetTheme, 'dark');
    await tester.tap(find.text('Square'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.settings.widgetCorners, 'square');
    await tester.tap(find.bySemanticsLabel('blue accent'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.settings.widgetAccent, 'blue');

    // Every widget is listed with its sizes; one opens to its face, and the Quick card to its layout too.
    for (final name in HomeWidgets.kinds.values) {
      await tester.scrollUntilVisible(find.text(name), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text(name), findsOneWidget, reason: name);
    }
    await tester.scrollUntilVisible(find.text('Quick card'), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Quick card'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Quick card'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(find.text('Side by side'), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Side by side'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Face'), findsOneWidget);
    expect(find.text('Side by side'), findsOneWidget);
    await tester.tap(find.text('Ink'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.settings.widgetSurfaces['quick'], 'ink');
    await tester.tap(find.text('Side by side'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.settings.widgetQuick, 'side');
    await tester.tap(find.text('As designed'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.settings.widgetSurfaces.containsKey('quick'), isFalse);

    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
