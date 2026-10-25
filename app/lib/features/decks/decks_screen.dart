import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../ui/coach.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/shapes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../browse/deck_browser.dart';
import '../editor/editor_sheet.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/nav_bar.dart';
import '../shell/shell.dart';
import '../today/today_screen.dart';
import 'deck_motion.dart';
import 'deck_row.dart';
import 'empty_folder.dart';

/// The home screen (canvas Main.dc.html): the decks of the current folder.
class DecksScreen extends StatefulWidget {
  const DecksScreen({super.key});

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  String? _highlight;
  String? _folderShown;

  /// The list has scrolled under the header: decks fade out at the top edge instead of being cut.
  bool _scrolled = false;

  /// Bumped when a deck leaves the list or is pinned, so the other decks spring to their new places.
  int _flipEpoch = 0;
  _FlipPlan? _plan;

  void _flip(_FlipPlan plan) {
    _plan = plan;
    _flipEpoch++;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final folder = store.currentFolder;
    final decks = folder == null ? <Deck>[] : store.decksIn(folder);
    final lib = store.libraryStats();
    final streak = store.engine.liveStreak();
    final top = mq.padding.top;
    final navH = NavBar.height + mq.padding.bottom;
    final mix = store.buildMix(max: 60);
    final mixDecks = mix.map((e) => e.$1).toSet().length;
    final showMix = folder != null && !folder.isArchive && mix.length >= 5 && mixDecks >= 2;
    final firstVisit = !store.coachSeen('deck-swipe') && decks.isNotEmpty;
    if (_folderShown != folder?.id) {
      _folderShown = folder?.id;
      _scrolled = false;
      openDeck.value = null;
    }

    return Scaffold(
      backgroundColor: mc.canvas,
      body: Wall(child: Stack(
        children: [
          Positioned.fill(
            top: top + 88,
            child: folder == null || decks.isEmpty
                ? EmptyFolder(folder: folder, bottom: navH)
                : EdgeFade(
                    // Melts into the wall: at the top once scrolled, and above the nav bar.
                    top: _scrolled ? 22 : 0,
                    bottom: 110,
                    bottomInset: navH,
                    child: NotificationListener<ScrollUpdateNotification>(
                    onNotification: (n) {
                      final s = n.metrics.pixels > 2;
                      if (s != _scrolled) setState(() => _scrolled = s);
                      return false;
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: ListView(
                        key: ValueKey(folder.id),
                        padding: EdgeInsets.only(bottom: navH + 120),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          if (showMix)
                            Cascade(
                              index: 0,
                              child: _MixRow(
                                count: mix.length,
                                decks: mixDecks,
                                onTap: () => Shell.of(context).study(null),
                              ),
                            ),
                          for (var i = 0; i < decks.length; i++)
                            Cascade(
                              key: ValueKey(decks[i].id),
                              index: i + (showMix ? 1 : 0),
                              child: FlipSlot(
                                epoch: _flipEpoch,
                                spec: _plan?.specFor(i, decks),
                                skip: _plan?.pinId == decks[i].id,
                                child: DeckRow(
                                  deck: decks[i],
                                  stats: store.stats(decks[i]),
                                  archived: folder.isArchive,
                                  demo: firstVisit && i == 0,
                                  highlight: _highlight == decks[i].id,
                                  onOpen: () => Shell.of(context).study(decks[i].id),
                                  onDelete: () {
                                    // Delete A: the others close the gap just after the deck bursts.
                                    _flip(_FlipPlan.leaves(i, delay: 0.06, stagger: 0.05, z: 0.72, w: 17));
                                    _delete(store, decks[i]);
                                  },
                                  onArchive: () {
                                    // Archive B: they follow in a bouncy wave.
                                    _flip(_FlipPlan.leaves(i, delay: 0, stagger: 0.06, z: 0.5, w: 20));
                                    _archive(store, decks[i], folder);
                                  },
                                  onMove: () => _move(context, store, decks[i]),
                                  onMoveTo: (fid) {
                                    // Move D: they close the gap as the deck is hauled out of sight.
                                    _flip(_FlipPlan.leaves(i, delay: 0, stagger: 0.06, z: 0.6, w: 14));
                                    _moveTo(store, decks[i], fid);
                                  },
                                  onPin: () {
                                    // Pin A: the decks above make room, the top one first.
                                    _flip(decks[i].pinned
                                        ? _FlipPlan.all(z: 0.8, w: 16)
                                        : _FlipPlan.pinned(decks[i].id, delay: 0.06, stagger: 0.05, z: 0.8, w: 16));
                                    store.togglePin(decks[i].id);
                                  },
                                  skin: store.skinOf(decks[i]),
                                ),
                              ),
                            ),
                          if (firstVisit) _Hint(onSeen: () => store.markCoach('deck-swipe')),
                        ],
                      ),
                    ),
                  ),
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: top,
            child: _Header(
              title: folder?.name ?? 'Memory Card',
              streak: streak,
              due: lib.slipping,
              onDrawer: () => Shell.of(context).openDrawer(),
              onStreak: () => Navigator.of(context, rootNavigator: true).push(TodayScreen.route()),
              onMenu: () => _menu(context, store, folder),
            ),
          ),
        ],
      )),
    );
  }

