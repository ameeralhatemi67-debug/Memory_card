import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/store.dart';

/// The daily reminder (RES-47 §5.3: "German · A1: 24 cards are slipping"). Local notifications only;
/// nothing is sent anywhere. Rescheduled whenever you study, so the text stays current.
class Reminders {
  Reminders._();
  static final i = Reminders._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _updateId = 2;
  static const _updatePayload = 'update';

  /// Counts taps on the update reminder; the shell opens the update card when it changes (and once at start
  /// when [updateTapPending] says a tap opened the app).
  final updateTaps = ValueNotifier<int>(0);
  bool updateTapPending = false;

  void _tapped(NotificationResponse r) {
    if (r.payload != _updatePayload) return;
    updateTapPending = true;
    updateTaps.value++;
  }

  bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init(AppStore store) async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_cards'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings, onDidReceiveNotificationResponse: _tapped);
      _ready = true;
      // The app was opened by tapping the update reminder.
      try {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true && launch?.notificationResponse?.payload == _updatePayload) _tapped(launch!.notificationResponse!);
      } catch (_) {}
      await reschedule(store);
    } catch (e) {
      debugPrint('Memory Card reminders unavailable: $e');
    }
  }

  /// Asks the OS for permission (Android 13+, iOS). Returns whether reminders can be shown.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await a?.requestNotificationsPermission() ?? true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// What tomorrow's reminder says, based on what will be slipping by then.
  static (String, String) compose(AppStore store) {
    final now = store.now();
    final tomorrow = now + 86400000;
    var slipping = 0;
    String? worstName;
    var worst = 0;
    for (final d in store.data.activeDecks) {
      var n = 0;
      for (final c in store.data.cardsOf(d)) {
        final r = store.engine.recall(c, tomorrow);
        if (r != null && r < 0.9) n++;
      }
      slipping += n;
      if (n > worst) {
        worst = n;
        worstName = d.name;
      }
    }
    final streak = store.engine.liveStreak();
    if (slipping == 0) {
      return ('Your stack is waiting', streak > 0 ? 'Keep your $streak-day streak going: a few cards is enough.' : 'Five minutes today starts a streak.');
    }
    final mins = (slipping * 6 / 60).ceil().clamp(1, 30);
    return (
      worstName == null ? '$slipping cards are slipping' : '$worstName: $worst ${worst == 1 ? 'card is' : 'cards are'} slipping',
      streak > 0 ? 'About $mins min saves them, and your $streak-day streak.' : 'About $mins min saves them.',
    );
  }

  Future<void> reschedule(AppStore store) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: 1);
      final s = store.settings;
      if (!s.remind) return;
      final (title, body) = compose(store);
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, s.remindMinutes ~/ 60, s.remindMinutes % 60);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: 1,
        title: title,
        body: body,
        scheduledDate: at,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily',
            'Daily reminder',
            channelDescription: 'One reminder a day when cards are slipping',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Memory Card could not schedule the reminder: $e');
    }
  }

  /// The one optional update reminder ("1.6.0 is still waiting"), [at] local time. A silent notice on its own
  /// channel, so Android lets you switch it off by itself.
  Future<void> scheduleUpdateReminder(String version, DateTime at) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: _updateId,
        title: 'Memory Card $version is still waiting',
        body: 'Install it whenever you are on Wi-Fi. Your cards and streak stay.',
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        payload: _updatePayload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'updates',
            'App updates',
            channelDescription: 'One quiet reminder when a new version of Memory Card is waiting',
            importance: Importance.low,
            priority: Priority.low,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Memory Card could not schedule the update reminder: $e');
    }
  }

  Future<void> cancelUpdateReminder() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _updateId);
    } catch (_) {}
  }
}
