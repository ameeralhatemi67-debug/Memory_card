import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/store_scope.dart';
import '../../services/reminders.dart';
import '../../services/updates.dart';
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
import 'update_card.dart';

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

class ShellState extends State<Shell> with TickerProviderStateMixin {
  final _nav = GlobalKey<NavigatorState>();
  final _routes = <ShellTab>[ShellTab.decks];
  bool _drawer = false;
  String? _studyDeck;

  /// The + card has dealt New deck / New card ([_deal] runs while they fly out and back).
  bool _menu = false;
  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    reverseDuration: const Duration(milliseconds: 320),
  );

  /// The update card is out (dealt by itself once per new version, or from the + fan). [_updAnim] runs while it
  /// leaves the + card and returns to it.
  bool _upd = false;
  Timer? _dealTimer;
  late final AnimationController _updAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
    reverseDuration: const Duration(milliseconds: 560),
  );

  ShellTab get tab => _routes.last;
  bool get drawerOpen => _drawer;
  bool get createOpen => _menu;
  bool get updateOpen => _upd;
  String? get studyDeckId => tab == ShellTab.study ? _studyDeck : null;

  @override
  void initState() {
    super.initState();
    Shell.current = this;
    Updates.i.addListener(_onUpdates);
    Reminders.i.updateTaps.addListener(_onUpdates);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onUpdates());
  }

  @override
  void dispose() {
    if (Shell.current == this) Shell.current = null;
    Updates.i.removeListener(_onUpdates);
    Reminders.i.updateTaps.removeListener(_onUpdates);
    _dealTimer?.cancel();
    _deal.dispose();
    _updAnim.dispose();
    super.dispose();
  }

  // ---- the update card

  /// What GitHub said changed (or a tapped update reminder): the badge and fan follow, and a card nobody has
  /// seen yet deals itself.
  void _onUpdates() {
    if (!mounted) return;
    setState(() {});
    if (Reminders.i.updateTapPending && Updates.i.available) {
      Reminders.i.updateTapPending = false;
      goHome();
      _dealTimer?.cancel();
      _dealTimer = Timer(const Duration(milliseconds: 500), openUpdate);
      return;
    }
    _maybeDeal();
  }

  /// Once per version, and only while you are on Home with nothing else out.
  void _maybeDeal() {
    if (!mounted || _upd || !Updates.i.dealPending || tab != ShellTab.decks || _menu || _drawer) return;
    _dealTimer?.cancel();
    _dealTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && !_upd && Updates.i.dealPending && tab == ShellTab.decks && !_menu && !_drawer) openUpdate(auto: true);
    });
  }

  void openUpdate({bool auto = false}) {
    if (_upd || !Updates.i.available) return;
    closeDrawer();
    closeCreate();
    if (auto) Updates.i.markDealt();
    Fx.i.deal();
    setState(() => _upd = true);
    _updAnim.forward();
  }

  /// Later: the card goes back into the + (and waits in its fan, with a gold 1).
  void closeUpdate() {
    if (!_upd) return;
    setState(() => _upd = false);
    // A preview (Settings › Updates) is gone once the card is back in the + card.
    _updAnim.reverse().whenComplete(() {
      if (Updates.i.previewing) Updates.i.clearPreview();
    });
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
    closeCreate();
    if (_routes.length > 1) {
      _nav.currentState!.popUntil((r) => r.isFirst);
      setState(() => _routes
        ..clear()
        ..add(ShellTab.decks));
    }
    _maybeDeal();
  }

  void openShop() => _openTab(ShellTab.shop, () => const ShopScreen());

  void openLab() => _openTab(ShellTab.lab, () => const MemoryLab(inShell: true));

  void openAccount() => _openTab(ShellTab.account, () => const ProfileScreen(inShell: true));

  /// A tab already open further down comes back to the top (what was above it closes); otherwise it opens
  /// over the current page, so Back returns there.
  void _openTab(ShellTab t, Widget Function() screen) {
    closeDrawer();
    closeCreate();
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
    closeCreate();
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
      _maybeDeal();
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
  /// any deck; everywhere else the + card deals two cards, New deck and New card (tap it again to take
  /// them back).
  void create() {
    if (tab == ShellTab.study) {
      createCard();
      return;
    }
    _menu ? closeCreate() : openCreate();
  }

  void openCreate() {
    if (_menu) return;
    closeDrawer();
    Fx.i.deal();
    setState(() => _menu = true);
    _deal.forward();
  }

  void closeCreate() {
    if (!_menu) return;
    setState(() => _menu = false);
    _deal.reverse();
  }

  void _pick(String what) {
    final store = context.storeRead;
    Fx.i.pop();
    closeCreate();
    if (what == 'update') {
      openUpdate();
      return;
    }
    if (what == 'deck') {
      showEditor(context, folderId: store.currentFolder?.id, newDeck: true);
    } else {
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
    if (_upd) {
      closeUpdate();
      return false;
    }
    if (_menu) {
      closeCreate();
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
    final upd = Updates.i.available ? Updates.i.latest : null;
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
            // The page dims while the + card's two cards are out; the hand stays above it, live.
            // (Always a positioned child: an empty unpositioned one would shrink the whole stack.)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _deal,
                builder: (context, child) => _deal.isDismissed ? const SizedBox.shrink() : child!,
                child: CreateDim(anim: _deal, onClose: closeCreate),
              ),
            ),
            // The same dimming while the update card is out; the hand stays above it so the + card is its origin.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _updAnim,
                builder: (context, child) => _updAnim.isDismissed ? const SizedBox.shrink() : child!,
                child: CreateDim(anim: _updAnim, onClose: closeUpdate),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: navH,
              child: NavBar(
                current: tab,
                open: _menu,
                badge: upd != null,
                onHome: goHome,
                onLab: openLab,
                onCreate: create,
                onShop: openShop,
                onAccount: openAccount,
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _deal,
                builder: (context, child) => _deal.isDismissed ? const SizedBox.shrink() : child!,
                child: CreateDeal(
                  anim: _deal,
                  onPick: _pick,
                  update: upd?.version,
                  updateNote: upd == null ? '' : '${upd.version}${upd.megabytes.isEmpty ? '' : ' · ${upd.megabytes}'}',
                ),
              ),
            ),
            if (upd != null)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _updAnim,
                  builder: (context, child) => _updAnim.isDismissed ? const SizedBox.shrink() : child!,
                  child: UpdateCardLayer(anim: _updAnim, info: upd, installed: Updates.i.installed, onLater: closeUpdate),
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