  void _delete(AppStore store, Deck d) {
    final undo = store.deleteDeck(d.id);
    Toaster.i.show('Deleted ${d.name}', undo: undo);
  }

  void _archive(AppStore store, Deck d, Folder from) {
    final undo = store.archiveDeck(d.id);
    Toaster.i.show(from.isArchive ? 'Restored ${d.name}' : 'Archived ${d.name}', undo: undo);
  }

  void _moveTo(AppStore store, Deck d, String folderId) {
    final to = store.data.folderById(folderId);
    if (to == null) return;
    final undo = store.moveDeck(d.id, folderId);
    Toaster.i.show('Moved to ${to.name}', undo: undo);
  }

  Future<void> _move(BuildContext context, AppStore store, Deck d) async {
    final from = store.data.folderOf(d.id);
    final fid = await pickFolder(context, title: 'Move to…', subtitle: d.name, exclude: {if (from != null) from.id});
    if (fid == null) return;
    final to = store.data.folderById(fid)!;
    final undo = store.moveDeck(d.id, fid);
    Toaster.i.show('Moved to ${to.name}', undo: undo);
  }

  void _menu(BuildContext context, AppStore store, Folder? folder) {
    final nav = Navigator.of(context, rootNavigator: true);
    showMcMenu(context, [
      MenuItemData("Today's progress", () => nav.push(TodayScreen.route()), icon: McIcons.done),
      MenuItemData('Search all cards', () => nav.push(SearchScreen.route()), icon: McIcons.search),
      if (folder != null) ...[
        MenuItemData(
          'New deck in ${folder.name}',
          () => showEditor(context, folderId: folder.id, newDeck: true),
          icon: McIcons.plus,
        ),
        MenuItemData(
          'Import cards (CSV)',
          () => showEditor(context, folderId: folder.id, startOnImport: true),
          icon: McIcons.list,
        ),
        if (!folder.isArchive)
          MenuItemData('Rename folder', () async {
            final name = await promptText(context, title: 'Rename folder', initial: folder.name);
            if (name != null) store.renameFolder(folder.id, name);
          }, icon: McIcons.newFolder),
      ],
      MenuItemData(Mc.of(context).dark ? 'Light mode' : 'Dark mode', () {
        final dark = Mc.of(context).dark;
        store.updateSettings((s) => s.theme = dark ? 'light' : 'dark');
      }, icon: McIcons.sun),
      MenuItemData('Settings', () => nav.push(SettingsScreen.route()), icon: McIcons.gear),
    ]);
  }
}

/// How the rows of the list reorganise after one change (see [FlipSlot]).
class _FlipPlan {
  const _FlipPlan._(this.at, this.pinId, this.delay, this.stagger, this.z, this.w);

  /// A deck at list index [at] left: every row from there on moves up, the nearest first.
  const _FlipPlan.leaves(int at, {required double delay, required double stagger, required double z, required double w})
      : this._(at, null, delay, stagger, z, w);

  /// The deck [id] was pinned to the front: the rows between its new and its old place move down, the one next to
  /// the front first. The pinned deck itself is flown by an overlay.
  const _FlipPlan.pinned(String id, {required double delay, required double stagger, required double z, required double w})
      : this._(-1, id, delay, stagger, z, w);

  /// Everything simply springs to where it now is (a deck was unpinned).
  const _FlipPlan.all({required double z, required double w}) : this._(-2, null, 0, 0, z, w);

  final int at;
  final String? pinId;
  final double delay, stagger, z, w;

