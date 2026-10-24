import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/store_scope.dart';
import '../../ui/fx.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../decks/deck_maker.dart';
import '../decks/decks_screen.dart';
import '../drawer/folder_drawer.dart';
import '../editor/editor_sheet.dart';
import '../lab/memory_lab.dart';
import '../profile/profile_screen.dart';
import '../shop/shop_screen.dart';
import '../study/study_screen.dart';
import 'create_menu.dart';
import 'nav_bar.dart';

enum ShellTab { decks, study, shop, lab, account }

/// The app frame: a nested navigator for Decks / Study / Lab / Shop / Account under one persistent nav
/// bar, the folder drawer above it, and the toasts on top.
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
  final _plus = GlobalKey();
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

  void openShop() => _openTab(ShellTab.shop, () => const ShopScreen());

  void openLab() => _openTab(ShellTab.lab, () => const MemoryLab(inShell: true));

  void openAccount() => _openTab(ShellTab.account, () => const ProfileScreen(inShell: true));

  /// A tab already open further down comes back to the top (what was above it closes); otherwise it opens
  /// over the current page, so Back returns there.
  void _openTab(ShellTab t, Widget Function() screen) {
    closeDrawer();
    if (tab == t) return;
    if (_routes.contains(t)) {
      _nav.currentState!.popUntil((r) => r.settings.name == t.name);
      setState(() {
        while (_routes.last != t) {
          _routes.removeLast();
        }
      });
      return;
    }
    _push(t, screen(), t.name);
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

  /// The context-aware "+": in a deck's stack it writes a card for that deck; in the Daily mix, a card for
  /// any deck; everywhere else it asks whether to make a deck or a card.
  Future<void> create() async {
    final store = context.storeRead;
    if (tab == ShellTab.study) {
      createCard();
      return;
    }
    final box = _plus.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      createCard();
      return;
    }
    final pick = await showCreateMenu(context, box.localToGlobal(Offset.zero) & box.size);
    if (!mounted) return;
    if (pick == 'deck') {
      showEditor(context, folderId: store.currentFolder?.id, newDeck: true);
    } else if (pick == 'card') {
      createCard();
    }
  }

  /// The card maker: for the deck being studied, else for any deck (its deck pill picks one).
  void createCard() {
    final store = context.storeRead;
    showEditor(context, deckId: studyDeckId, folderId: store.currentFolder?.id);
  }

  /// The deck maker for an existing deck: its name, look and seals.
  void customizeDeck(String deckId) => openDeckMaker(context, deckId: deckId);

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
        if (!exit || !context.mounted) return;
        // At the decks root, back leaves the app, as on any Android home screen.
        final root = Navigator.of(context);
        if (root.canPop()) {
          root.pop();
        } else {
          SystemNavigator.pop();
        }
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
                diamondKey: _plus,
                onHome: goHome,
                onLab: openLab,
                onCreate: create,
                onShop: openShop,
                onAccount: openAccount,
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
