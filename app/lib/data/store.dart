import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../engine/assessor.dart';
import '../engine/days.dart';
import '../engine/seals.dart';
import '../engine/study_engine.dart';
import 'app_data.dart';
import 'card_layout.dart';
import 'catalog.dart';
import 'models.dart';
import 'persistence.dart';

final _rand = math.Random();
int _seq = 0;

/// Short unique ids: time + sequence + randomness.
String uid(String prefix) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}${_rand.nextInt(1 << 20).toRadixString(36)}';

/// Fields of a card being written in the editor.
class CardDraft {
  const CardDraft({
    required this.front,
    required this.back,
    this.label = '',
    this.example = '',
    this.hook = '',
    this.image,
    this.frontLayout,
    this.backLayout,
  });
  final String front;
  final String back;
  final String label;
  final String example;
  final String hook;

  /// The older single picture (kept so imported or old cards still show it).
  final String? image;
  final SideLayout? frontLayout;
  final SideLayout? backLayout;
}

/// Everything needed to undo one swipe exactly (RES-47 §5.1: stack, card state and review log).
class StudySnapshot {
  StudySnapshot({
    required this.deckId,
    required this.deck,
    required this.card,
    required this.today,
    required this.profile,
    required this.engine,
    this.logKey,
  });

  final String deckId;
  final Map<String, Object?> deck;
  final Map<String, Object?> card;
  final Map<String, Object?>? today;
  final Map<String, Object?> profile;
  final Map<String, Object?> engine;
  int? logKey;
}

/// The single source of truth. Screens listen to it; every change is saved to the phone right away.
class AppStore extends ChangeNotifier {
  AppStore._(this._db, this.data, this.catalog) : engine = StudyEngine(data);

  static Future<AppStore> open({String? path}) async {
    final db = await Persistence.open(path: path);
    final catalog = await Catalog.load();
    final data = db.isEmpty ? AppData() : db.load();
    final store = AppStore._(db, data, catalog);
    store.engine.ensureToday(data.now());
    store._saveMeta();
    return store;
  }

  final Persistence _db;
  final AppData data;
  final Catalog catalog;
  final StudyEngine engine;

  /// Bumps on every change (cheap cache key for derived numbers).
  int version = 0;

  int now() => data.now();
  Settings get settings => data.settings;

  void _changed() {
    version++;
    notifyListeners();
  }

  /// Tells listeners about changes made silently during a build.
  void ping() => _changed();

  void _saveMeta() => _db.saveMeta(data);

  Future<void> flush() => _db.flush();

  Future<void> close() => _db.close();

  // ---------------------------------------------------------------- derived numbers

  final Map<String, (int, int, DeckStats)> _stats = {};

  DeckStats stats(Deck d) {
    final n = now();
    final bucket = n ~/ 60000;
    final hit = _stats[d.id];
    if (hit != null && hit.$1 == version && hit.$2 == bucket) return hit.$3;
    final s = engine.deckStats(d, n);
    _stats[d.id] = (version, bucket, s);
    return s;
  }

  /// Totals over every deck outside the archive (or one folder).
  ({int total, int slipping, int strong, int mastered, int tomorrow, double? health}) libraryStats({String? folderId}) {
    var total = 0, slipping = 0, strong = 0, mastered = 0, tomorrow = 0, reviewed = 0;
    var weighted = 0.0;
    for (final f in data.folders) {
      if (folderId != null ? f.id != folderId : f.isArchive) continue;
      for (final id in f.deckIds) {
        final d = data.decks[id];
        if (d == null) continue;
        final s = stats(d);
        total += s.total;
        slipping += s.slipping;
        strong += s.strong;
        mastered += s.mastered;
        tomorrow += s.tomorrow;
        final r = s.total - s.fresh;
        if (s.health != null) {
          weighted += s.health! * r;
          reviewed += r;
        }
      }
    }
    return (
      total: total,
      slipping: slipping,
      strong: strong,
      mastered: mastered,
      tomorrow: tomorrow,
      health: reviewed == 0 ? null : weighted / reviewed,
    );
  }

  Today get today {
    engine.ensureToday(now());
    return data.today!;
  }

  /// Called on resume and by a periodic timer: starts a new study day after 04:00.
  bool tickDay() {
    if (engine.ensureToday(now())) {
      _saveMeta();
      _changed();
      return true;
    }
    return false;
  }

