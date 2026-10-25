import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'reminders.dart';

/// What GitHub says the newest release is, cut down to what the update card shows.
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    this.build = 0,
    this.notes = const [],
    this.size = 0,
    this.downloadUrl = Updates.downloadUrl,
    this.pageUrl = Updates.pageUrl,
    this.important = false,
  });

  /// "1.6.0" (the release tag without its v).
  final String version;

  /// The +N after the version in the tag, 0 when the tag has none.
  final int build;

  /// Up to three short lines, the first bullets of the release notes.
  final List<String> notes;

  /// Bytes of MemoryCard.apk, 0 when unknown.
  final int size;
  final String downloadUrl;
  final String pageUrl;

  /// The release notes start with "Important:".
  final bool important;

  /// "150 MB" (decimal, as the release notes say it); empty when the size is unknown.
  String get megabytes => size <= 0 ? '' : '${(size / 1e6).round()} MB';

  Map<String, Object?> toJson() => {
        'v': version,
        'b': build,
        'notes': notes,
        'size': size,
        'dl': downloadUrl,
        'page': pageUrl,
        'imp': important,
      };

  /// What the latest-release address answers, cut down to the card's facts; null for a draft, a pre-release or a
  /// tag that is not a version.
  static UpdateInfo? fromRelease(Object? json) {
    if (json is! Map || json['draft'] == true || json['prerelease'] == true) return null;
    final tag = json['tag_name'];
    final v = tag is String ? Updates.parseVersion(tag) : null;
    if (v == null) return null;
    var download = Updates.downloadUrl;
    var size = 0;
    final assets = json['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is Map && a['name'] == 'MemoryCard.apk') {
          size = (a['size'] as num?)?.toInt() ?? 0;
          download = Updates._github(a['browser_download_url'], Updates.downloadUrl);
        }
      }
    }
    final body = (json['body'] as String?) ?? '';
    return UpdateInfo(
      version: '${v[0]}.${v[1]}.${v[2]}',
      build: v[3],
      notes: Updates.notesFrom(body),
      size: size,
      downloadUrl: download,
      pageUrl: Updates._github(json['html_url'], Updates.pageUrl),
      important: body.trimLeft().startsWith('Important:'),
    );
  }

  static UpdateInfo? fromJson(Map<String, Object?> j) {
    final v = j['v'];
    if (v is! String || v.isEmpty) return null;
    return UpdateInfo(
      version: v,
      build: (j['b'] as num?)?.toInt() ?? 0,
      notes: [for (final n in (j['notes'] as List?) ?? const []) '$n'],
      size: (j['size'] as num?)?.toInt() ?? 0,
      downloadUrl: Updates._github(j['dl'], Updates.downloadUrl),
      pageUrl: Updates._github(j['page'], Updates.pageUrl),
      important: j['imp'] == true,
    );
  }
}

/// GitHub answered with something other than 200.
class UpdateHttpException implements Exception {
  UpdateHttpException(this.status);
  final int status;
  @override
  String toString() => 'GitHub answered $status';
}

/// Update notices for APK installs from GitHub: once a day, when the app opens, it asks GitHub's latest-release
/// address what is newest. A newer, unskipped version shows as the update card and a gold 1 on the + card.
/// Nothing is downloaded without a tap, nothing but the version number is read, and nothing about you is sent.
class Updates extends ChangeNotifier {
  Updates._();
  static final i = Updates._();

  static const repo = 'ameeralhatemi67-debug/Memory_card';
  static final api = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
  static const downloadUrl = 'https://github.com/$repo/releases/latest/download/MemoryCard.apk';
  static const pageUrl = 'https://github.com/$repo/releases/latest';

  /// A link read from the answer must stay inside this project's own releases.
  static String _github(Object? v, String fallback) => v is String && v.startsWith('https://github.com/$repo/') ? v : fallback;

  AppStore? _store;

  /// The running build: "1.5.0" and "10". Empty until known (and in tests).
  String installed = '';
  String build = '';

  bool checking = false;

  /// Whether the last check got an answer: null before the first one.
  bool? lastOk;
  DateTime _lastTry = DateTime.fromMillisecondsSinceEpoch(0);

