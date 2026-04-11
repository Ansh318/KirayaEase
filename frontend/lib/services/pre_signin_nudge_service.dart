import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One-time local notification if the user opens the app but never signs in.
/// (Remote FCM is only registered after login, so this must be local.)
class PreSigninNudgeService {
  PreSigninNudgeService._();

  static const int _notificationId = 94001;
  static const String _kEverSignedIn = 'kirayaease_ever_signed_in_v1';
  static const String _kNudgeScheduled = 'kirayaease_pre_signin_nudge_scheduled_v1';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> _ensurePluginReady() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  /// Call from [main] after Firebase init. Schedules at most once per install
  /// while the user has no session and has never completed sign-in.
  static Future<void> syncOnLaunch() async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kEverSignedIn) == true) {
      await cancelPendingNudge();
      return;
    }

    final session = prefs.getString('session_id')?.trim();
    if (session != null && session.isNotEmpty) {
      await cancelPendingNudge();
      return;
    }

    if (prefs.getBool(_kNudgeScheduled) == true) return;

    await _ensurePluginReady();

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      if (granted == false) return;
    }

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final ok = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (ok == false) return;
    }

    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    final when = tz.TZDateTime.now(tz.local).add(const Duration(hours: 48));
    try {
      await _plugin.zonedSchedule(
        _notificationId,
        'KirayaEase',
        'Join in to simplify rent management — sign in when you\'re ready.',
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'pre_signin_reminders',
            'Getting started',
            channelDescription:
                'A gentle reminder if you have not signed in yet.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint('[PreSigninNudge] schedule failed: $e\n$st');
      return;
    }

    await prefs.setBool(_kNudgeScheduled, true);
  }

  /// Call after a successful backend login (Google or Apple).
  static Future<void> onUserSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEverSignedIn, true);
    await cancelPendingNudge();
  }

  static Future<void> cancelPendingNudge() async {
    if (kIsWeb) return;
    await _ensurePluginReady();
    await _plugin.cancel(_notificationId);
  }
}
