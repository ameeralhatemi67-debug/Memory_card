import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/ui/icons.dart';
import 'package:memory_card/ui/theme.dart';

/// Draws the launcher icons from the app's own logo (the three fanned cards, paper on ink) into
/// android/app/src/main/res. Run after changing the logo:  flutter test test_gallery/icon_gen_test.dart
void main() {
  const ink = Color(0xFF333333);
  const res = 'android/app/src/main/res';
  const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

  Future<void> render(WidgetTester tester, Widget art, double dp, Map<String, String> outs) async {
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(key: key, child: SizedBox(width: dp, height: dp, child: art)),
      ),
    ));
    // The SVG decodes off the frame: let it finish, then paint.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    for (final MapEntry(key: density, value: name) in outs.entries) {
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: densities[density]!);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        final dir = name.startsWith('ic_stat') ? 'drawable' : 'mipmap';
        final f = File('$res/$dir-$density/$name.png')..createSync(recursive: true);
        f.writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  }

  Widget logo(double h, Color color) => Center(child: McIcon(McIcons.logo, size: Size(h * 11.211 / 14.182, h), color: color));

  testWidgets('launcher icons', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Adaptive icon layers: 108 dp, the logo inside the 66 dp safe circle.
    for (final d in densities.keys) {
      await render(tester, logo(46, Mc.paper), 108, {d: 'ic_launcher_foreground'});
      await render(tester, logo(46, Colors.white), 108, {d: 'ic_launcher_monochrome'});
    }
    // Legacy square and round icons for Android 7 and older launchers.
    for (final d in densities.keys) {
      await render(
        tester,
        DecoratedBox(
          decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(11)),
          child: logo(27, Mc.paper),
        ),
        48,
        {d: 'ic_launcher'},
      );
      await render(
        tester,
        DecoratedBox(decoration: const BoxDecoration(color: ink, shape: BoxShape.circle), child: logo(25, Mc.paper)),
        48,
        {d: 'ic_launcher_round'},
      );
    }
    // Status-bar icon for the reminder: white on transparent, 24 dp.
    for (final d in densities.keys) {
      await render(tester, logo(21, Colors.white), 24, {d: 'ic_stat_cards'});
    }
    // Web: favicon, PWA icons (the maskable ones keep the logo inside the 80 % safe zone).
    Future<void> web(Widget art, double size, String path) async {
      final key = GlobalKey();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: RepaintBoundary(key: key, child: SizedBox(width: size, height: size, child: art))),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(path).writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    for (final s in [192.0, 512.0]) {
      await web(
        DecoratedBox(
          decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(s * 0.22)),
          child: logo(s * 0.56, Mc.paper),
        ),
        s,
        'web/icons/Icon-${s.toInt()}.png',
      );
      await web(const ColoredBox(color: ink).wrapLogo(logo(s * 0.42, Mc.paper)), s, 'web/icons/Icon-maskable-${s.toInt()}.png');
    }
    await web(
      DecoratedBox(decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(7)), child: logo(20, Mc.paper)),
      32,
      'web/favicon.png',
    );
    await tester.pumpWidget(const SizedBox());
  });
}

extension on ColoredBox {
  /// A full-bleed coloured square with [child] centred on it.
  Widget wrapLogo(Widget child) => Stack(fit: StackFit.expand, children: [this, child]);
}