  /// The phone asked GitHub; tests answer for it.
  @visibleForTesting
  Future<String> Function(Uri uri) fetcher = _httpGet;

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// Tests start each case without a failed try or a check in flight.
  @visibleForTesting
  void forgetTries() {
    _lastTry = DateTime.fromMillisecondsSinceEpoch(0);
    checking = false;
  }

  Settings? get _s => _store?.settings;

  /// Starts watching: reads the running version, books or drops the reminder, and checks if a day has passed.
  Future<void> attach(AppStore store, {String? installedVersion, String? buildNumber}) async {
    _store = store;
    if (installedVersion != null) {
      installed = installedVersion;
      build = buildNumber ?? '';
    } else {
      try {
        final p = await PackageInfo.fromPlatform();
        installed = p.version;
        build = p.buildNumber;
      } catch (_) {}
    }
    notifyListeners();
    await syncReminder();
    unawaited(maybeCheck());
  }

  /// A made-up newer version, to see the card and the fan (Settings › Updates › Preview). Never saved.
  UpdateInfo? _preview;
  bool get previewing => _preview != null;

  void startPreview() {
    final v = parseVersion(installed);
    _preview = UpdateInfo(
      version: v == null ? '1.6.0' : '${v[0]}.${v[1] + 1}.0',
      size: 150000000,
      notes: const [
        'Reminders say the real minutes and back off when you are away',
        'A Today strip on Home, plus a session timer',
        'Fix: widgets keep their size after an update',
      ],
    );
    notifyListeners();
  }

  void clearPreview() {
    if (_preview == null) return;
    _preview = null;
    notifyListeners();
  }

  UpdateInfo? get latest => _preview ?? (_s == null ? null : UpdateInfo.fromJson(_s!.updateLatest));

  /// A newer version than the one running, and not one you skipped.
  bool get available {
    if (_preview != null) return true;
    final l = latest;
    final s = _s;
    if (l == null || s == null || installed.isEmpty || l.version == s.updateSkipped) return false;
    return isNewer(l.version, l.build, installed, int.tryParse(build) ?? 0);
  }

  /// The card should deal itself out of the + once for each new version.
  bool get dealPending => _preview == null && available && _s!.updateDealt != latest!.version;

  bool get skipped {
    final l = latest;
    return l != null && _s != null && l.version == _s!.updateSkipped;
  }

  /// Once a day: at most every 20 hours since the last answer, and not again within 30 minutes of a failed try.
  Future<void> maybeCheck() async {
    final s = _s;
    if (s == null || !s.updateCheck) return;
    final now = clock();
    if (now.millisecondsSinceEpoch - s.updateChecked < 20 * 3600 * 1000) return;
    if (now.difference(_lastTry) < const Duration(minutes: 30)) return;
    await check();
  }

  /// Asks GitHub now ("Check now" and the daily check).
  Future<void> check() async {
    final store = _store;
    if (store == null || checking) return;
    checking = true;
    _lastTry = clock();
    notifyListeners();
    try {
      final info = UpdateInfo.fromRelease(jsonDecode(await fetcher(api)));
      store.updateSettings((s) {
        s.updateLatest = info?.toJson() ?? {};
        s.updateChecked = clock().millisecondsSinceEpoch;
      });
      lastOk = true;
    } on UpdateHttpException catch (e) {
      if (e.status == 404) {
        // A project with no release yet: nothing newer than what you have.
        store.updateSettings((s) {
          s.updateLatest = {};
          s.updateChecked = clock().millisecondsSinceEpoch;
        });
        lastOk = true;
      } else {
        lastOk = false;
      }
    } catch (e) {
      lastOk = false;
      debugPrint('Memory Card update check failed: $e');
    } finally {
      checking = false;
      notifyListeners();
      unawaited(syncReminder());
    }
  }

  /// The card has been dealt for this version: it will not deal itself again.
  void markDealt() {
    final l = latest;
    final store = _store;
    if (l == null || store == null || _preview != null) return;
    store.updateSettings((s) {
      s.updateDealt = l.version;
      s.updateDealtAt = clock().millisecondsSinceEpoch;
    });
    notifyListeners();
    unawaited(syncReminder());
  }

