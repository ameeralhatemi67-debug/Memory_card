import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store_scope.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/routes.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../editor/editor_sheet.dart';
import '../shell/shell.dart';
import 'card_detail.dart';

enum _Filter { all, slipping, fresh, tricky, mastered, suspended }

/// Every card of a deck with its predicted recall; find, fix, suspend or study.
class DeckBrowser extends StatefulWidget {
  const DeckBrowser({super.key, required this.deckId});
  final String deckId;

  static Route<void> route(String deckId) => McPageRoute(builder: (_) => DeckBrowser(deckId: deckId));

  @override
  State<DeckBrowser> createState() => _DeckBrowserState();
}

class _DeckBrowserState extends State<DeckBrowser> {
  final _q = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _q.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final deck = store.data.decks[widget.deckId];
    if (deck == null) return Scaffold(backgroundColor: mc.canvas);
    final now = store.now();
    final s = store.stats(deck);
    final q = _q.text.trim().toLowerCase();
    final cards = store.data.cardsOf(deck).where((c) {
      if (q.isNotEmpty && !c.front.toLowerCase().contains(q) && !c.back.toLowerCase().contains(q)) return false;
      final r = store.engine.recall(c, now);
      return switch (_filter) {
        _Filter.all => true,
        _Filter.slipping => r != null && r < 0.9,
        _Filter.fresh => c.isNew,
        _Filter.tricky => c.leech || (c.reps >= 4 && c.successRate < 0.5),
        _Filter.mastered => store.engine.isMastered(c),
        _Filter.suspended => c.suspended,
      };
    }).toList()
      ..sort((a, b) {
        final ra = store.engine.recall(a, now) ?? 2, rb = store.engine.recall(b, now) ?? 2;
        return ra.compareTo(rb);
      });

    return Scaffold(
      backgroundColor: mc.canvas,
      body: Column(children: [
        SizedBox(height: mq.padding.top),
        SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 12, 0),
            child: Row(children: [
              IconTap(icon: McIcons.back, size: const Size(26, 26), label: 'Back', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 6),
              Expanded(child: Text(deck.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.d(24, color: mc.ink))),
              IconTap(icon: McIcons.dots, size: const Size(8, 26), label: 'Deck menu', onTap: () => _menu(context, deck)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(children: [
            Expanded(child: StatTile(value: '${s.total}', label: 'cards', valueSize: 26)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: '${s.slipping}', label: 'slipping', valueSize: 26)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: s.health == null ? '—' : '${(s.health! * 100).round()}%', label: 'health', valueSize: 26)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: '${s.mastered}', label: 'mastered', valueSize: 26)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            controller: _q,
            style: T.t(17, w: FontWeight.w600, color: mc.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Find a card',
              hintStyle: T.t(17, w: FontWeight.w600, color: mc.muted),
              filled: true,
              fillColor: mc.soft,
              prefixIcon: Padding(padding: const EdgeInsets.only(left: 12, right: 6), child: McIcon(McIcons.search, size: const Size(20, 20), color: mc.muted)),
              prefixIconConstraints: const BoxConstraints(minWidth: 38),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip2(
                    switch (f) {
                      _Filter.all => 'All',
                      _Filter.slipping => 'Slipping',
                      _Filter.fresh => 'New',
                      _Filter.tricky => 'Tricky',
                      _Filter.mastered => 'Mastered',
                      _Filter.suspended => 'Suspended',
                    },
                    height: 32,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: cards.isEmpty
              ? Center(child: Text('No cards here', style: T.t(17, w: FontWeight.w600, color: mc.muted)))
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 110 + mq.padding.bottom),
                  itemCount: cards.length,
                  itemBuilder: (context, i) => _CardRow(card: cards[i], recall: store.engine.recall(cards[i], now)),
                ),
        ),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Expanded(child: SoftButton('+ Add a card', onTap: () => showEditor(context, deckId: deck.id))),
          const SizedBox(width: 10),
          Expanded(
            child: InkButton('Study', height: 50, onTap: () {
              Navigator.pop(context);
              Shell.maybeOf(context)?.study(deck.id);
            }),
          ),
        ]),
      ),
    );
  }

  void _menu(BuildContext context, Deck deck) {
    final store = context.storeRead;
    showMcMenu(context, [
      MenuItemData('Rename deck', () async {
        final name = await promptText(context, title: 'Rename deck', initial: deck.name);
        if (name != null) {
          deck.name = name;
          store.saveDeck(deck);
        }
      }, icon: McIcons.list),
      MenuItemData('Export as CSV', () async {
        final csv = store.exportDeckCsv(deck.id);
        try {
          await FilePicker.saveFile(
            fileName: '${deck.name.replaceAll(RegExp(r'[^\w\- ]'), '').trim()}.csv',
            bytes: Uint8List.fromList(utf8.encode(csv)),
            mimeType: 'text/csv',
          );
          Toaster.i.show('Deck exported');
        } catch (_) {
          Toaster.i.show('Could not export the deck');
        }
      }, icon: McIcons.share),
      MenuItemData('Reset progress', () async {
        final ok = await confirm(context,
            title: 'Reset ${deck.name}?', message: 'Every card starts over as new. Your review log is kept.', yes: 'Reset', no: 'Keep');
        if (ok) {
          store.resetDeck(deck.id);
          Toaster.i.show('Progress reset');
        }
      }, icon: McIcons.undo),
      MenuItemData('Delete deck', () async {
        final ok = await confirm(context, title: 'Delete ${deck.name}?', message: 'All its cards go too. You can undo right after.');
        if (!ok || !context.mounted) return;
        final undo = store.deleteDeck(deck.id);
        Navigator.pop(context);
        Toaster.i.show('Deleted ${deck.name}', undo: undo);
      }, icon: McIcons.x, danger: true),
    ]);
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card, required this.recall});
  final CardItem card;
  final double? recall;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final r = recall;
    final color = r == null ? Mc.peach : r < 0.9 ? Mc.red : r < 0.97 ? mc.ink : Mc.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: () => Navigator.of(context).push(CardDetail.route(card.id)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(card.front,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.d(19, color: card.suspended ? mc.muted : mc.ink)),
                const SizedBox(height: 2),
                Text(card.back, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.t(14, w: FontWeight.w500, color: mc.muted)),
              ]),
            ),
            const SizedBox(width: 10),
            if (card.leech)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('TRICKY', style: T.caps(10, color: Mc.red, spacing: 0.8)),
              ),
            SizedBox(
              width: 52,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(r == null ? 'new' : '${(r * 100).round()}%', style: T.t(14, w: FontWeight.w700, color: mc.ink)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 4,
                    width: 52,
                    child: Stack(children: [
                      Positioned.fill(child: ColoredBox(color: mc.line)),
                      FractionallySizedBox(widthFactor: r ?? 0.0, child: ColoredBox(color: color)),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