  Folder? get currentFolder {
    final f = data.folderById(data.currentFolderId);
    if (f != null) return f;
    return data.folders.isEmpty ? null : data.folders.first;
  }

  List<Deck> decksIn(Folder f) {
    final list = [for (final id in f.deckIds) if (data.decks[id] != null) data.decks[id]!];
    // Pinned decks first, otherwise keep the folder order.
    final pinned = list.where((d) => d.pinned).toList();
    return [...pinned, ...list.where((d) => !d.pinned)];
  }

  Folder get archive {
    final a = data.folderById(Folder.archiveId);
    if (a != null) return a;
    final f = Folder(id: Folder.archiveId, name: 'Archive', created: now());
    data.folders.add(f);
    return f;
  }

  // ---------------------------------------------------------------- folders

  Folder createFolder(String name, {bool atTop = true}) {
    final f = Folder(id: uid('f'), name: name.trim().isEmpty ? 'New folder' : name.trim(), created: now());
    if (atTop) {
      data.folders.insert(0, f);
    } else {
      final archiveAt = data.folders.indexWhere((x) => x.isArchive);
      data.folders.insert(archiveAt < 0 ? data.folders.length : archiveAt, f);
    }
    _saveMeta();
    _changed();
    return f;
  }

  void renameFolder(String id, String name) {
    final f = data.folderById(id);
    if (f == null || name.trim().isEmpty) return;
    f.name = name.trim();
    _saveMeta();
    _changed();
  }

  void moveFolder(int from, int to) {
    if (from == to || from < 0 || from >= data.folders.length) return;
    final f = data.folders.removeAt(from);
    data.folders.insert(to.clamp(0, data.folders.length), f);
    _saveMeta();
    _changed();
  }

  /// Makes [id] the current folder and the most recent one (the drawer shows the last 3 with pills).
  void touchFolder(String id) {
    data.currentFolderId = id;
    data.recentFolders = [id, ...data.recentFolders.where((x) => x != id)].take(3).toList();
    _saveMeta();
    _changed();
  }

  /// Deletes a folder with its decks and cards. Returns an undo.
  VoidCallback deleteFolder(String id) {
    final index = data.folders.indexWhere((f) => f.id == id);
    if (index < 0) return () {};
    final folder = data.folders[index];
    final decks = [for (final did in folder.deckIds) if (data.decks[did] != null) data.decks[did]!];
    final cards = [for (final d in decks) ...data.cardsOf(d)];
    final recent = [...data.recentFolders];
    final current = data.currentFolderId;
    final added = Map<String, String>.from(data.shopAdded);
    data.folders.removeAt(index);
    for (final d in decks) {
      _forgetDeck(d);
    }
    data.recentFolders.remove(id);
    if (data.currentFolderId == id) data.currentFolderId = data.folders.isEmpty ? null : data.folders.first.id;
    _saveMeta();
    _changed();
    return () {
      data.folders.insert(math.min(index, data.folders.length), folder);
      for (final d in decks) {
        data.decks[d.id] = d;
        _db.saveDeck(d);
      }
      for (final c in cards) {
        data.cards[c.id] = c;
      }
      _db.saveCards(cards);
      data.recentFolders = recent;
      data.currentFolderId = current;
      data.shopAdded
        ..clear()
        ..addAll(added);
      _saveMeta();
      _changed();
    };
  }

  void _forgetDeck(Deck d) {
    for (final cid in d.cardIds) {
      data.cards.remove(cid);
    }
    _db.deleteCards(d.cardIds);
    data.decks.remove(d.id);
    _db.deleteDeck(d.id);
    data.shopAdded.removeWhere((k, v) => v == d.id);
    if (data.lastDeckId == d.id) data.lastDeckId = null;
  }

  // ---------------------------------------------------------------- decks

  Deck createDeck({
    required String name,
    required String folderId,
    String category = 'custom',
    String? lang,
    String kind = 'text',
    String mono = '',
    String description = '',
    String level = '',
    String? catalogId,
  }) {
    final d = Deck(
      id: uid('d'),
      name: name.trim().isEmpty ? 'New deck' : name.trim(),
      mono: mono,
      category: category,
      lang: lang,
      kind: kind,
      description: description,
      level: level,
      catalogId: catalogId,
      created: now(),
    );
    data.decks[d.id] = d;
    final f = data.folderById(folderId) ?? (data.folders.isEmpty ? createFolder('Library') : data.folders.first);
    f.deckIds.insert(0, d.id);
    _db.saveDeck(d);
    _saveMeta();
    _changed();
    return d;
  }

