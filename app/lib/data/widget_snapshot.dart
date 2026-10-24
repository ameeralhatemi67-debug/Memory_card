import 'dart:convert';
import 'dart:math' as math;

import '../engine/days.dart';
import '../engine/seals.dart';
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
  final streak = store.engine.liveStreak();
  final ahead = healthAhead(store, now);
  final mix = dailyMix(store);
  return {
    'v': 2,
    'at': now - data.clockOffset,
    'offset': data.clockOffset,
    'day': t.day,
    'goal': s.goal,
    'done': t.done,
    'goalHit': t.goalHit,
    'ok': t.ok,
    'fail': t.fail,
    'hard': t.hard,
    'easy': t.easy,
    'mins': math.max(t.done > 0 ? 1 : 0, (t.ms / 60000).round()),
    'lastDeck': last?.name,
    'lastDeckId': last?.id,
    'streak': streak,
    'rawStreak': p.streak,
    'lastGoalDay': p.lastGoalDay,
    'shields': p.shields,
    'best': p.bestStreak,
    'goalDays': [for (var d = t.day - 13; d <= t.day; d++) if (p.history[d]?.goal ?? false) d],
    'health': lib.health == null ? null : double.parse(lib.health!.toStringAsFixed(3)),
    'slipping': lib.slipping,
    'tomorrow': lib.tomorrow,
    'mastered': lib.mastered,
    'total': p.totalReviews,
    // Swipes per study day, the last 126 days, today last.
    'heat': [for (var d = t.day - 125; d <= t.day; d++) p.history[d]?.swipes ?? 0],
    'studyDays': p.history.values.where((r) => r.swipes > 0).length,
    // Cards that start slipping on each of the next 14 days (today's includes the ones slipping now).
    'forecast': slipForecast(store, 14),
    // The library's health and slipping count every two hours from now: recall only falls while you are away,
    // so the widget can keep its numbers right with the app closed.
    'hz': ahead.health,
    'sz': ahead.slipping,
    'member': {
      'tier': tierFor(lib.mastered, p.bestStreak),
      'name': s.name.trim().isEmpty ? 'Guest Learner' : s.name.trim(),
      'since': DateTime.fromMillisecondsSinceEpoch(p.since).year,
      'felt': feltSuccess(store),
    },
    'seals': sealsInfo(store, streak, lib.mastered),
    'decks': widgetDecks(store),
    'mix': {'slipping': mix.$1, 'decks': mix.$2},
    'cotd': cardsOfTheDay(store, now),
    'look': widgetLook(s),
    'queue': widgetQueue(store, now, size: queueSize),
  };
}

/// The user's Look settings, as the widgets read them.
Map<String, Object?> widgetLook(Settings s) => {
      'theme': s.widgetTheme,
      'accent': s.widgetAccent,
      'corners': s.widgetCorners,
      'opacity': s.widgetOpacity,
      'motion': s.widgetMotion && !s.reducedMotion,
      'quick': s.widgetQuick,
      'surfaces': s.widgetSurfaces,
    };

/// How many cards start slipping (predicted recall under 90 %) on each of the next [days] days.
List<int> slipForecast(AppStore store, int days) {
  final today = dayNumber(store.now());
  final out = List.filled(days, 0);
  for (final d in store.data.activeDecks) {
    for (final c in store.data.cardsOf(d)) {
      if (c.suspended) continue;
      final at = store.engine.slipsAt(c);
      if (at == null) continue;
      final day = math.max(0, dayNumber(at) - today);
      if (day < days) out[day]++;
    }
  }
  return out;
}

/// The library's mean predicted recall, and how many cards are slipping, every two hours from [now] for two days.
({List<double> health, List<int> slipping}) healthAhead(AppStore store, int now, {int points = 25, int stepMs = 2 * msPerHour}) {
  final cards = <CardItem>[
    for (final d in store.data.activeDecks)
      for (final c in store.data.cardsOf(d))
        if (!c.suspended && !c.isNew) c,
  ];
  final health = <double>[];
  final slipping = <int>[];
  for (var k = 0; k < points; k++) {
    final at = now + k * stepMs;
    var sum = 0.0, n = 0, slip = 0;
    for (final c in cards) {
      final r = store.engine.recall(c, at);
      if (r == null) continue;
      sum += r;
      n++;
      if (r < 0.9) slip++;
    }
    health.add(n == 0 ? 0 : double.parse((sum / n).toStringAsFixed(4)));
    slipping.add(slip);
  }
  return (health: health, slipping: slipping);
}

