import 'package:flutter/material.dart';

import '../../data/store_scope.dart';
import '../../ui/fx.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../decks/decks_screen.dart';
import '../drawer/folder_drawer.dart';
import '../editor/editor_sheet.dart';
import '../shop/shop_screen.dart';
import '../study/study_screen.dart';
import 'nav_bar.dart';

enum ShellTab { decks, study, shop }

/// The app frame: a nested navigator for Decks / Study / Shop under one persistent nav bar, the folder
/// drawer above it, and the toasts on top.
class Shell extends StatefulWidget {
  const Shell({super.key});

  static ShellState of(BuildContext context) => context.findAncestorStateOfType<ShellState>() ?? current!;

  /// Screens pushed above the shell (Today, Profile…) reach it through here.
  static ShellState? maybeOf(BuildContext context) => context.findAncestorStateOfType<ShellState>() ?? current;

  static ShellState? current;

  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  final _nav = GlobalKey<NavigatorState>();
  final _routes = <ShellTab>[ShellTab.decks];
  bool _drawer = false;
  String? _studyDeck;

  ShellTab get tab => _routes.last;
  bool get drawerOpen => _drawer;
  String? get studyDeckId => tab == ShellTab.study ? _studyDeck : null;

  @override
  void initState() {
    super.initState();
    Shell.current = this;
  }

  @override
  void dispose() {
    if (Shell.current == this) Shell.current = null;
    super.dispose();
  }

  // ---- navigation ----

  void openDrawer() {
    if (_drawer) return;
    Fx.i.whoosh();
    setState(() => _drawer = true);
  }

  void closeDrawer() {
    if (!_drawer) return;
    setState(() => _drawer = false);
  }

  void goHome() {
    closeDrawer();
    if (_routes.length > 1) {
      _nav.currentState!.popUntil((r) => r.isFirst);
      setState(() => _routes
        ..clear()
        ..add(ShellTab.decks));
    }
  }

  void openShop() {
    closeDrawer();
    if (tab == ShellTab.shop) return;
    if (_routes.contains(ShellTab.shop)) {
      _nav.currentState!.popUntil((r) => r.settings.name == 'shop');
      setState(() {
        while (_routes.last != ShellTab.shop) {
          _routes.removeLast();
        }
      });
      return;
    }
    _push(ShellTab.shop, const ShopScreen(), 'shop');
  }

  /// Opens a deck's study stack ([deckId] null = the cross-deck daily mix).
  void study(String? deckId) {
    closeDrawer();
    final screen = StudyScreen(key: ValueKey('study-$deckId-${DateTime.now().millisecondsSinceEpoch}'), deckId: deckId);
    if (tab == ShellTab.study) {
      _studyDeck = deckId;
      _nav.currentState!.pushReplacement(_route(screen, 'study'));
      setState(() {});
      return;
    }
    _studyDeck = deckId;
    _push(ShellTab.study, screen, 'study');
  }

  void _push(ShellTab t, Widget screen, String name) {
    setState(() => _routes.add(t));
    _nav.currentState!.push(_route(screen, name)).then((_) {
      if (mounted && _routes.length > 1 && _routes.last == t) setState(() => _routes.removeLast());
    });
  }

  PageRoute _route(Widget screen, String name) => PageRouteBuilder(
        settings: RouteSettings(name: name),
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, a, b) => screen,
        transitionsBuilder: (context, a, b, child) {
          final reduced = MotionPrefs.reducedOf(context);
          final c = CurvedAnimation(parent: a, curve: McCurves.out, reverseCurve: Curves.easeInCubic);
          if (reduced) return FadeTransition(opacity: c, child: child);
          return FadeTransition(
            opacity: c,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(c),
              child: child,
            ),
          );
        },
      );

  /// The context-aware "+": in a study stack it adds to that deck, elsewhere it asks.
  void create() {
    final store = context.storeRead;
    showEditor(context, deckId: studyDeckId, folderId: store.currentFolder?.id);
  }

  Future<bool> _onBack() async {
    if (_drawer) {
      closeDrawer();
      return false;
    }
    if (_nav.currentState?.canPop() ?? false) {
      _nav.currentState!.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navH = NavBar.height + mq.padding.bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await _onBack();
        if (exit && context.mounted) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: HeroControllerScope(
                controller: MaterialApp.createMaterialHeroController(),
                child: Navigator(
                  key: _nav,
                  onGenerateRoute: (s) => PageRouteBuilder(
                    settings: const RouteSettings(name: 'decks'),
                    pageBuilder: (context, a, b) => const DecksScreen(),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: navH,
              child: NavBar(
                current: tab,
                onHome: goHome,
                onCreate: create,
                onShop: openShop,
              ),
            ),
            Positioned.fill(child: FolderDrawer(open: _drawer, onClose: closeDrawer)),
            ToastHost(bottom: _drawer ? 96 : navH + 12),
          ],
        ),
      ),
    );
  }
}