  void saveDeck(Deck d) {
    _db.saveDeck(d);
    _changed();
  }

  VoidCallback deleteDeck(String id) {
    final d = data.decks[id];
    final f = data.folderOf(id);
    if (d == null || f == null) return () {};
    final index = f.deckIds.indexOf(id);
    final cards = data.cardsOf(d).toList();
    final added = Map<String, String>.from(data.shopAdded);
    f.deckIds.remove(id);
    _forgetDeck(d);
    _saveMeta();
    _changed();
    return () {
      data.decks[id] = d;
      for (final c in cards) {
        data.cards[c.id] = c;
      }
      _db.saveDeck(d);
      _db.saveCards(cards);
      f.deckIds.insert(math.min(index, f.deckIds.length), id);
      data.shopAdded
        ..clear()
        ..addAll(added);
      _saveMeta();
      _changed();
    };
  }

  /// Archives a deck (or restores it from the archive to where it came from). Returns an undo.
  VoidCallback archiveDeck(String id) {
    final d = data.decks[id];
    final from = data.folderOf(id);
    if (d == null || from == null) return () {};
    final index = from.deckIds.indexOf(id);
    final prevPrev = d.prevFolderId;
    final Folder to;
    if (from.isArchive) {
      to = data.folderById(d.prevFolderId) ??
          data.folders.firstWhere((f) => !f.isArchive, orElse: () => createFolder('Library', atTop: false));
      d.prevFolderId = null;
    } else {
      to = archive;
      d.prevFolderId = from.id;
    }
    from.deckIds.remove(id);
    to.deckIds.insert(0, id);
    _db.saveDeck(d);
    _saveMeta();
    _changed();
    return () {
      to.deckIds.remove(id);
      from.deckIds.insert(math.min(index, from.deckIds.length), id);
      d.prevFolderId = prevPrev;
      _db.saveDeck(d);
      _saveMeta();
      _changed();
    };
  }

  VoidCallback moveDeck(String id, String folderId) {
    final from = data.folderOf(id);
    final to = data.folderById(folderId);
    if (from == null || to == null || from.id == to.id) return () {};
    final index = from.deckIds.indexOf(id);
    from.deckIds.remove(id);
    to.deckIds.insert(0, id);
    _saveMeta();
    _changed();
    return () {
      to.deckIds.remove(id);
      from.deckIds.insert(math.min(index, from.deckIds.length), id);
      _saveMeta();
      _changed();
    };
  }

  void togglePin(String id) {
    final d = data.decks[id];
    if (d == null) return;
    d.pinned = !d.pinned;
    _db.saveDeck(d);
    _changed();
  }

  void resetDeck(String id) {
    final d = data.decks[id];
    if (d == null) return;
    final cards = data.cardsOf(d).toList();
    for (final c in cards) {
      c.resetMemory();
    }
    _db.saveCards(cards);
    d.ema = 0.75;
    d.lastStudied = 0;
    d.masteredAt = null;
    _db.saveDeck(d);
    _changed();
  }

  /// Adds a shop deck to [folderId]. New decks start with up to 15 active cards; the rest wait in the
  /// reservoir and join as you get comfortable (Intense puts them all in at once).
  Deck addCatalogDeck(String catalogId, String folderId, {bool? reverse}) {
    final cd = catalog.byId(catalogId)!;
    final d = createDeck(
      name: cd.name,
      folderId: folderId,
      category: cd.category,
      lang: cd.lang,
      kind: cd.kind,
      mono: cd.mono,
      description: cd.description,
      level: cd.level,
      catalogId: cd.id,
    );
    final rows = [
      for (final c in cd.cards)
        () {
          final (fl, bl) = cd.layoutsFor(c);
          return CardDraft(
            front: c.front,
            back: c.back,
            label: c.label,
            example: c.example,
            hook: c.hook,
            frontLayout: fl,
            backLayout: bl,
          );
        }(),
    ];
    _fillNewDeck(d, rows, reverse: reverse ?? cd.style.reverse);
    data.shopAdded[cd.id] = d.id;
    _saveMeta();
    _changed();
    return d;
  }

