import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/catalog.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../engine/days.dart';
import '../../ui/coach.dart';
import '../../ui/deck_look.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/shapes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../settings/settings_screen.dart';
import '../shell/nav_bar.dart';
import '../shell/shell.dart';
import 'preview_sheet.dart';
import 'shop_tile.dart';

enum _Sort { featured, name, size }

/// The shop (canvas Shop.dc.html): every bundled deck, by category, with search, a featured deck and
/// press-and-hold quick actions.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _query = TextEditingController();
  String _cat = 'all';
  _Sort _sort = _Sort.featured;
  bool _hideAdded = false;
  String? _similarTo;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() => _similarTo = null));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<CatalogDeck> _filter(AppStore store) {
    final q = _query.text.trim().toLowerCase();
    var decks = store.catalog.decks.where((d) {
      if (_cat != 'all' && d.category != _cat) return false;
      if (_hideAdded && store.data.shopAdded.containsKey(d.id)) return false;
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          d.description.toLowerCase().contains(q) ||
          d.cards.any((c) => c.front.toLowerCase().contains(q) || c.back.toLowerCase().contains(q));
    }).toList();
    if (_similarTo != null) {
      final base = store.catalog.byId(_similarTo!);
      if (base != null) decks = [base, ...store.catalog.similarTo(base)];
    }
    switch (_sort) {
      case _Sort.name:
        decks.sort((a, b) => a.name.compareTo(b.name));
      case _Sort.size:
        decks.sort((a, b) => b.cards.length.compareTo(a.cards.length));
      case _Sort.featured:
        if (_similarTo == null) decks = store.catalog.featuredFirst(decks);
    }
    return decks;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final navH = NavBar.height + mq.padding.bottom;
    final decks = _filter(store);
    final q = _query.text.trim();
    final showHero = _cat == 'all' && q.isEmpty && _similarTo == null;
    // A new library starts at the canvas's German A1; after that, a different featured deck each day.
    final fresh = store.data.shopAdded.isEmpty;
    final featured = fresh
        ? store.catalog.byId('de-a1-basics')
        : store.catalog.deckOfTheDay(dayNumber(store.data.now()), store.data.shopAdded.containsKey);
    final pins = store.catalog.decks.where((d) => store.data.shopPins.contains(d.id)).toList();
    final cols = mq.size.width >= 600 ? 3 : 2;

    final sections = <(String, List<CatalogDeck>)>[];
    if (_similarTo != null) {
      sections.add(('Similar decks', decks));
    } else {
      if (showHero && pins.isNotEmpty) sections.add(('Your favourites', pins));
      for (final c in CatalogCategory.all) {
        final list = decks.where((d) => d.category == c.id).toList();
        if (list.isNotEmpty) sections.add((c.name, list));
      }
    }

    return Scaffold(
      backgroundColor: mc.canvas,
      resizeToAvoidBottomInset: false,
      body: Wall(child: Stack(
        children: [
          Positioned.fill(
            top: top + 196,
            child: EdgeFade(
              top: 10,
              bottom: 60,
              bottomInset: navH,
              child: ListView(
              padding: EdgeInsets.fromLTRB(18, 6, 18, navH + 120),
              physics: const BouncingScrollPhysics(),
              children: [
                if (showHero && featured != null) _Hero(deck: featured, label: fresh ? 'START HERE' : 'DECK OF THE DAY'),
                if (_similarTo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Chip2('Clear similar ×', onTap: () => setState(() => _similarTo = null)),
                    ),
                  ),
                for (var s = 0; s < sections.length; s++) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 26,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: Text(sections[s].$1, style: T.d(25, color: mc.ink))),
                      Text('${sections[s].$2.length} ${sections[s].$2.length == 1 ? 'deck' : 'decks'}',
                          style: T.t(13, w: FontWeight.w600, color: mc.muted)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  _Grid(
                    cols: cols,
                    children: [
                      for (var i = 0; i < sections[s].$2.length; i++)
                        Cascade(
                          index: i,
                          delayMs: 30,
                          child: _HoldTile(
                            deck: sections[s].$2[i],
                            added: store.data.shopAdded.containsKey(sections[s].$2[i].id),
                            pinned: store.data.shopPins.contains(sections[s].$2[i].id),
                            onTap: () => showPreview(context, sections[s].$2[i].id),
                            onHold: (rect) => _openHold(context, store, sections[s].$2[i], rect),
                          ),
                        ),
                    ],
                  ),
                ],
                if (sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text('No decks match “$q”.',
                        textAlign: TextAlign.center, style: T.t(17, w: FontWeight.w600, color: mc.muted)),
                  ),
                const SizedBox(height: 20),
                Text('Press and hold a deck for quick actions',
                    textAlign: TextAlign.center, style: T.t(14, w: FontWeight.w500, color: mc.muted)),
              ],
            ),
            ),
          ),
          // Header, search and categories.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: top + 196,
            child: ColoredBox(
              color: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    height: 76,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 16, 0),
                      child: Row(children: [
                        IconTap(icon: McIcons.logo, label: 'Open folders', onTap: () => Shell.of(context).openDrawer()),
                        const SizedBox(width: 12),
                        Text('Shop', style: T.d(26, color: mc.ink)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${store.catalog.decks.length} decks · ${store.catalog.cardCount} cards',
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.t(13, w: FontWeight.w600, color: mc.muted)),
                        ),
                        IconTap(
                          icon: McIcons.gear,
                          label: 'Settings',
                          size: const Size(28, 32),
                          onTap: () => Navigator.of(context, rootNavigator: true).push(SettingsScreen.route()),
                        ),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: Row(children: [
                      Expanded(child: _Search(controller: _query)),
                      const SizedBox(width: 10),
                      Pressable(
                        label: 'Filters',
                        haptic: true,
                        onTap: () => _filters(context),
                        child: Container(
                          width: 50,
                          height: 50,
                          foregroundDecoration: texDeco(context, 'buttons', BorderRadius.circular(14)),
                          decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(14), boxShadow: mc.e1),
                          child: Center(child: McIcon(McIcons.filter, size: const Size(24, 24), color: mc.canvas)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      children: [
                        for (final c in [const CatalogCategory('all', 'All', 0), ...CatalogCategory.all])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip2(
                              c.name,
                              height: 34,
                              selected: _cat == c.id,
                              dot: c.id == 'all' ? (_cat == 'all' ? mc.canvas : mc.ink) : Color(c.color),
                              onTap: () => setState(() {
                                _cat = c.id;
                                _similarTo = null;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      )),
    );
  }

  Future<void> _filters(BuildContext context) async {
    final mc = Mc.of(context);
    await showMcSheet<void>(
      context,
      expand: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 22 + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Sort & filter', style: T.d(30, color: mc.ink)),
            const SizedBox(height: 14),
            Text('Sort by', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
            const SizedBox(height: 8),
            Seg<_Sort>(
              options: _Sort.values,
              value: _sort,
              labelOf: (s) => switch (s) { _Sort.featured => 'Featured', _Sort.name => 'Name', _Sort.size => 'Size' },
              onPick: (s) {
                set(() => _sort = s);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('Hide decks I already have', style: T.t(16, w: FontWeight.w700, color: mc.ink))),
              McSwitch(
                value: _hideAdded,
                onChanged: (v) {
                  set(() => _hideAdded = v);
                  setState(() {});
                },
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _openHold(BuildContext context, AppStore store, CatalogDeck deck, Rect rect) async {
    Fx.i.pop();
    final action = await Navigator.of(context, rootNavigator: true).push<String>(PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: const Color(0xA80F0F0F),
      barrierLabel: 'Close quick actions',
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, a, b) => Material(
        type: MaterialType.transparency,
        child: _HoldMenu(deck: deck, rect: rect, pinned: store.data.shopPins.contains(deck.id)),
      ),
      transitionsBuilder: (ctx, a, b, child) => FadeTransition(opacity: a, child: child),
    ));
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'pin':
        store.toggleShopPin(deck.id);
        Toaster.i.show(store.data.shopPins.contains(deck.id) ? 'Pinned to favourites' : 'Removed from favourites');
      case 'share':
        final sample = deck.cards.take(5).map((c) => '${c.front.isEmpty ? 'Picture' : c.front} → ${c.back}').join('\n');
        try {
          await SharePlus.instance.share(ShareParams(
            text: 'Memory Card · ${deck.name}\n${deck.description}\n\n$sample\n…and ${math.max(0, deck.cards.length - 5)} more cards.',
          ));
        } catch (_) {
          Toaster.i.show('Sharing is not available here');
        }
      case 'similar':
        setState(() {
          _similarTo = deck.id;
          _cat = 'all';
        });
        Toaster.i.show('Showing decks like ${deck.name}');
      case 'save':
        final existing = store.data.shopAdded[deck.id];
        if (existing != null && store.data.decks.containsKey(existing)) {
          Toaster.i.show('Already in ${store.data.folderOf(existing)?.name ?? 'your library'}');
          return;
        }
        final folder = store.data.folders.where((f) => f.name.toLowerCase() == deck.folder.toLowerCase() && !f.isArchive).firstOrNull ??
            store.createFolder(deck.folder, atTop: false);
        final d = store.addCatalogDeck(deck.id, folder.id);
        Fx.i.remembered();
        Toaster.i.show('Saved to ${folder.name}', undo: () => store.deleteDeck(d.id));
    }
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.cols, required this.children});
  final int cols;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var j = 0; j < cols; j++) ...[
            if (j > 0) const SizedBox(width: 12),
            Expanded(child: i + j < children.length ? children[i + j] : const SizedBox.shrink()),
          ],
        ]),
      ));
    }
    return Column(children: rows);
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: T.t(18, w: FontWeight.w600, color: mc.ink),
      cursorColor: mc.ink,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search decks and cards',
        hintStyle: T.t(18, w: FontWeight.w600, color: mc.muted),
        filled: true,
        fillColor: mc.soft,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: McIcon(McIcons.search, size: const Size(24, 24), color: mc.muted),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 46),
        suffixIcon: controller.text.isEmpty
            ? null
            : GestureDetector(onTap: controller.clear, child: Icon(Icons.close_rounded, color: mc.muted)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.deck, required this.label});
  final CatalogDeck deck;
  final String label;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final skin = deck.skin;
    final (title, sub) = skin == null ? (mc.onInk, mc.mutedOnInk) : skinInk(skin);
    return Pressable(
      onTap: () => showPreview(context, deck.id),
      child: Container(
        height: 160,
        foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(22)),
        decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(22), boxShadow: mc.e2),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // A deck with its own look shows it here too.
          if (skin != null) ...[
            Positioned.fill(child: SkinPicture(skin: skin)),
            Positioned.fill(child: SkinShade(skin: skin)),
          ],
          Positioned(
            left: 18,
            top: 18,
            width: 180,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: T.caps(12, color: sub, spacing: 1.4)),
              const SizedBox(height: 6),
              Text(deck.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.d(24, color: title)),
              const SizedBox(height: 4),
              Text('${deck.cards.length} cards${deck.lang != null ? ' · with audio' : ''}',
                  style: T.t(14, w: FontWeight.w600, color: sub)),
              const SizedBox(height: 10),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: mc.canvas, borderRadius: BorderRadius.circular(16)),
                child: Text('Preview', style: T.t(14, w: FontWeight.w700, color: mc.ink)),
              ),
            ]),
          ),
          // The two cards under the front one rock now and then, exactly like the shop's deck tiles.
          Positioned.fill(
            child: Sway(
              delayMs: 500,
              periodMs: 7000,
              builder: (context, v) => Stack(children: [
                Positioned(right: 30, top: 26, child: _rot(-12 - v * StackArt.swing * 180 / math.pi, Container(width: 92, height: 116, decoration: _card(mc.heroBack2)))),
                Positioned(right: 22, top: 22, child: _rot(7 + v * StackArt.swing * 180 / math.pi, Container(width: 92, height: 116, decoration: _card(mc.heroBack1)))),
              ]),
            ),
          ),
          // The category tab sits one level down, behind the front card, so only its top shows.
          Positioned(
            right: 30,
            top: 18,
            child: Container(
              width: 30,
              height: 12,
              decoration: BoxDecoration(color: Color(CatalogCategory.of(deck.category).color), borderRadius: BorderRadius.circular(5)),
            ),
          ),
          Positioned(
            right: 24,
            top: 24,
            child: Container(
              width: 92,
              height: 116,
              alignment: Alignment.center,
              decoration: _card(mc.canvas),
              child: Text(deck.mono, style: T.d(46, color: mc.ink)),
            ),
          ),
        ]),
      ),
    );
  }

  static Widget _rot(double deg, Widget c) => Transform.rotate(angle: deg * math.pi / 180, child: c);
  static BoxDecoration _card(Color c) => BoxDecoration(color: c, borderRadius: BorderRadius.circular(14));
}

