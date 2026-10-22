import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'data/store.dart';
import 'features/onboarding/splash.dart';
import 'services/reminders.dart';
import 'ui/fx.dart';
import 'ui/icons.dart';
import 'ui/textures.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  runApp(const Boot());
}

/// Opens the store, warms the fonts and sounds behind the splash, then hands over to the app.
class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  AppStore? _store;
  bool _splashDone = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final store = await AppStore.open();
      Fx.i
        ..sounds = store.settings.sounds
        ..haptics = store.settings.haptics;
      unawaited(Fx.i.init());
      // Icons decode once, here, so the first screen appears complete.
      unawaited(McIcons.precache().catchError((Object _) => <void>[]));
      // Texture maps in use decode now, so the first screen has its wall.
      unawaited(Textures.i.preload(store.settings.texture));
      // Text fonts download once (then they are cached); never wait more than 2.5 s for them.
      try {
        await GoogleFonts.pendingFonts(T.preload()).timeout(const Duration(milliseconds: 2500));
      } catch (_) {}
      unawaited(Reminders.i.init(store));
      if (mounted) setState(() => _store = store);
    } catch (e, st) {
      debugPrint('Memory Card failed to open: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store != null && _splashDone) return MemoryCardApp(store: store);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Mc.theme(Mc.light),
      darkTheme: Mc.theme(Mc.darkTheme),
      home: Splash(
        ready: store != null,
        error: _error,
        onDone: () => setState(() => _splashDone = true),
      ),
    );
  }
}
