import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'data/store_scope.dart';
import 'features/onboarding/onboarding.dart';
import 'features/profile/profile_screen.dart';
import 'features/search/search_screen.dart';
import 'features/shell/shell.dart';
import 'features/today/today_screen.dart';
import 'services/home_widgets.dart';
import 'services/reminders.dart';
import 'services/updates.dart';
import 'ui/motion.dart';
import 'ui/textures.dart';
import 'ui/theme.dart';

class MemoryCardApp extends StatefulWidget {
  const MemoryCardApp({super.key, required this.store});
  final AppStore store;

  @override
  State<MemoryCardApp> createState() => _MemoryCardAppState();
}

class _MemoryCardAppState extends State<MemoryCardApp> with WidgetsBindingObserver {
  static final _light = Mc.theme(Mc.light);
  static final _dark = Mc.theme(Mc.darkTheme);

  Timer? _dayTimer;
  final _nav = GlobalKey<NavigatorState>();
  late String _theme = widget.store.settings.theme;
  late bool _reduced = widget.store.settings.reducedMotion;
  late bool _onboarded = widget.store.data.onboarded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_onStore);
    Textures.i.update(widget.store.settings.texture);
    _dayTimer = Timer.periodic(const Duration(seconds: 30), (_) => widget.store.tickDay());
    HomeWidgets.i.listen(_fromWidget);
  }

  /// A home-screen widget was tapped: memorycard://study (optionally ?deck=…), today, mix (the Daily mix), new
  /// (a new card), search, profile, lab (Memory Lab) or seals.
  void _fromWidget(Uri uri) {
    final store = widget.store;
    final shell = Shell.current;
    if (shell == null) return;
    _nav.currentState?.popUntil((r) => r.isFirst);
    switch (uri.host) {
      case 'study':
        final id = uri.queryParameters['deck'] ?? store.data.today?.lastDeck ?? store.data.lastDeckId;
        if (id != null && store.data.decks.containsKey(id)) {
          shell.study(id);
        } else {
          shell.goHome();
        }
      case 'mix':
        shell.study(null);
      case 'new':
        shell.goHome();
        shell.createCard();
      case 'today':
        _nav.currentState?.push(TodayScreen.route());
      case 'search':
        _nav.currentState?.push(SearchScreen.route());
      case 'profile':
        shell.openAccount();
      case 'lab':
        shell.openLab();
      case 'seals':
        final ctx = _nav.currentContext;
        if (ctx != null) showSealGallery(ctx, store);
    }
  }

  /// Only theme, motion and onboarding changes rebuild the app root; everything else rebuilds locally.
  void _onStore() {
    final s = widget.store.settings;
    Textures.i.update(s.texture);
    if (s.theme != _theme || s.reducedMotion != _reduced || widget.store.data.onboarded != _onboarded) {
      setState(() {
        _theme = s.theme;
        _reduced = s.reducedMotion;
        _onboarded = widget.store.data.onboarded;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_onStore);
    _dayTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      widget.store.flush();
      Reminders.i.reschedule(widget.store);
      HomeWidgets.i.publish();
    } else if (state == AppLifecycleState.resumed) {
      // Quick card answers given meanwhile count for their own day before a new day starts.
      HomeWidgets.i.catchUp().whenComplete(widget.store.tickDay);
      // Once a day (it ignores the call when one was made less than 20 hours ago).
      unawaited(Updates.i.maybeCheck());
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = switch (_theme) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
    return StoreScope(
      store: widget.store,
      child: MaterialApp(
        navigatorKey: _nav,
        debugShowCheckedModeBanner: false,
        title: 'Memory Card',
        theme: _light,
        darkTheme: _dark,
        themeMode: mode,
        themeAnimationDuration: const Duration(milliseconds: 350),
        themeAnimationCurve: McCurves.paper,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final reduced = _reduced || mq.disableAnimations;
          final dark = Theme.of(context).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
            ),
            child: MotionPrefs(
              reduced: reduced,
              // Text grows with the OS setting, within what the card layouts can hold.
              child: MediaQuery(
                data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3)),
                // Paper grain and vignette sit over everything when they are on.
                child: TextureScope(child: Stack(children: [child!, const Positioned.fill(child: GrainOverlay())])),
              ),
            ),
          );
        },
        home: RootGate(onboarded: _onboarded),
      ),
    );
  }
}

/// First launch → onboarding. Afterwards → the app.
class RootGate extends StatelessWidget {
  const RootGate({super.key, required this.onboarded});
  final bool onboarded;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: McCurves.out,
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: onboarded ? const Shell(key: ValueKey('shell')) : const Onboarding(key: ValueKey('onboarding')),
    );
  }
}
