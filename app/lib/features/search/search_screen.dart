import 'package:flutter/material.dart';

import '../../data/store_scope.dart';
import '../../ui/icons.dart';
import '../../ui/routes.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../browse/card_detail.dart';

/// Search every card you have, front, back, example and hook.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static Route<void> route() => McPageRoute(builder: (_) => const SearchScreen());

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();

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
    final q = _q.text.trim().toLowerCase();
    final hits = q.length < 2
        ? const []
        : store.data.cards.values
            .where((c) =>
                !c.isReverse &&
                (c.front.toLowerCase().contains(q) ||
                    c.back.toLowerCase().contains(q) ||
                    c.example.toLowerCase().contains(q) ||
                    c.hook.toLowerCase().contains(q)))
            .take(200)
            .toList();
    return Scaffold(
      backgroundColor: mc.canvas,
      body: Column(children: [
        SizedBox(height: mq.padding.top),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 20, 8),
          child: Row(children: [
            IconTap(icon: McIcons.back, size: const Size(26, 26), label: 'Back', onTap: () => Navigator.pop(context)),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _q,
                autofocus: true,
                style: T.t(19, w: FontWeight.w600, color: mc.ink),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search ${store.data.cards.length} cards',
                  hintStyle: T.t(19, w: FontWeight.w600, color: mc.muted),
                  filled: true,
                  fillColor: mc.soft,
                  prefixIcon: Padding(padding: const EdgeInsets.only(left: 12, right: 6), child: McIcon(McIcons.search, size: const Size(22, 22), color: mc.muted)),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: q.length < 2
              ? Center(child: Text('Type at least two letters', style: T.t(16, w: FontWeight.w600, color: mc.muted)))
              : hits.isEmpty
                  ? Center(child: Text('Nothing found for “${_q.text.trim()}”', style: T.t(16, w: FontWeight.w600, color: mc.muted)))
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + mq.padding.bottom),
                      itemCount: hits.length,
                      itemBuilder: (context, i) {
                        final c = hits[i];
                        final d = store.data.decks[c.deckId];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Pressable(
                            onTap: () => Navigator.of(context).push(CardDetail.route(c.id)),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                              decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(d?.name ?? '', style: T.caps(11, color: mc.muted)),
                                const SizedBox(height: 3),
                                Text(c.front, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.d(20, color: mc.ink)),
                                Text(c.back, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.t(15, w: FontWeight.w500, color: mc.muted)),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
