import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  String get _appId => dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  String get _restApiKey => dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Initialize OneSignal SDK on supported platforms (Android / iOS)
  Future<void> initialize() async {
    if (!_isSupportedPlatform) {
      debugPrint('[NotificationService] OneSignal is only supported on Android and iOS.');
      return;
    }

    if (_appId.isEmpty) {
      debugPrint('[NotificationService] ONESIGNAL_APP_ID is not configured in .env.');
      return;
    }

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      OneSignal.initialize(_appId);

      // Prompt for push notification permission
      await OneSignal.Notifications.requestPermission(true);

      // Listener for notification clicks
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('[NotificationService] Notification clicked: ');
      });

      debugPrint('[NotificationService] OneSignal initialized successfully.');
    } catch (e) {
      debugPrint('[NotificationService] Error initializing OneSignal: ');
    }
  }

  /// Subscribe the device to a specific school's notification channel
  Future<void> subscribeToSchool(String schoolCode) async {
    if (!_isSupportedPlatform || _appId.isEmpty) return;
    try {
      await OneSignal.User.addTagWithKey('school_code', schoolCode.trim().toUpperCase());
      debugPrint('[NotificationService] Subscribed to school: ');
    } catch (e) {
      debugPrint('[NotificationService] Failed to tag school_code: ');
    }
  }

  /// Unsubscribe device when logging out
  Future<void> unsubscribeFromSchool() async {
    if (!_isSupportedPlatform || _appId.isEmpty) return;
    try {
      await OneSignal.User.removeTag('school_code');
      debugPrint('[NotificationService] Unsubscribed from school_code tag');
    } catch (e) {
      debugPrint('[NotificationService] Failed to remove tag: ');
    }
  }

  /// Send a push notification to all students and parents subscribed to this school
  Future<bool> sendPushNotification({
    required String schoolCode,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_appId.isEmpty) {
      debugPrint('[NotificationService] Cannot send notification: ONESIGNAL_APP_ID missing');
      return false;
    }

    if (_restApiKey.isEmpty) {
      debugPrint('[NotificationService] Note: ONESIGNAL_REST_API_KEY is not set. Push simulated.');
      return true;
    }

    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final authHeader = _restApiKey.startsWith('os_v2_')
          ? 'Key '
          : 'Basic ';

      final body = {
        'app_id': _appId,
        'filters': [
          {
            'field': 'tag',
            'key': 'school_code',
            'relation': '=',
            'value': schoolCode.trim().toUpperCase(),
          }
        ],
        'headings': {'en': title, 'ar': title},
        'contents': {'en': message, 'ar': message},
        if (additionalData != null) 'data': additionalData,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': authHeader,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[NotificationService] Notification dispatched successfully: ');
        return true;
      } else {
        debugPrint('[NotificationService] Failed to dispatch notification:  - ');
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error sending notification: ');
      return false;
    }
  }
}
