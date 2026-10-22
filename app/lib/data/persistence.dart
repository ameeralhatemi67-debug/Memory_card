import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app_data.dart';
import 'models.dart';

/// Local storage on Hive (IndexedDB on the web). Everything lives on the phone; nothing leaves it.
///
/// Boxes: `meta` (settings, profile, today, engine, folders…), `decks`, `cards`, and the append-only
/// `logs` (lazy, so years of reviews never sit in memory).
class Persistence {
  Persistence._(this._meta, this._decks, this._cards, this._logs);

  static const schema = 1;

  final Box _meta;
  final Box _decks;
  final Box _cards;
  final LazyBox _logs;

  /// [path] is only for tests (a temporary folder); the app uses the platform's documents folder.
  static Future<Persistence> open({String? path}) async {
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter('memory_card');
    }
    final meta = await Hive.openBox('meta');
    final decks = await Hive.openBox('decks');
    final cards = await Hive.openBox('cards');
    final logs = await Hive.openLazyBox('logs');
    return Persistence._(meta, decks, cards, logs);
  }

  bool get isEmpty => _meta.get('v') == null;

  AppData load() {
    final data = AppData(
      folders: ((_meta.get('folders') as List?) ?? const []).map((e) => Folder.fromJson(e as Map)).toList(),
      settings: Settings.fromJson(_meta.get('settings') as Map?),
      profile: _meta.get('profile') == null ? null : Profile.fromJson(_meta.get('profile') as Map),
      today: _meta.get('today') == null ? null : Today.fromJson(_meta.get('today') as Map),
      engine: EngineState.fromJson(_meta.get('engine') as Map?),
      recentFolders: ((_meta.get('recent') as List?) ?? const []).cast<String>(),
      currentFolderId: _meta.get('current') as String?,
      lastDeckId: _meta.get('lastDeck') as String?,
      shopPins: ((_meta.get('shopPins') as List?) ?? const []).cast<String>().toSet(),
      shopAdded: ((_meta.get('shopAdded') as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v')),
      onboarded: (_meta.get('onboarded') as bool?) ?? false,
      coach: ((_meta.get('coach') as List?) ?? const []).cast<String>().toSet(),
      clockOffset: (_meta.get('clock') as num?)?.toInt() ?? 0,
    );
    for (final v in _decks.values) {
      final d = Deck.fromJson(v as Map);
      data.decks[d.id] = d;
    }
    for (final v in _cards.values) {
      final c = CardItem.fromJson(v as Map);
      data.cards[c.id] = c;
    }
    return data;
  }

  // ---- writes ----

  Future<void> saveAll(AppData data) async {
    saveMeta(data);
    await _decks.clear();
    await _cards.clear();
    await _decks.putAll({for (final d in data.decks.values) d.id: d.toJson()});
    await _cards.putAll({for (final c in data.cards.values) c.id: c.toJson()});
  }

  void saveMeta(AppData data) {
    _put(_meta, 'v', schema);
    _put(_meta, 'folders', data.folders.map((f) => f.toJson()).toList());
    _put(_meta, 'settings', data.settings.toJson());
    _put(_meta, 'profile', data.profile.toJson());
    _put(_meta, 'today', data.today?.toJson());
    _put(_meta, 'engine', data.engine.toJson());
    _put(_meta, 'recent', data.recentFolders);
    _put(_meta, 'current', data.currentFolderId);
    _put(_meta, 'lastDeck', data.lastDeckId);
    _put(_meta, 'shopPins', data.shopPins.toList());
    _put(_meta, 'shopAdded', data.shopAdded);
    _put(_meta, 'onboarded', data.onboarded);
    _put(_meta, 'coach', data.coach.toList());
    _put(_meta, 'clock', data.clockOffset);
  }

  void saveDeck(Deck d) => _put(_decks, d.id, d.toJson());
  void saveCard(CardItem c) => _put(_cards, c.id, c.toJson());
  void saveCards(Iterable<CardItem> cs) => _guard(_cards.putAll({for (final c in cs) c.id: c.toJson()}));
  void deleteDeck(String id) => _guard(_decks.delete(id));
  void deleteCards(Iterable<String> ids) => _guard(_cards.deleteAll(ids.toList()));

  Future<int> addLog(ReviewLog log) => _logs.add(log.toJson());
  Future<void> deleteLog(int key) => _logs.delete(key);
  int get logCount => _logs.length;

  /// Every review, oldest first.
  Future<List<ReviewLog>> readLogs({int? since}) async {
    final out = <ReviewLog>[];
    for (final k in _logs.keys) {
      final v = await _logs.get(k);
      if (v == null) continue;
      final log = ReviewLog.fromJson(v as Map);
      if (since == null || log.ts >= since) out.add(log);
    }
    return out;
  }

  Future<void> replaceLogs(List<ReviewLog> logs) async {
    await _logs.clear();
    for (final l in logs) {
      await _logs.add(l.toJson());
    }
  }

  Future<void> wipe() async {
    await _meta.clear();
    await _decks.clear();
    await _cards.clear();
    await _logs.clear();
  }

  /// Closes every box (tests open a fresh store per test).
  Future<void> close() => Hive.close();

  Future<void> flush() async {
    await Future.wait([_meta.flush(), _decks.flush(), _cards.flush(), _logs.flush()]);
  }

  void _put(Box box, Object key, Object? value) => _guard(box.put(key, value));

  void _guard(Future<void> f) {
    f.catchError((Object e, StackTrace st) {
      debugPrint('Memory Card storage error: $e');
    });
  }
}