  void skip() {
    final l = latest;
    if (l == null || _store == null || _preview != null) return;
    _store!.updateSettings((s) => s.updateSkipped = l.version);
    notifyListeners();
    unawaited(syncReminder());
  }

  void unskip() {
    if (_store == null) return;
    _store!.updateSettings((s) => s.updateSkipped = '');
    notifyListeners();
    unawaited(syncReminder());
  }

  void setCheck(bool on) {
    _store?.updateSettings((s) => s.updateCheck = on);
    notifyListeners();
    if (on) unawaited(maybeCheck());
  }

  void setRemind(bool on) {
    _store?.updateSettings((s) => s.updateRemind = on);
    notifyListeners();
    unawaited(syncReminder());
  }

  Future<bool> openDownload() => _open(Uri.parse(latest?.downloadUrl ?? downloadUrl));
  Future<bool> openNotes() => _open(Uri.parse(latest?.pageUrl ?? pageUrl));

  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// The one optional reminder: 4 days after the card first appeared, at your reminder time, while the update is
  /// still waiting. Booked from the day it first appeared, so opening the app does not keep pushing it back.
  Future<void> syncReminder() async {
    final s = _s;
    final l = latest;
    if (s == null || _preview != null) return;
    final due = reminderAt();
    if (!s.updateRemind || !available || l == null || due == null) {
      await Reminders.i.cancelUpdateReminder();
      return;
    }
    await Reminders.i.scheduleUpdateReminder(l.version, due);
  }

  /// When the reminder is due, or null when it cannot be: no card yet, or four days have already passed.
  DateTime? reminderAt() {
    final s = _s;
    final l = latest;
    if (s == null || l == null || s.updateDealt != l.version || s.updateDealtAt <= 0) return null;
    final base = DateTime.fromMillisecondsSinceEpoch(s.updateDealtAt).add(const Duration(days: 4));
    final at = DateTime(base.year, base.month, base.day, s.remindMinutes ~/ 60, s.remindMinutes % 60);
    return at.isAfter(clock()) ? at : null;
  }

  static Future<String> _httpGet(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      req.headers
        ..set('Accept', 'application/vnd.github+json')
        ..set('User-Agent', 'MemoryCard');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw UpdateHttpException(res.statusCode);
      }
      return await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));
    } finally {
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------------- versions and notes

  static final _ver = RegExp(r'^\s*v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?');

  /// "v1.6.0" → [1, 6, 0, 0]; "1.5.0+10" → [1, 5, 0, 10]; null when it is not a version.
  static List<int>? parseVersion(String s) {
    final m = _ver.firstMatch(s);
    if (m == null) return null;
    return [for (var g = 1; g <= 4; g++) int.tryParse(m.group(g) ?? '') ?? 0];
  }

  /// Whether [latest] is a later release than [installed]: by version, then by build number when the tag gives one.
  static bool isNewer(String latest, int latestBuild, String installed, int installedBuild) {
    final a = parseVersion(latest);
    final b = parseVersion(installed);
    if (a == null || b == null) return false;
    for (var k = 0; k < 3; k++) {
      if (a[k] != b[k]) return a[k] > b[k];
    }
    final lb = latestBuild > 0 ? latestBuild : a[3];
    return lb > 0 && lb > installedBuild;
  }

  /// The first three bullets of the release notes, as plain short lines.
  static List<String> notesFrom(String body) {
    final out = <String>[];
    for (final raw in const LineSplitter().convert(body)) {
      final line = raw.trim();
      if (!line.startsWith('- ') && !line.startsWith('* ')) continue;
      final text = line
          .substring(2)
          .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
          .replaceAll(RegExp(r'[*`]+'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text.isEmpty) continue;
      out.add(_short(text));
      if (out.length == 3) break;
    }
    return out;
  }

  /// One sentence, and no more than [max] characters.
  static String _short(String t, [int max = 80]) {
    final stop = t.indexOf('. ');
    if (stop > 12 && stop < max) return t.substring(0, stop + 1);
    if (t.length <= max) return t;
    final cut = t.lastIndexOf(' ', max);
    return '${t.substring(0, cut > 40 ? cut : max).trimRight()}…';
  }
}