  void _fillNewDeck(Deck d, List<CardDraft> rows, {bool reverse = false}) {
    final created = <CardItem>[];
    final fronts = <String>[];
    final backs = <String>[];
    for (final r in rows) {
      final c = _makeCard(d, r);
      created.add(c);
      fronts.add(c.id);
      if (reverse) {
        final rc = _makeReverse(d, c);
        created.add(rc);
        backs.add(rc.id);
      }
    }
    final ordered = [...fronts, ...backs];
    final intense = engine.effectivePace(d) == 'intense';
    final k = intense ? ordered.length : math.min(15, ordered.length);
    d.stack = ordered.sublist(0, k);
    d.reservoir = ordered.sublist(k);
    _db.saveCards(created);
    _db.saveDeck(d);
  }

  CardItem _makeCard(Deck d, CardDraft r) {
    final c = CardItem(
      id: uid('c'),
      deckId: d.id,
      front: r.front.trim(),
      back: r.back.trim(),
      label: r.label.trim(),
      example: r.example.trim(),
      hook: r.hook.trim(),
      image: r.image,
      frontLayout: r.frontLayout?.copy(),
      backLayout: r.backLayout?.copy(),
      created: now(),
    );
    data.cards[c.id] = c;
    d.cardIds.add(c.id);
    return c;
  }

  CardItem _makeReverse(Deck d, CardItem c) {
    final rc = CardItem(
      id: uid('c'),
      deckId: d.id,
      front: c.back,
      back: c.front,
      label: 'reverse',
      hook: c.hook,
      // The reverse shows what the original hid: pictures swap sides along with the words.
      frontLayout: c.backLayout?.flagged(blur: false),
      backLayout: c.frontLayout?.flagged(blur: true) ?? _pictureOnBack(c),
      isReverse: true,
      siblingId: c.id,
      created: now(),
    );
    c.siblingId = rc.id;
    data.cards[rc.id] = rc;
    d.cardIds.add(rc.id);
    return rc;
  }

  /// A card that has only the older single picture: its reverse shows that picture as the answer.
  SideLayout? _pictureOnBack(CardItem c) {
    final src = c.image;
    if (src == null || src.isEmpty) return null;
    return SideLayout.forPicture(Tpl.below, back: true, src: src, blur: true);
  }

  // ---------------------------------------------------------------- cards

  int get ownCardCount => data.cards.values.where((c) {
        final d = data.decks[c.deckId];
        return d != null && d.catalogId == null && !c.isReverse;
      }).length;

  /// A card written into an existing deck joins 3 cards from the top; its reverse 10 further down.
  CardItem addCard(String deckId, CardDraft draft, {bool reverse = false}) {
    final d = data.decks[deckId]!;
    final c = _makeCard(d, draft);
    final at = math.min(3, d.stack.length);
    final stack = [...d.stack]..insert(at, c.id);
    if (reverse) {
      final rc = _makeReverse(d, c);
      stack.insert(math.min(at + 11, stack.length), rc.id);
      _db.saveCard(rc);
    }
    d.stack = stack;
    _db.saveCard(c);
    _db.saveDeck(d);
    final seals = Seals.checkAuthoring(data, ownCardCount);
    if (seals.isNotEmpty) {
      _pendingSeals.addAll(seals);
      _saveMeta();
    }
    _changed();
    return c;
  }

  void updateCard(String id, CardDraft draft) {
    final c = data.cards[id];
    if (c == null) return;
    c
      ..front = draft.front.trim()
      ..back = draft.back.trim()
      ..label = draft.label.trim()
      ..example = draft.example.trim()
      ..hook = draft.hook.trim()
      ..image = draft.image
      ..frontLayout = draft.frontLayout?.copy()
      ..backLayout = draft.backLayout?.copy();
    _db.saveCard(c);
    final sib = c.siblingId == null ? null : data.cards[c.siblingId];
    if (sib != null) {
      sib
        ..front = c.back
        ..back = c.front
        ..hook = c.hook
        ..frontLayout = c.backLayout?.flagged(blur: false)
        ..backLayout = c.frontLayout?.flagged(blur: true) ?? _pictureOnBack(c);
      _db.saveCard(sib);
    }
    _changed();
  }

