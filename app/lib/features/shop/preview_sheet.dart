import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../engine/deck_seals.dart';
import '../../services/speech.dart';
import '../../ui/deck_look.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../decks/deck_row.dart';
import '../layout/layout_face.dart';
import '../shell/shell.dart';
import 'shop_tile.dart';

/// Deck preview (canvas Preview.dc.html): flip through sample cards, pick a folder, add the deck.
Future<void> showPreview(BuildContext context, String catalogId, {String? folderId}) {
  final shell = Shell.maybeOf(context);
  return showMcSheet(context, top: 64, builder: (ctx) => PreviewSheet(catalogId: catalogId, folderId: folderId, shell: shell));
}

class PreviewSheet extends StatefulWidget {
  const PreviewSheet({super.key, required this.catalogId, this.folderId, this.shell});
  final String catalogId;
  final String? folderId;
  final ShellState? shell;

  @override
  State<PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<PreviewSheet> with SingleTickerProviderStateMixin {
  late final AppStore store = context.storeRead;
  late final CatalogDeck deck = store.catalog.byId(widget.catalogId)!;
  late final AnimationController _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  int _sample = 0;
  String? _folder; // folder id, or '__new:<name>'
  late bool _reverse = deck.category == 'lang' || deck.style.reverse;

  @override
  void initState() {
    super.initState();
    final match = store.data.folders.where((f) => !f.isArchive && f.name.toLowerCase() == deck.folder.toLowerCase()).firstOrNull;
    _folder = widget.folderId ?? match?.id ?? '__new:${deck.folder}';
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _tapSample() {
    Fx.i.reveal();
    if (_flip.value < 0.5) {
      _flip.animateTo(1, curve: McCurves.springy);
    } else {
      _flip.animateBack(0, curve: Curves.easeOut).whenComplete(() {
        if (mounted) setState(() => _sample = (_sample + 1) % math.min(deck.cards.length, 6));
      });
    }
  }

  Future<void> _add() async {
    String folderId;
    if (_folder!.startsWith('__new:')) {
      folderId = store.createFolder(_folder!.substring(6), atTop: false).id;
    } else {
      folderId = _folder!;
    }
    final d = store.addCatalogDeck(deck.id, folderId, reverse: _reverse);
    final f = store.data.folderById(folderId)!;
    Fx.i.remembered(easy: true);
    store.touchFolder(folderId);
    Navigator.pop(context);
    widget.shell?.goHome();
    Toaster.i.show('Added ${d.cardIds.length} cards to ${f.name}', undo: () => store.deleteDeck(d.id));
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final store = context.store;
    final addedId = store.data.shopAdded[deck.id];
    final added = addedId != null && store.data.decks.containsKey(addedId);
    final sample = deck.cards.isEmpty ? null : deck.cards[_sample % deck.cards.length];
    final folders = store.data.folders.where((f) => !f.isArchive).toList();
    final newName = _folder!.startsWith('__new:') ? _folder!.substring(6) : null;
    final bottom = MediaQuery.of(context).padding.bottom;
    final target = newName ?? store.data.folderById(_folder)?.name ?? 'a folder';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 18 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // The sample card, fanned over two others.
                SizedBox(
                  height: 196,
                  child: Stack(alignment: Alignment.topCenter, children: [
                    // The two cards beneath rock as the sheet opens, then every 7 s.
                    Positioned.fill(
                      child: Sway(
                        delayMs: 380,
                        builder: (context, v) => Stack(alignment: Alignment.topCenter, children: [
                          Positioned(
                            top: 18,
                            child: Transform.translate(
                              offset: const Offset(-4, 0),
                              child: Transform.rotate(angle: -7 * math.pi / 180 - v * StackArt.swing, child: _blank(mc.back2, mc)),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            child: Transform.translate(
                              offset: const Offset(4, 0),
                              child: Transform.rotate(angle: 5 * math.pi / 180 + v * StackArt.swing, child: _blank(mc.back1, mc)),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    if (sample != null)
                      Positioned(
                        top: 14,
                        child: GestureDetector(
                          onTap: _tapSample,
                          child: AnimatedBuilder(
                            animation: _flip,
                            builder: (context, _) {
                              final a = _flip.value * math.pi;
                              final back = a > math.pi / 2;
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.0014)
                                  ..rotateY(back ? a - math.pi : a),
                                child: Container(
                                  width: 214,
                                  height: 150,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: back ? Mc.peach : mc.ink,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: mc.e2,
                                  ),
                                  child: !back && sample.img.isNotEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: SizedBox.expand(
                                              child: ColoredBox(
                                                color: deck.style.plate == 'paper' ? Mc.paper : const Color(0x14000000),
                                                child: cardImage(deck.assetOf(sample.img),
                                                    fit: deck.style.contain ? BoxFit.contain : BoxFit.cover,
                                                    alignment: deck.style.contain ? Alignment.center : const Alignment(0, -0.5)),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text(back ? 'ANSWER' : (sample.label.isEmpty ? deck.level : sample.label).toUpperCase(),
                                        maxLines: 1,
                                        style: T.caps(12, color: (back ? Mc.graphite : mc.onInk).withValues(alpha: 0.7))),
                                    const SizedBox(height: 6),
                                    Text(
                                      back ? sample.back : sample.front,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: deck.kind == 'code' && !back
                                          ? T.mono(18, color: mc.onInk)
                                          : T.d((back ? sample.back : sample.front).length > 18 ? 24 : 34,
                                              color: back ? Mc.graphite : mc.onInk),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      child: Text('Sample card · tap to flip', style: T.t(13, w: FontWeight.w600, color: mc.muted)),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(deck.name, style: T.d(38, color: mc.ink)),
                const SizedBox(height: 6),
                Text('${deck.publisher} · Free', style: T.t(15, w: FontWeight.w600, color: mc.muted)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: StatTile(value: '${deck.cards.length}', label: 'cards', valueSize: 26)),
                  const SizedBox(width: 8),
                  Expanded(child: StatTile(value: deck.level.isEmpty ? '—' : deck.level, label: 'level', valueSize: 26)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: deck.lang != null
                        ? Pressable(
                            onTap: () => sample == null ? null : Speech.i.speak(sample.front, deck.lang!),
                            child: const StatTile(value: 'Audio', label: 'tap to hear', valueSize: 26),
                          )
                        : StatTile(value: CatalogCategory.of(deck.category).name, label: 'category', valueSize: 22),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(deck.description, style: T.t(16, w: FontWeight.w500, color: mc.ink, height: 1.4)),
                if (deck.cards.any((c) => c.hook.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    McIcon(McIcons.lightbulb, size: const Size(16, 16), color: mc.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${deck.cards.where((c) => c.hook.isNotEmpty).length} cards come with a memory hook',
                          style: T.t(14, w: FontWeight.w600, color: mc.muted)),
                    ),
                  ]),
                ],
                if (deck.skin != null) ...[
                  const SizedBox(height: 18),
                  const SectionLabel('In your library'),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, box) => DeckBarFace(
                      id: deck.id,
                      name: deck.name,
                      meta: '${deck.cards.length} cards · new',
                      steps: 0,
                      width: math.min(box.maxWidth, 520.0),
                      skin: deck.skin,
                    ),
                  ),
                ],
                if (deck.seals.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionLabel('${deck.seals.length == 1 ? 'A seal' : '${deck.seals.length} seals'} to earn'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 14, runSpacing: 12, children: [
                    for (final s in deck.seals)
                      SizedBox(
                        width: 104,
                        child: Column(children: [
                          SizedBox(height: 66, child: Center(child: DeckSealBadge(seal: s, size: s.wide ? 58 : 66))),
                          const SizedBox(height: 6),
                          Text(s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: T.t(13, w: FontWeight.w700, color: mc.ink)),
                          Text(DeckMilestones.of(s.when).label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: T.t(11.5, w: FontWeight.w600, color: mc.muted)),
                        ]),
                      ),
                  ]),
                ],
                if (store.catalog.similarTo(deck).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const SectionLabel('Similar decks'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 118,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final other in store.catalog.similarTo(deck).take(8))
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Pressable(
                              label: 'Preview ${other.name}',
                              onTap: () {
                                // Swap this sheet for the other deck's.
                                final nav = Navigator.of(context);
                                final ctx = widget.shell?.context;
                                nav.pop();
                                if (ctx != null && ctx.mounted) showPreview(ctx, other.id, folderId: widget.folderId);
                              },
                              child: SizedBox(
                                width: 96,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  StackArt(mono: other.mono, tab: Color(CatalogCategory.of(other.category).color), scale: 0.6, skin: other.skin),
                                  const SizedBox(height: 4),
                                  Text(other.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.t(13, w: FontWeight.w700, color: mc.ink, height: 1.15)),
                                ]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (added)
                  Container(
                    padding: const EdgeInsets.all(14),
                    foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(14)),
                    decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      McIcon(McIcons.done, size: const Size(22, 22), color: mc.ink),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('In your library · ${store.data.folderOf(addedId)?.name ?? ''}',
                            style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                      ),
                    ]),
                  )
                else ...[
                  const SectionLabel('Add to folder'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (!folders.any((f) => f.name.toLowerCase() == deck.folder.toLowerCase()))
                      Chip2('+ ${deck.folder}', height: 36, selected: newName == deck.folder, onTap: () => setState(() => _folder = '__new:${deck.folder}')),
                    for (final f in folders) Chip2(f.name, height: 36, selected: _folder == f.id, onTap: () => setState(() => _folder = f.id)),
                    Chip2('+ New folder', height: 36, selected: newName != null && newName != deck.folder, onTap: () async {
                      final name = await promptText(context, title: 'Name the folder', initial: 'New folder', action: 'Use it');
                      if (name != null) setState(() => _folder = '__new:$name');
                    }),
                  ]),
                  if (deck.category == 'lang' || deck.hasPictures) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Also study it in reverse', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                          Text(deck.hasPictures ? 'Adds a card for each one that shows the name and asks for the picture' : 'Adds a back-to-front card for each one',
                              style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.3)),
                        ]),
                      ),
                      McSwitch(value: _reverse, onChanged: (v) => setState(() => _reverse = v)),
                    ]),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (added)
            InkButton('Study it now', onTap: () {
              Navigator.pop(context);
              widget.shell?.study(addedId);
            })
          else
            InkButton('Add ${deck.cards.length * (_reverse ? 2 : 1)} cards to $target', size: 25, height: 58, onTap: _add),
        ],
      ),
    );
  }

  Widget _blank(Color c, Mc mc) => Container(
        width: 214,
        height: 150,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
      );
}