/// A tile that opens on tap and lifts into quick actions on a 430ms hold (scrolling cancels it).
class _HoldTile extends StatefulWidget {
  const _HoldTile({required this.deck, required this.added, required this.pinned, required this.onTap, required this.onHold});
  final CatalogDeck deck;
  final bool added;
  final bool pinned;
  final VoidCallback onTap;
  final ValueChanged<Rect> onHold;

  @override
  State<_HoldTile> createState() => _HoldTileState();
}

class _HoldTileState extends State<_HoldTile> {
  @override
  Widget build(BuildContext context) {
    final tile = Pressable(
      onTap: widget.onTap,
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final pos = box.localToGlobal(Offset.zero);
        widget.onHold(pos & box.size);
      },
      child: ShopTile(deck: widget.deck, added: widget.added, pinned: widget.pinned),
    );
    if (widget.deck.id != 'de-a1-basics') return tile;
    return CoachTarget(id: 'shop-hold', text: 'Press and hold any deck for quick actions', delayMs: 1800, child: tile);
  }
}

/// The quick actions: the held deck lifts, four scalloped badges pop out in an arc toward the roomier side.
class _HoldMenu extends StatelessWidget {
  const _HoldMenu({required this.deck, required this.rect, required this.pinned});
  final CatalogDeck deck;
  final Rect rect;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cx = rect.center.dx, cy = rect.center.dy;
    final toRight = cx < size.width / 2;
    final angles = toRight ? [-55.0, -20.0, 15.0, 50.0] : [235.0, 200.0, 165.0, 130.0];
    final rx = rect.width / 2 + 52, ry = rect.height / 2 + 44;
    final actions = [
      ('pin', pinned ? 'Unpin' : 'Pin', McIcons.pin, PolarShape.actScallop, 8.0),
      ('share', 'Share', McIcons.share, PolarShape.actSquircle, -6.0),
      ('similar', 'Similar', McIcons.search, PolarShape.actBurst, 0.0),
      ('save', 'Save', McIcons.save, PolarShape.actBlob, -10.0),
    ];
    return Stack(children: [
      Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 1.05),
            duration: const Duration(milliseconds: 260),
            curve: McCurves.springy,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: ShopTile(deck: deck, held: true),
          ),
        ),
      ),
      AmbientClock(builder: (context, ms) {
        return Stack(children: [
          for (var i = 0; i < actions.length; i++)
            Builder(builder: (context) {
              final r = angles[i] * math.pi / 180;
              final x = (cx + math.cos(r) * rx - 36).clamp(6.0, size.width - 78);
              final y = (cy + math.sin(r) * ry - 36).clamp(80.0, size.height - 112 - 76);
              // Pop in one after another.
              final u = ((ms - i * 45) / 240).clamp(0.0, 1.0);
              final s = u < 0.7 ? 0.4 + (1.08 - 0.4) * (u / 0.7) : 1.08 - 0.08 * ((u - 0.7) / 0.3);
              // A very soft bob, each badge on its own phase.
              final dy = -1.5 * (1 - math.cos(ms / 3200 * math.pi * 2 + i * 1.3));
              // Every 6 s the badge's shape (not its icon) turns once, slowly, easing out. The four start one
              // after another, so the turns roll through the arc instead of moving in lockstep.
              final since = ms - (_spinFirstMs + i * _spinGapMs);
              final spin = since < 0 ? 0.0 : Curves.easeOut.transform(((since % _spinPeriodMs) / _spinMs).clamp(0.0, 1.0));
              final (id, label, icon, shape, tilt) = actions[i];
              final turn = tilt * math.pi / 180 + spin * math.pi * 2;
              return Positioned(
                left: x,
                top: y,
                child: Opacity(
                  opacity: math.min(1.0, u * 2),
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: s,
                      child: Pressable(
                        label: label,
                        haptic: true,
                        onTap: () => Navigator.pop(context, id),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                            // Soft shadow in the badge's own shape.
                            Transform.translate(
                              offset: const Offset(0, 5),
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                                child: CustomPaint(
                                  size: const Size(72, 72),
                                  painter: PolarPainter(shape, const Color(0x38000000), rotation: turn),
                                ),
                              ),
                            ),
                            CustomPaint(size: const Size(72, 72), painter: PolarPainter(shape, Mc.paper, rotation: turn)),
                            McIcon(icon, size: const Size(28, 28), color: Mc.graphite),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ]);
      }),
    ]);
  }

  /// A turn begins every [_spinPeriodMs]; each takes [_spinMs]. The first badge starts [_spinFirstMs] after the
  /// menu opens and each next one [_spinGapMs] later.
  static const _spinPeriodMs = 6000.0;
  static const _spinMs = 2600.0;
  static const _spinFirstMs = 1200.0;
  static const _spinGapMs = 900.0;
}
