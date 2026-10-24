import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../data/store.dart';
import '../data/widget_snapshot.dart';
import '../engine/days.dart';

/// The Android home-screen widgets (android/app/src/main/kotlin/com/memorycard/memory_card/widgets):
/// keeps their snapshot fresh, brings Quick card answers back into the engine, and hands the app the
/// screen a tapped widget asked for. Everything is local; nothing leaves the phone.
class HomeWidgets {
  HomeWidgets._();
  static final i = HomeWidgets._();

  static const _package = 'com.memorycard.memory_card.widgets';

  /// Provider class → the name the widget picker and Settings show.
  static const kinds = {
    'SealWidget': 'Daily goal seal',
    'StreakWidget': 'Streak flame',
    'TodayWidget': 'Today',
    'QuickCardWidget': 'Quick card',
    'ActionsWidget': 'Quick actions',
    'ActionsGridWidget': 'Quick actions · grid',
    'ActivityWidget': 'Activity',
    'ForecastWidget': 'Next two weeks',
    'MembershipWidget': 'Membership card',
    'CardOfDayWidget': 'Card of the day',
    'SealsWidget': 'Seals',
    'DecksWidget': 'Continue a deck',
  };

  /// Provider class → the sizes it comes in, as the launcher counts them (columns × rows).
  static const sizes = {
    'SealWidget': '1×1 to 2×2',
    'StreakWidget': '1×1 to 4×1',
    'TodayWidget': '4×2 or 4×3',
    'QuickCardWidget': '4×2 or 4×3',
    'ActionsWidget': '1×1 to 4×1',
    'ActionsGridWidget': '2×2',
    'ActivityWidget': '2×2 to 4×2',
    'ForecastWidget': '4×2 or 4×3',
    'MembershipWidget': '4×2',
    'CardOfDayWidget': '4×1 or 4×2',
    'SealsWidget': '3×1 or 4×1',
    'DecksWidget': '4×1 to 4×3',
  };

  /// The size (dp) each widget is previewed at in Settings: its first size in the widget picker.
  static const previewSize = {
    'SealWidget': (172.0, 233.0),
    'StreakWidget': (172.0, 108.0),
    'TodayWidget': (360.0, 233.0),
    'QuickCardWidget': (360.0, 233.0),
    'ActionsWidget': (360.0, 108.0),
    'ActionsGridWidget': (172.0, 233.0),
    'ActivityWidget': (360.0, 233.0),
    'ForecastWidget': (360.0, 233.0),
    'MembershipWidget': (360.0, 233.0),
    'CardOfDayWidget': (360.0, 233.0),
    'SealsWidget': (360.0, 108.0),
    'DecksWidget': (360.0, 233.0),
  };