  /// Adds or removes the reverse card of [id].
  void setReverse(String id, bool on) {
    final c = data.cards[id];
    if (c == null || c.isReverse) return;
    final d = data.decks[c.deckId]!;
    if (on && c.siblingId == null) {
      final rc = _makeReverse(d, c);
      final stack = [...d.stack];
      stack.insert(math.min(14, stack.length), rc.id);
      d.stack = stack;
      _db.saveCard(rc);
      _db.saveCard(c);
      _db.saveDeck(d);
    } else if (!on && c.siblingId != null) {
      final sid = c.siblingId!;
      c.siblingId = null;
      _removeCard(d, sid);
      _db.saveCard(c);
    }
    _changed();
  }

  void _removeCard(Deck d, String id) {
    data.cards.remove(id);
    d.cardIds.remove(id);
    d.stack = d.stack.where((x) => x != id).toList();
    d.reservoir = d.reservoir.where((x) => x != id).toList();
    _db.deleteCards([id]);
    _db.saveDeck(d);
  }

  VoidCallback deleteCard(String id) {
    final c = data.cards[id];
    if (c == null) return () {};
    final d = data.decks[c.deckId]!;
    final cardIdx = d.cardIds.indexOf(id);
    final stackIdx = d.stack.indexOf(id);
    final resIdx = d.reservoir.indexOf(id);
    final sib = c.siblingId == null ? null : data.cards[c.siblingId];
    _removeCard(d, id);
    if (sib != null) {
      sib.siblingId = null;
      _db.saveCard(sib);
    }
    _changed();
    return () {
      data.cards[id] = c;
      d.cardIds.insert(math.min(math.max(cardIdx, 0), d.cardIds.length), id);
      if (stackIdx >= 0) d.stack = [...d.stack]..insert(math.min(stackIdx, d.stack.length), id);
      if (resIdx >= 0) d.reservoir = [...d.reservoir]..insert(math.min(resIdx, d.reservoir.length), id);
      if (sib != null) {
        sib.siblingId = id;
        _db.saveCard(sib);
      }
      _db.saveCard(c);
      _db.saveDeck(d);
      _changed();
    };
  }

  void toggleSuspend(String id) {
    final c = data.cards[id];
    if (c == null) return;
    c.suspended = !c.suspended;
    _db.saveCard(c);
    _changed();
  }

  void resetCard(String id) {
    final c = data.cards[id];
    if (c == null) return;
    c.resetMemory();
    _db.saveCard(c);
    _changed();
  }

  /// Imported rows: into an existing deck they join near the top; a new deck is paced like a shop deck.
  int importRows(String deckId, List<CardDraft> rows, {bool reverse = false, bool newDeck = false}) {
    final d = data.decks[deckId]!;
    if (rows.isEmpty) return 0;
    if (newDeck || d.cardIds.isEmpty) {
      _fillNewDeck(d, rows, reverse: reverse);
    } else {
      final created = <CardItem>[];
      final ids = <String>[];
      for (final r in rows) {
        final c = _makeCard(d, r);
        created.add(c);
        ids.add(c.id);
        if (reverse) {
          final rc = _makeReverse(d, c);
          created.add(rc);
          d.reservoir = [...d.reservoir, rc.id];
        }
      }
      // A few join the stack now, the rest wait their turn.
      final now = math.min(5, ids.length);
      final stack = [...d.stack];
      stack.insertAll(math.min(3, stack.length), ids.take(now));
      d.stack = stack;
      d.reservoir = [...ids.skip(now), ...d.reservoir];
      _db.saveCards(created);
      _db.saveDeck(d);
    }
    _changed();
    return rows.length;
  }

  // ---------------------------------------------------------------- studying

  final List<String> _pendingSeals = [];

  /// Seals earned outside a swipe (writing cards…) waiting to be celebrated.
  List<String> takePendingSeals() {
    final out = [..._pendingSeals];
    _pendingSeals.clear();
    return out;
  }

  /// Opens a deck for study. Returns the number of warm-up cards moved to the top.
  int prepare(String deckId, {bool notify = true}) {
    final d = data.decks[deckId];
    if (d == null) return 0;
    final warm = engine.prepareDeck(d, now());
    data.lastDeckId = deckId;
    final f = data.folderOf(deckId);
    if (f != null) {
      data.currentFolderId = f.id;
      data.recentFolders = [f.id, ...data.recentFolders.where((x) => x != f.id)].take(3).toList();
    }
    _db.saveDeck(d);
    _saveMeta();
    if (notify) {
      _changed();
    } else {
      version++;
    }
    return warm;
  }

