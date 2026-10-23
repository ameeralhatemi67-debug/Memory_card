import 'dart:convert';
import 'dart:math' as math;

import 'models.dart';
import 'store.dart';

/// Home-screen widgets (Android). The app hands them one JSON snapshot; they never run Dart. Answers
/// given on the Quick card come back through an inbox the app replays through the engine.
class WidgetKeys {
  const WidgetKeys._();

  /// The snapshot below, as a JSON string.
  static const snapshot = 'mc.snapshot';

  /// Quick card answers, a JSON list written by the widget: {card, deck, grade, ts, verify}.
  static const inbox = 'mc.inbox';

  /// The newest answer the app has applied (ms, as a string). Older inbox entries are dropped by the widget.
  static const applied = 'mc.inbox.applied';
}

/// One answer given on the Quick card widget.
class WidgetReview {
  const WidgetReview({required this.cardId, required this.deckId, required this.grade, required this.ts, this.verifyMs});

  final String cardId;
  final String deckId;

  /// 1 Again · 3 Good: the widget has no hesitation to read, so it never picks Hard or Easy.
  final int grade;

  /// When it was answered, on the phone's real clock (ms since epoch).
  final int ts;

  /// From the reveal to the answer, when the widget saw both.
  final int? verifyMs;

  static WidgetReview? fromJson(Object? j) {
    if (j is! Map) return null;
    final card = j['card'], deck = j['deck'], grade = j['grade'], ts = j['ts'];
    if (card is! String || deck is! String || grade is! num || ts is! num) return null;
    final verify = j['verify'];
    return WidgetReview(
      cardId: card,
      deckId: deck,
      grade: grade.toInt() <= 1 ? 1 : 3,
      ts: ts.toInt(),
      verifyMs: verify is num && verify > 0 ? verify.toInt() : null,
    );
  }

  /// The inbox entries newer than [appliedTs], oldest first. Anything unreadable is skipped.
  static List<WidgetReview> parseInbox(String? raw, int appliedTs) {
    if (raw == null || raw.isEmpty) return const [];
    Object? list;
    try {
      list = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (list is! List) return const [];
    return [for (final e in list) ?WidgetReview.fromJson(e)].where((r) => r.ts > appliedTs).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
  }
}

/// Everything the widgets draw, computed once by the app. Times are on the phone's real clock; `offset`
/// is the developer time travel, which the widget adds to its own clock to agree with the app.
Map<String, Object?> buildWidgetSnapshot(AppStore store, {int queueSize = 12}) {
  final data = store.data;
  final now = store.now();
  final t = store.today;
  final p = data.profile;
  final s = store.settings;
  final lib = store.libraryStats();
  final lastId = t.lastDeck ?? data.lastDeckId;
  final last = lastId == null ? null : data.decks[lastId];
  return {
    'v': 1,
    'at': now - data.clockOffset,
    'offset': data.clockOffset,
    'day': t.day,
    'goal': s.goal,
    'done': t.done,
    'goalHit': t.goalHit,
    'mins': math.max(t.done > 0 ? 1 : 0, (t.ms / 60000).round()),
    'lastDeck': last?.name,
    'lastDeckId': last?.id,
    'streak': store.engine.liveStreak(),
    'rawStreak': p.streak,
    'lastGoalDay': p.lastGoalDay,
    'shields': p.shields,
    'best': p.bestStreak,
    'goalDays': [for (var d = t.day - 13; d <= t.day; d++) if (p.history[d]?.goal ?? false) d],
    'health': lib.health == null ? null : double.parse(lib.health!.toStringAsFixed(3)),
    'slipping': lib.slipping,
    'tomorrow': lib.tomorrow,
    'queue': widgetQueue(store, now, size: queueSize),
  };
}

/// The cards the Quick card offers: the ones you are most likely to have forgotten, across every deck
/// outside the archive, interleaved so one deck rarely comes twice in a row. New cards are left out (there
/// is nothing to recall yet), and so are cards with nothing the widget can show.
List<Map<String, Object?>> widgetQueue(AppStore store, int now, {int size = 12}) {
  final engine = store.engine;
  final s = store.settings;
  final pool = <(double, CardItem, Deck)>[];
  for (final d in store.data.activeDecks) {
    for (final c in store.data.cardsOf(d)) {
      if (c.suspended || c.isNew) continue;
      final r = engine.recall(c, now);
      if (r == null || !_showable(c)) continue;
      pool.add((r, c, d));
    }
  }
  pool.sort((a, b) => a.$1.compareTo(b.$1));

  final picked = <(double, CardItem, Deck)>[];
  String? lastDeck;
  while (picked.length < size && pool.isNotEmpty) {
    // The most urgent card from another deck, if one is close enough to the front to be worth it.
    var i = pool.indexWhere((e) => e.$3.id != lastDeck);
    if (i < 0 || i > 4) i = 0;
    final e = pool.removeAt(i);
    picked.add(e);
    lastDeck = e.$3.id;
  }

  return [
    for (final (r, c, d) in picked)
      {
        'id': c.id,
        'deck': d.id,
        'deckName': d.name,
        'front': c.front,
        'back': c.back,
        'label': c.label,
        'example': c.example,
        'hook': c.hook,
        'r': double.parse(r.toStringAsFixed(3)),
        if (d.kind == 'code') 'mono': true,
        ..._pictures(c, s),
      },
  ];
}

/// Widgets can open bundled pictures (`asset:`) and pictures saved on the phone; web data URIs never
/// reach them.
String? _usable(String? src) => src == null || src.isEmpty || src.startsWith('data:') ? null : src;

bool _showable(CardItem c) {
  final front = c.front.trim().isNotEmpty || _usable(_frontPicture(c)?.$1) != null;
  final back = c.back.trim().isNotEmpty || _usable(c.backLayout?.firstImage?.src) != null;
  return front && back;
}

/// The front picture and whether it waits for the reveal.
(String, bool)? _frontPicture(CardItem c) {
  final el = c.frontLayout?.firstImage;
  if (el != null) return (el.src, el.blur);
  final legacy = c.image;
  return legacy == null || legacy.isEmpty ? null : (legacy, false);
}

Map<String, Object?> _pictures(CardItem c, Settings s) {
  final front = _frontPicture(c);
  final frontSrc = _usable(front?.$1);
  final backSrc = _usable(c.backLayout?.firstImage?.src);
  final waits = front != null && front.$2 && s.imageReveal != 'show';
  return {
    'img': ?frontSrc,
    if (frontSrc != null && waits) 'imgReveal': s.imageReveal,
    'backImg': ?backSrc,
  };
}