  FlipSpec? specFor(int i, List<Deck> decks) {
    if (at == -2) return FlipSpec(z: z, w: w);
    if (pinId != null) {
      final to = decks.indexWhere((d) => d.id == pinId);
      if (i <= to) return null;
      return FlipSpec(delay: delay + stagger * (i - to - 1), z: z, w: w);
    }
    if (i < at) return null;
    return FlipSpec(delay: delay + stagger * (i - at), z: z, w: w);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.streak,
    required this.due,
    required this.onDrawer,
    required this.onStreak,
    required this.onMenu,
  });

  final String title;
  final int streak;
  final int due;
  final VoidCallback onDrawer;
  final VoidCallback onStreak;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return SizedBox(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 16, 0),
        child: Row(
          children: [
            CoachTarget(
              id: 'drawer',
              text: 'Your folders live here',
              child: IconTap(icon: McIcons.logo, label: 'Open folders', onTap: onDrawer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onDrawer,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.d(24, color: mc.ink),
                  ),
                ),
              ),
            ),
            Pressable(
              onTap: onStreak,
              label: 'Streak $streak days, $due cards slipping',
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
                decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
                child: Row(
                  children: [
                    const SizedBox(width: 14, height: 16, child: CustomPaint(painter: FlamePainter())),
                    const SizedBox(width: 6),
                    Text(
                      '$streak',
                      style: T.t(15, w: FontWeight.w600, color: mc.ink),
                    ),
                    Text(
                      ' · $due due',
                      style: T.t(15, w: FontWeight.w600, color: mc.muted),
                    ),
                  ],
                ),
              ),
            ),
            IconTap(icon: McIcons.dots, label: 'Menu', size: const Size(8, 26), onTap: onMenu),
          ],
        ),
      ),
    );
  }
}

/// "Daily mix": every slipping card across your decks, most urgent first.
class _MixRow extends StatelessWidget {
  const _MixRow({required this.count, required this.decks, required this.onTap});
  final int count;
  final int decks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final width = MediaQuery.of(context).size.width;
    final barW = math.min(width - 40, 520.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Pressable(
          onTap: onTap,
          haptic: true,
          label: 'Daily mix, $count slipping cards from $decks decks',
          child: Container(
            width: barW,
            height: 72,
            decoration: BoxDecoration(
              color: mc.soft,
              borderRadius: BorderRadius.circular(10),
              boxShadow: mc.e1,
              border: Border.all(color: mc.ink, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Three cards from different decks, fanned.
                for (var i = 0; i < 3; i++)
                  Positioned(
                    right: 6 + (2 - i) * 18.0,
                    bottom: -34 + i * 6.0,
                    child: Transform.rotate(
                      alignment: Alignment.bottomRight,
                      angle: (-14 + i * 7) * math.pi / 180,
                      child: Container(
                        width: 50,
                        height: 76,
                        decoration: BoxDecoration(
                          color: [Mc.blue, Mc.peach, Mc.red][i],
                          borderRadius: BorderRadius.circular(7),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(-2, 0))],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  top: 11,
                  right: 100,
                  child: Text('Daily mix', style: T.d(23, color: mc.ink, height: 1.05)),
                ),
                Positioned(
                  left: 16,
                  bottom: 11,
                  right: 100,
                  child: Text(
                    '$count slipping · from $decks decks',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.t(13, w: FontWeight.w600, color: mc.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatefulWidget {
  const _Hint({required this.onSeen});
  final VoidCallback onSeen;

  @override
  State<_Hint> createState() => _HintState();
}

class _HintState extends State<_Hint> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) widget.onSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
      child: Text(
        'Tip: tap a deck to study. Swipe it sideways for delete, archive, move and pin.',
        textAlign: TextAlign.center,
        style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.35),
      ),
    );
  }
}

/// Lets you pick a folder (or make a new one). Returns its id.
Future<String?> pickFolder(
  BuildContext context, {
  required String title,
  String? subtitle,
  Set<String> exclude = const {},
}) {
  final store = context.storeRead;
  return showMcSheet<String>(
    context,
    expand: false,
    builder: (ctx) {
      final mc = Mc.of(ctx);
      final folders = store.data.folders.where((f) => !exclude.contains(f.id)).toList();
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: T.d(30, color: mc.ink)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: T.t(15, w: FontWeight.w600, color: mc.muted),
              ),
            ],
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < folders.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Pressable(
                        onTap: () => Navigator.pop(ctx, folders[i].id),
                        child: Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: mc.soft,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: mc.e1,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: folderShade(i, mc.dark).c1,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(folders[i].name, style: T.d(22, color: mc.ink)),
                              ),
                              Text(
                                '${folders[i].deckIds.length} decks',
                                style: T.t(14, w: FontWeight.w600, color: mc.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SoftButton(
              '+ New folder',
              onTap: () async {
                final name = await promptText(ctx, title: 'Name the folder', initial: 'New folder');
                if (name == null || !ctx.mounted) return;
                final f = store.createFolder(name, atTop: false);
                Fx.i.pop();
                Navigator.pop(ctx, f.id);
              },
            ),
          ],
        ),
      );
    },
  );
}

/// Opens the deck browser for [deckId] (used from menus).
void openDeckBrowser(BuildContext context, String deckId) =>
    Navigator.of(context, rootNavigator: true).push(DeckBrowser.route(deckId));