  String? top(String deckId) {
    final d = data.decks[deckId];
    if (d == null) return null;
    final before = d.stack.isEmpty ? null : d.stack.first;
    final id = engine.topCard(d, now());
    if (id != before) _db.saveDeck(d);
    return id;
  }

  StudySnapshot snapshot(String deckId, String cardId) => StudySnapshot(
        deckId: deckId,
        deck: data.decks[deckId]!.toJson(),
        card: data.cards[cardId]!.toJson(),
        today: data.today?.toJson(),
        profile: data.profile.toJson(),
        engine: data.engine.toJson(),
      );

  /// Applies a swipe and saves everything it touched.
  SwipeOutcome swipe({
    required String deckId,
    required String cardId,
    required bool recalled,
    required ReviewSignals signals,
    String mode = 'flow',
    int? forcedGrade,
    SessionMood mood = const SessionMood(),
    StudySnapshot? snapshot,
  }) {
    final d = data.decks[deckId]!;
    final out = engine.swipe(d, cardId,
        recalled: recalled, signals: signals, now: now(), mode: mode, forcedGrade: forcedGrade, mood: mood);
    _db.saveCard(data.cards[cardId]!);
    _db.saveDeck(d);
    _saveMeta();
    _db.addLog(out.log).then((k) => snapshot?.logKey = k).catchError((Object _) => 0);
    _logCache?.add(out.log);
    _changed();
    return out;
  }

  /// Undo: restores the deck, the card, the day, the profile, the engine and removes the log entry.
  void restore(StudySnapshot s) {
    final d = Deck.fromJson(s.deck);
    data.decks[d.id] = d;
    final c = CardItem.fromJson(s.card);
    data.cards[c.id] = c;
    data.today = s.today == null ? null : Today.fromJson(s.today!);
    data.profile = Profile.fromJson(s.profile);
    data.engine = EngineState.fromJson(s.engine);
    engine.weightsChanged();
    _db.saveDeck(d);
    _db.saveCard(c);
    _saveMeta();
    final key = s.logKey;
    if (key != null) _db.deleteLog(key);
    _logCache = null;
    _changed();
  }

  /// Cross-deck "Daily mix": the slipping cards of every deck, most urgent first, interleaved so the
  /// same deck rarely comes twice in a row (RES-17).
  List<(String deckId, String cardId)> buildMix({int max = 40}) {
    final n = now();
    final byDeck = <String, List<(double, String)>>{};
    for (final d in data.activeDecks) {
      for (final c in data.cardsOf(d)) {
        if (c.suspended) continue;
        final r = engine.recall(c, n);
        if (r != null && r < 0.9) byDeck.putIfAbsent(d.id, () => []).add((r, c.id));
      }
    }
    for (final l in byDeck.values) {
      l.sort((a, b) => a.$1.compareTo(b.$1));
    }
    final out = <(String, String)>[];
    String? lastDeck;
    while (out.length < max && byDeck.values.any((l) => l.isNotEmpty)) {
      final candidates = byDeck.entries.where((e) => e.value.isNotEmpty).toList()
        ..sort((a, b) => a.value.first.$1.compareTo(b.value.first.$1));
      final pick = candidates.firstWhere((e) => e.key != lastDeck, orElse: () => candidates.first);
      out.add((pick.key, pick.value.removeAt(0).$2));
      lastDeck = pick.key;
    }
    return out;
  }

  // ---------------------------------------------------------------- settings, onboarding, shop

  void updateSettings(void Function(Settings s) fn) {
    final before = settings.pace;
    fn(settings);
    if (settings.pace == Pace.intense && before != Pace.intense) {
      for (final d in data.decks.values) {
        if (d.reservoir.isNotEmpty && d.pace == null) {
          d.stack = [...d.stack, ...d.reservoir];
          d.reservoir = [];
          _db.saveDeck(d);
        }
      }
    }
    if (data.today != null && data.today!.goalHit && !engine.goalReached()) {
      // Raising the goal after reaching it keeps today's celebration; nothing to undo.
    }
    _saveMeta();
    _changed();
  }