  static const _channel = MethodChannel('memorycard/widgets');

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// A picture (PNG) of widget [cls] at [w]×[h] dp, drawn by the home-screen code from the live numbers with
  /// [look] (the Look settings, as widgetLook gives them), so Settings can show a choice as it is made.
  Future<Uint8List?> preview(String cls, {required Map<String, Object?> look, required bool night, double? w, double? h}) async {
    if (!supported) return null;
    final size = previewSize[cls];
    if (size == null) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('preview', {'cls': cls, 'w': w ?? size.$1, 'h': h ?? size.$2, 'night': night, 'look': look});
    } catch (e) {
      debugPrint('Memory Card widgets: no preview of $cls: $e');
      return null;
    }
  }

  /// Asks Android to add the Memory Card tile to Quick Settings: added · already · declined · unsupported.
  Future<String> addTile() async {
    if (!supported) return 'unsupported';
    try {
      return await _channel.invokeMethod<String>('addTile') ?? 'unsupported';
    } catch (_) {
      return 'unsupported';
    }
  }

  AppStore? _store;
  Timer? _debounce;
  void Function(Uri uri)? _onOpen;
  Uri? _waiting;

  /// Quick card answers the app has not applied yet, oldest first.
  Future<List<WidgetReview>> pendingReviews() async {
    if (!supported) return const [];
    try {
      final raw = await HomeWidget.getWidgetData<String>(WidgetKeys.inbox);
      return WidgetReview.parseInbox(raw, await _applied());
    } catch (e) {
      debugPrint('Memory Card widgets: inbox unreadable: $e');
      return const [];
    }
  }

  Future<int> _applied() async => int.tryParse(await HomeWidget.getWidgetData<String>(WidgetKeys.applied) ?? '') ?? 0;

  /// Moves the watermark past [reviews] so the widget drops them and the app never applies them twice.
  Future<void> markApplied(List<WidgetReview> reviews) async {
    if (!supported || reviews.isEmpty) return;
    try {
      final newest = math.max(await _applied(), reviews.map((r) => r.ts).reduce(math.max));
      await HomeWidget.saveWidgetData<String>(WidgetKeys.applied, '$newest');
    } catch (e) {
      debugPrint('Memory Card widgets: could not mark answers applied: $e');
    }
  }

  /// Keeps the widgets in step with [store] from now on.
  Future<void> attach(AppStore store) async {
    if (!supported || _store != null) return;
    _store = store;
    store.addListener(_schedule);
    try {
      HomeWidget.widgetClicked.listen(_open);
      _open(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (e) {
      debugPrint('Memory Card widgets: clicks unavailable: $e');
    }
    await publish();
  }

  /// Where tapped widgets go. An address that arrived before the app was ready is delivered now.
  void listen(void Function(Uri uri) onOpen) {
    _onOpen = onOpen;
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null) WidgetsBinding.instance.addPostFrameCallback((_) => onOpen(waiting));
  }

  void _open(Uri? uri) {
    if (uri == null || uri.scheme != 'memorycard') return;
    final onOpen = _onOpen;
    if (onOpen == null) {
      _waiting = uri;
    } else {
      onOpen(uri);
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), publish);
  }

  /// Writes the snapshot and redraws every widget. Also books a redraw for the next 04:00 (a new study day)
  /// and for 18:00 (the streak starts asking to be kept).
  Future<void> publish() async {
    _debounce?.cancel();
    final store = _store;
    if (store == null) return;
    try {
      await HomeWidget.saveWidgetData<String>(WidgetKeys.snapshot, jsonEncode(buildWidgetSnapshot(store)));
      final times = _redrawTimes(store);
      for (final k in kinds.keys) {
        await HomeWidget.updateWidget(qualifiedAndroidName: '$_package.$k');
        await HomeWidget.scheduleWidgetUpdates(times, qualifiedAndroidName: '$_package.$k');
      }
    } catch (e) {
      debugPrint('Memory Card widgets: publish failed: $e');
    }
  }

  List<DateTime> _redrawTimes(AppStore store) {
    final offset = store.data.clockOffset;
    final now = store.now();
    final day = DateTime.fromMillisecondsSinceEpoch(now - dayRolloverHour * msPerHour);
    final rollover = DateTime(day.year, day.month, day.day + 1, dayRolloverHour, 0, 5);
    final evening = DateTime(day.year, day.month, day.day, 18);
    return [
      if (evening.millisecondsSinceEpoch > now) evening,
      rollover,
    ].map((t) => DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch - offset)).toList();
  }

  /// Back in the app: applies the Quick card answers given meanwhile, then redraws.
  Future<void> catchUp() async {
    final store = _store;
    if (store == null) return;
    final reviews = await pendingReviews();
    if (reviews.isNotEmpty) {
      store.applyWidgetReviews(reviews);
      await markApplied(reviews);
    }
    await publish();
  }

  Future<bool> canPin() async {
    if (!supported) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the launcher to place a widget (it shows its own confirmation).
  Future<void> pin(String kind) => HomeWidget.requestPinWidget(qualifiedAndroidName: '$_package.$kind');
}
