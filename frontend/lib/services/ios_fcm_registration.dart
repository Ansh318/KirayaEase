import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Registers the device FCM token with KirayaEase API (iOS only for now).
class IosFcmRegistration {
  IosFcmRegistration._();

  static bool _refreshListenerAttached = false;

  static Future<void> _postToken(String sessionId, String token) async {
    final uri = Uri.parse(ApiConfig.fcmTokenEndpoint);
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $sessionId',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fcm_token': token, 'platform': 'ios'}),
    );
    // Always log (release too) — visible in Xcode device logs when /me/push-test says no token.
    final snippet = resp.body.length > 160
        ? '${resp.body.substring(0, 160)}...'
        : resp.body;
    debugPrint('[KirayaEase FCM] POST ${uri.path} -> ${resp.statusCode} $snippet');
  }

  static void _ensureTokenRefreshListener() {
    if (_refreshListenerAttached) return;
    _refreshListenerAttached = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      final sid = prefs.getString('session_id')?.trim();
      if (sid == null || sid.isEmpty) return;
      try {
        await _postToken(sid, newToken);
      } catch (e) {
        debugPrint('FCM onTokenRefresh post failed: $e');
      }
    });
  }

  /// Call after login or when the main dashboard loads with a valid session.
  static Future<void> registerIfIosAndLoggedIn() async {
    if (kIsWeb || !Platform.isIOS) return;

    final prefs = await SharedPreferences.getInstance();
    final session = prefs.getString('session_id')?.trim();
    if (session == null || session.isEmpty) return;

    _ensureTokenRefreshListener();

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!ok) {
      debugPrint(
        '[KirayaEase FCM] notification permission denied: ${settings.authorizationStatus}',
      );
      return;
    }

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[KirayaEase FCM] getToken() returned empty (use physical device)');
      return;
    }

    try {
      await _postToken(session, token);
    } catch (e) {
      debugPrint('FCM token register failed: $e');
    }
  }
}