  void setOnboarded() {
    data.onboarded = true;
    _saveMeta();
    _changed();
  }

  bool coachSeen(String id) => data.coach.contains(id);

  void markCoach(String id) {
    if (data.coach.add(id)) _saveMeta();
  }

  void resetCoach() {
    data.coach.clear();
    _saveMeta();
    _changed();
  }

  void toggleShopPin(String catalogId) {
    if (!data.shopPins.remove(catalogId)) data.shopPins.add(catalogId);
    _saveMeta();
    _changed();
  }

  /// Developer time travel (Settings › Lab).
  void shiftClock(int? ms) {
    data.clockOffset = ms == null ? 0 : data.clockOffset + ms;
    engine.ensureToday(now());
    _saveMeta();
    _changed();
  }

  void personalWeights(List<double>? w, {double? before, double? after, int trainedOn = 0}) {
    data.engine.weights = w;
    data.engine.trainedAt = now();
    data.engine.lossBefore = before;
    data.engine.lossAfter = after;
    data.engine.trainedOn = trainedOn;
    engine.weightsChanged();
    if (w != null && !data.profile.seals.containsKey('tuned')) {
      data.profile.seals['tuned'] = data.today?.day ?? dayNumber(now());
      _pendingSeals.add('tuned');
    }
    _saveMeta();
    _changed();
  }

  /// Rewrites every card's memory state (after training new weights).
  void replaceMemory(Map<String, (double, double, int)> states) {
    final changed = <CardItem>[];
    states.forEach((id, st) {
      final c = data.cards[id];
      if (c == null) return;
      c
        ..s = st.$1
        ..d = st.$2
        ..last = st.$3;
      changed.add(c);
    });
    _db.saveCards(changed);
    _changed();
  }

  /// Every review, oldest first. Read from disk once, then kept in memory and appended to.
  Future<List<ReviewLog>> logs({int? since}) async {
    final all = _logCache ??= await _db.readLogs();
    return since == null ? all : all.where((l) => l.ts >= since).toList();
  }

  List<ReviewLog>? _logCache;
  int get logCount => _db.logCount;

  // ---------------------------------------------------------------- backup

  static String _mimeOf(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.png') ? 'image/png' : (p.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
  }

  /// A picture file as a data URI (anything else — bundled `asset:` pictures, data URIs — stays as it is).
  static Object? _embedSrc(Object? src) {
    if (kIsWeb || src is! String || src.isEmpty || src.startsWith('data:') || src.startsWith('http') || src.startsWith('asset:')) return src;
    try {
      final f = File(src);
      if (!f.existsSync()) return src;
      return 'data:${_mimeOf(src)};base64,${base64Encode(f.readAsBytesSync())}';
    } catch (_) {
      return src;
    }
  }

  /// On a phone, card pictures are files: a backup carries them inline (the older single picture and
  /// every picture in a card's layouts) so they survive a move to a new phone.
  static Map<String, Object?> _embedImage(Map<String, Object?> j) {
    var out = {...j, 'img': _embedSrc(j['img'])};
    for (final key in const ['fl', 'bl']) {
      final side = j[key];
      if (side is! Map) continue;
      final els = [
        for (final e in (side['e'] as List?) ?? const [])
          if (e is Map && e['k'] == 'i') {...e, 's': _embedSrc(e['s'])} else e,
      ];
      out = {...out, key: {...side, 'e': els}};
    }
    return out;
  }

  /// The reverse of embedding: pictures that came back inside a backup are written to files again, so
  /// cards do not decode a huge data URI every time they are drawn.
  Future<void> _restorePictures() async {
    if (kIsWeb) return;
    Directory? folder;
    Future<String> toFile(String src) async {
      if (!src.startsWith('data:')) return src;
      try {
        folder ??= Directory('${(await getApplicationDocumentsDirectory()).path}/card_images');
        if (!await folder!.exists()) await folder!.create(recursive: true);
        final data = Uri.parse(src).data;
        if (data == null) return src;
        final ext = data.mimeType == 'image/png' ? 'png' : (data.mimeType == 'image/webp' ? 'webp' : 'jpg');
        final path = '${folder!.path}/${uid('img')}.$ext';
        await File(path).writeAsBytes(data.contentAsBytes(), flush: true);
        return path;
      } catch (_) {
        return src; // no storage plugin (tests): the data URI keeps working
      }
    }

    for (final c in data.cards.values) {
      final legacy = c.image;
      if (legacy != null && legacy.startsWith('data:')) c.image = await toFile(legacy);
      for (final side in [c.frontLayout, c.backLayout]) {
        if (side == null) continue;
        for (final img in side.images) {
          img.src = await toFile(img.src);
        }
      }
    }
  }

