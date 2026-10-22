import 'dart:convert';

import 'package:flutter/services.dart';

/// A deck in the shop catalogue (bundled with the app, works offline).
class CatalogCard {
  const CatalogCard({required this.front, required this.back, this.label = '', this.example = '', this.hook = ''});
  final String front;
  final String back;
  final String label;
  final String example;
  final String hook;

  factory CatalogCard.fromJson(Map j) => CatalogCard(
        front: (j['front'] as String).trim(),
        back: (j['back'] as String).trim(),
        label: ((j['label'] as String?) ?? '').trim(),
        example: ((j['example'] as String?) ?? '').trim(),
        hook: ((j['hook'] as String?) ?? '').trim(),
      );
}

class CatalogDeck {
  const CatalogDeck({
    required this.id,
    required this.name,
    required this.mono,
    required this.category,
    required this.level,
    required this.lang,
    required this.kind,
    required this.folder,
    required this.description,
    required this.origin,
    required this.cards,
  });

  final String id;
  final String name;
  final String mono;
  final String category;
  final String level;
  final String? lang;
  final String kind;
  final String folder;
  final String description;

  /// originals · haiku
  final String origin;
  final List<CatalogCard> cards;

  String get publisher => origin == 'haiku' ? 'Memory Card Studio' : 'Memory Card Originals';

  factory CatalogDeck.fromJson(Map j) => CatalogDeck(
        id: j['id'] as String,
        name: j['name'] as String,
        mono: (j['mono'] as String?) ?? '',
        category: (j['category'] as String?) ?? 'knowledge',
        level: (j['level'] as String?) ?? '',
        lang: j['lang'] as String?,
        kind: (j['kind'] as String?) ?? 'text',
        folder: (j['folder'] as String?) ?? 'Library',
        description: (j['description'] as String?) ?? '',
        origin: (j['origin'] as String?) ?? 'originals',
        cards: ((j['cards'] as List?) ?? const []).map((e) => CatalogCard.fromJson(e as Map)).toList(),
      );
}

/// Shop categories with their tab colours (the drawer's blue / peach / red, plus green and ink).
class CatalogCategory {
  const CatalogCategory(this.id, this.name, this.color);
  final String id;
  final String name;
  final int color;

  static const all = <CatalogCategory>[
    CatalogCategory('lang', 'Languages', 0xFF80AEFF),
    CatalogCategory('code', 'Coding', 0xFFFFC680),
    CatalogCategory('med', 'Medicine', 0xFFD35F5F),
    CatalogCategory('science', 'Science', 0xFF8BD3A0),
    CatalogCategory('knowledge', 'Knowledge', 0xFFB4B4B4),
  ];

  static CatalogCategory of(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => const CatalogCategory('custom', 'Yours', 0xFF9D9D9D));
}

class Catalog {
  Catalog(this.decks);

  final List<CatalogDeck> decks;

  static Future<Catalog> load() async {
    try {
      final raw = await rootBundle.loadString('assets/content/catalog.json');
      final j = jsonDecode(raw) as Map;
      return Catalog(((j['decks'] as List?) ?? const []).map((e) => CatalogDeck.fromJson(e as Map)).toList());
    } catch (_) {
      return Catalog(const []);
    }
  }

  CatalogDeck? byId(String id) {
    for (final d in decks) {
      if (d.id == id) return d;
    }
    return null;
  }

  int get cardCount => decks.fold(0, (a, d) => a + d.cards.length);

  /// Decks that share the category, closest in size first (the shop's "Similar" action).
  List<CatalogDeck> similarTo(CatalogDeck deck) {
    final same = decks.where((d) => d.id != deck.id && d.category == deck.category).toList()
      ..sort((a, b) => (a.cards.length - deck.cards.length).abs().compareTo((b.cards.length - deck.cards.length).abs()));
    return same;
  }
}