/// Your felt success over the last two weeks (the share of swipes you remembered), or null before any.
double? feltSuccess(AppStore store) {
  var n = 0, ok = 0;
  final today = store.today.day;
  for (var d = today - 13; d <= today; d++) {
    final r = store.data.profile.history[d];
    if (r == null) continue;
    n += r.swipes;
    ok += r.ok;
  }
  return n == 0 ? null : double.parse((ok / n).toStringAsFixed(3));
}

/// The seals: how many are earned, the latest few to show, and the one closest to being earned.
Map<String, Object?> sealsInfo(AppStore store, int streak, int mastered) {
  final p = store.data.profile;
  final latest = p.seals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final shown = <Map<String, Object?>>[];
  for (final e in latest) {
    final def = Seals.byId(e.key);
    if (def == null) continue;
    shown.add({'mark': def.mark, 'color': def.color, 'title': def.title});
    if (shown.length == 4) break;
  }
  // Milestone seals still to earn, with where you stand: the closest one wins.
  final goals = <(String, num, int, String)>[
    for (final n in const [3, 7, 14, 30, 100, 365]) ('streak-$n', streak, n, 'days'),
    for (final n in const [100, 1000, 5000]) ('reviews-$n', p.totalReviews, n, 'cards'),
    for (final n in const [10, 100]) ('mastered-$n', mastered, n, 'mastered'),
  ];
  Map<String, Object?>? next;
  var best = -1.0;
  for (final (id, have, need, unit) in goals) {
    if (p.seals.containsKey(id) || have >= need) continue;
    final f = have / need;
    final def = Seals.byId(id);
    if (def == null || f <= best) continue;
    best = f;
    next = {'mark': def.mark, 'title': def.title, 'color': def.color, 'have': have, 'need': need, 'unit': unit};
  }
  return {'earned': p.seals.length, 'total': Seals.all.length, 'latest': shown, 'next': next};
}

/// The decks the "Continue a deck" widget shows: pinned ones first, then the ones studied most recently.
List<Map<String, Object?>> widgetDecks(AppStore store, {int size = 5}) {
  final decks = store.data.activeDecks.toList()
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.lastStudied.compareTo(a.lastStudied);
    });
  return [
    for (final d in decks.take(size))
      {
        'id': d.id,
        'name': d.name,
        'cards': store.stats(d).total,
        'slipping': store.stats(d).slipping,
        'fresh': store.stats(d).fresh,
        'steps': store.stats(d).steps,
      },
  ];
}

/// The Daily mix: how many cards slip across your decks right now, and in how many decks.
(int, int) dailyMix(AppStore store) {
  var slipping = 0, decks = 0;
  for (final d in store.data.activeDecks) {
    final n = store.stats(d).slipping;
    slipping += n;
    if (n > 0) decks++;
  }
  return (slipping, decks);
}

/// Up to eight mastered cards for "Card of the day", in an order that changes each day. Only cards you know
/// cold (recall 97 % or more) are used, so seeing an answer never spoils a review that is due.
List<Map<String, Object?>> cardsOfTheDay(AppStore store, int now, {int size = 8}) {
  final day = dayNumber(now);
  final pool = <(int, double, CardItem, Deck)>[];
  for (final d in store.data.activeDecks) {
    for (final c in store.data.cardsOf(d)) {
      if (c.suspended || c.isNew || !_showable(c) || c.front.trim().isEmpty || c.back.trim().isEmpty) continue;
      final r = store.engine.recall(c, now);
      if (r == null || r < 0.97) continue;
      pool.add((_scramble(c.id, day), r, c, d));
    }
  }
  pool.sort((a, b) => a.$1.compareTo(b.$1));
  return [
    for (final (_, r, c, d) in pool.take(size))
      {
        'id': c.id,
        'deck': d.id,
        'deckName': d.name,
        'front': c.front,
        'back': c.back,
        'label': c.label,
        'hook': c.hook,
        'example': c.example,
        'r': double.parse(r.toStringAsFixed(3)),
        if (d.kind == 'code') 'mono': true,
      },
  ];
}

/// A fixed shuffle of card ids for one day (FNV-1a), so the day's cards do not change when the app restarts.
int _scramble(String id, int day) {
  var h = 0x811c9dc5 ^ day;
  for (final u in id.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0x7fffffff;
  }
  return h;
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