  Future<String> exportBackup() async {
    final logs = await _db.readLogs();
    final payload = {
      'app': 'memory-card',
      'v': Persistence.schema,
      'exported': DateTime.now().toUtc().toIso8601String(),
      'folders': data.folders.map((f) => f.toJson()).toList(),
      'decks': data.decks.values.map((d) => d.toJson()).toList(),
      'cards': [for (final c in data.cards.values) _embedImage(c.toJson())],
      'settings': data.settings.toJson(),
      'profile': data.profile.toJson(),
      'today': data.today?.toJson(),
      'engine': data.engine.toJson(),
      'recent': data.recentFolders,
      'current': data.currentFolderId,
      'shopPins': data.shopPins.toList(),
      'shopAdded': data.shopAdded,
      'logs': logs.map((l) => l.toJson()).toList(),
    };
    return const JsonEncoder.withIndent(' ').convert(payload);
  }

  /// Replaces everything with a backup. Throws [FormatException] if the file is not a backup.
  Future<void> importBackup(String raw) async {
    final j = jsonDecode(raw);
    if (j is! Map || j['app'] != 'memory-card' || j['folders'] is! List || j['decks'] is! List || j['cards'] is! List) {
      throw const FormatException('This file is not a Memory Card backup.');
    }
    data.folders
      ..clear()
      ..addAll((j['folders'] as List).map((e) => Folder.fromJson(e as Map)));
    data.decks
      ..clear()
      ..addEntries((j['decks'] as List).map((e) => Deck.fromJson(e as Map)).map((d) => MapEntry(d.id, d)));
    data.cards
      ..clear()
      ..addEntries((j['cards'] as List).map((e) => CardItem.fromJson(e as Map)).map((c) => MapEntry(c.id, c)));
    await _restorePictures();
    data.settings = Settings.fromJson(j['settings'] as Map?);
    if (j['profile'] is Map) data.profile = Profile.fromJson(j['profile'] as Map);
    data.today = j['today'] is Map ? Today.fromJson(j['today'] as Map) : null;
    data.engine = EngineState.fromJson(j['engine'] as Map?);
    data.recentFolders = ((j['recent'] as List?) ?? const []).cast<String>();
    data.currentFolderId = j['current'] as String?;
    data.shopPins
      ..clear()
      ..addAll(((j['shopPins'] as List?) ?? const []).cast<String>());
    data.shopAdded
      ..clear()
      ..addAll(((j['shopAdded'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v')));
    data.onboarded = true;
    engine.weightsChanged();
    engine.ensureToday(now());
    await _db.saveAll(data);
    final logs = ((j['logs'] as List?) ?? const []).map((e) => ReviewLog.fromJson(e as Map)).toList();
    await _db.replaceLogs(logs);
    _logCache = null;
    _changed();
  }

  /// Erases everything on this phone and starts over (onboarding again).
  Future<void> eraseAll() async {
    await _db.wipe();
    _logCache = null;
    data.folders.clear();
    data.decks.clear();
    data.cards.clear();
    data.settings = Settings();
    data.profile = Profile(since: now());
    data.today = null;
    data.engine = EngineState();
    data.recentFolders = [];
    data.currentFolderId = null;
    data.lastDeckId = null;
    data.shopPins.clear();
    data.shopAdded.clear();
    data.coach.clear();
    data.onboarded = false;
    data.clockOffset = 0;
    engine.weightsChanged();
    engine.ensureToday(now());
    _saveMeta();
    _changed();
  }

  /// CSV of one deck (front, back, label, example), for sharing or a spreadsheet.
  String exportDeckCsv(String deckId) {
    final d = data.decks[deckId]!;
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final lines = ['front,back,label,example'];
    for (final c in data.cardsOf(d)) {
      if (c.isReverse) continue;
      lines.add([c.front, c.back, c.label, c.example].map(q).join(','));
    }
    return lines.join('\n');
  }
}
