import 'dart:convert';

import 'package:flutter/services.dart';

import 'card_layout.dart';

/// A deck in the shop catalogue (bundled with the app, works offline).
class CatalogCard {
  const CatalogCard({
    required this.front,
    required this.back,
    this.label = '',
    this.example = '',
    this.hook = '',
    this.img = '',
    this.bimg = '',
    this.aspect = 0,
    this.backAspect = 0,
    this.alpha = false,
    this.backAlpha = false,
  });
  final String front;
  final String back;
  final String label;
  final String example;
  final String hook;

  /// Picture file names inside the deck's folder (assets/content/img/DECK_ID/) for the front and back.
  final String img;
  final String bimg;

  /// Width ÷ height of those pictures, and whether they have transparent areas.
  final double aspect;
  final double backAspect;
  final bool alpha;
  final bool backAlpha;

  bool get hasPicture => img.isNotEmpty || bimg.isNotEmpty;

  factory CatalogCard.fromJson(Map j) => CatalogCard(
        front: ((j['front'] as String?) ?? '').trim(),
        back: (j['back'] as String).trim(),
        label: ((j['label'] as String?) ?? '').trim(),
        example: ((j['example'] as String?) ?? '').trim(),
        hook: ((j['hook'] as String?) ?? '').trim(),
        img: ((j['img'] as String?) ?? '').trim(),
        bimg: ((j['bimg'] as String?) ?? '').trim(),
        aspect: (j['a'] as num?)?.toDouble() ?? 0,
        backAspect: (j['ba'] as num?)?.toDouble() ?? 0,
        alpha: j['al'] == 1,
        backAlpha: j['bal'] == 1,
      );
}

/// How a picture deck lays its cards out (decided once per deck).
class CatalogStyle {
  const CatalogStyle({
    this.front = Tpl.text,
    this.back = Tpl.text,
    this.contain = false,
    this.reverse = false,
    this.plate = '',
  });

  final Tpl front;
  final Tpl back;
  final bool contain;

  /// Add a reverse card (name → picture) by default.
  final bool reverse;

  /// A solid plate behind transparent pictures ('paper' for logos).
  final String plate;

  factory CatalogStyle.fromJson(Object? j) {
    if (j is! Map) return const CatalogStyle();
    return CatalogStyle(
      front: Tpl.parse(j['front']),
      back: Tpl.parse(j['back']),
      contain: j['fit'] == 'contain',
      reverse: j['reverse'] == true,
      plate: (j['plate'] as String?) ?? '',
    );
  }
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
    this.style = const CatalogStyle(),
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
  final CatalogStyle style;

  /// A deck whose cards show pictures.
  bool get hasPictures => cards.any((c) => c.hasPicture);

  /// The bundled file for one of this deck's pictures.
  String assetOf(String file) => 'asset:assets/content/img/$id/$file';

  /// The front and back layouts of [c] (null = a plain text side).
  (SideLayout?, SideLayout?) layoutsFor(CatalogCard c) {
    SideLayout? side(String file, double aspect, bool alpha, Tpl tpl, bool back, CatalogCard c) {
      if (file.isEmpty) return null;
      return SideLayout.forPicture(
        tpl == Tpl.text ? Tpl.below : tpl,
        back: back,
        src: assetOf(file),
        aspect: aspect,
        contain: style.contain,
        alpha: alpha,
        plate: style.plate,
        outline: style.contain,
        // Cropped pictures keep the top: faces sit above the middle of a figure.
        panY: style.contain ? 0.5 : 0.15,
        blur: back,
        textless: back ? (c.back.isEmpty && c.hook.isEmpty) : (c.front.isEmpty && c.example.isEmpty),
      );
    }

    return (side(c.img, c.aspect, c.alpha, style.front, false, c), side(c.bimg, c.backAspect, c.backAlpha, style.back, true, c));
  }

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
        style: CatalogStyle.fromJson(j['style']),
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

  /// Hand-picked starting points, best first. The shop's "Featured" order and the onboarding picker
  /// show these before the rest of a category.
  static const featuredIds = [
    'es-basics', 'fr-essentials', 'de-a1-basics', 'it-basics', 'ja-hiragana', 'pt-everyday', 'zh-pinyin', //
    'ar-alphabet', 'en-idioms', 'ru-cyrillic', 'de-a1-everyday', 'ja-survival',
    'python-syntax', 'git-commands', 'js-essentials', 'sql-queries', 'linux-shell', 'regex-patterns', 'big-o-operations',
    'anatomy-bones', 'cranial-nerves', 'med-prefixes', 'medical-abbreviations', 'pharm-basics', 'vitamin-deficiencies',
    'periodic-table', 'solar-system', 'organelles', 'si-units-constants', 'functional-groups',
    'world-capitals', 'history-dates', 'us-states', 'greek-gods', 'latin-phrases', 'paintings', 'philosophy', 'fallacies',
  ];

  /// [list] with the featured decks first, in [featuredIds] order; the others keep their order.
  List<CatalogDeck> featuredFirst(Iterable<CatalogDeck> list) {
    int rank(CatalogDeck d) {
      final i = featuredIds.indexOf(d.id);
      return i < 0 ? featuredIds.length : i;
    }

    final indexed = list.indexed.toList()
      ..sort((a, b) {
        final r = rank(a.$2).compareTo(rank(b.$2));
        return r != 0 ? r : a.$1.compareTo(b.$1);
      });
    return [for (final (_, d) in indexed) d];
  }

  /// The shop's deck of the day: walks the featured decks you don't have yet, one step per day.
  CatalogDeck? deckOfTheDay(int day, bool Function(String id) owned) {
    final pool = featuredFirst(decks.where((d) => !owned(d.id)));
    if (pool.isEmpty) return null;
    final featured = pool.where((d) => featuredIds.contains(d.id)).length;
    return pool[day % (featured > 0 ? featured : pool.length)];
  }

  /// Decks that share the category, closest in size first (the shop's "Similar" action).
  List<CatalogDeck> similarTo(CatalogDeck deck) {
    final same = decks.where((d) => d.id != deck.id && d.category == deck.category).toList()
      ..sort((a, b) => (a.cards.length - deck.cards.length).abs().compareTo((b.cards.length - deck.cards.length).abs()));
    return same;
  }
}
