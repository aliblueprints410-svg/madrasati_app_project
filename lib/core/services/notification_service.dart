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
        debugPrint('[NotificationService] Notification clicked: ${event.notification.notificationId}');
      });

      debugPrint('[NotificationService] OneSignal initialized successfully.');
    } catch (e) {
      debugPrint('[NotificationService] Error initializing OneSignal: $e');
    }
  }

  /// Explicitly prompt the user for notification permissions (can be called from UI when mounted)
  Future<bool> requestPermission() async {
    if (!_isSupportedPlatform) return false;
    try {
      final granted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('[NotificationService] Notification permission status: $granted');
      return granted;
    } catch (e) {
      debugPrint('[NotificationService] Error requesting notification permission: $e');
      return false;
    }
  }

  /// Check if notification permission is currently granted
  bool get hasNotificationPermission {
    if (!_isSupportedPlatform) return false;
    try {
      return OneSignal.Notifications.permission;
    } catch (_) {
      return false;
    }
  }

  /// Check push subscription status
  bool get isSubscribed {
    if (!_isSupportedPlatform) return false;
    try {
      return OneSignal.User.pushSubscription.optedIn ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get the current device subscription ID
  String? get subscriptionId {
    if (!_isSupportedPlatform) return null;
    try {
      return OneSignal.User.pushSubscription.id;
    } catch (_) {
      return null;
    }
  }

  /// Send an immediate test notification
  Future<bool> sendTestNotification({
    required String schoolCode,
    String? classId,
  }) async {
    return sendPushNotification(
      schoolCode: schoolCode,
      classId: classId,
      title: '🔔 إشعار فحص من تطبيق مدرستي',
      message: 'هذا إشعار تجريبي للتأكد من وصول الإشعارات إلى هاتفك بنجاح!',
      additionalData: {'type': 'test'},
    );
  }

  /// Subscribe the device to a specific school and optionally a specific class
  Future<void> subscribeToSchool(String schoolCode, {String? classId}) async {
    if (!_isSupportedPlatform || _appId.isEmpty) return;
    try {
      final cleanSchool = schoolCode.trim().toUpperCase();
      await OneSignal.User.addTagWithKey('school_code', cleanSchool);
      if (classId != null && classId.trim().isNotEmpty) {
        await OneSignal.User.addTagWithKey('class_id', classId.trim());
      }
      debugPrint('[NotificationService] Subscribed to school: $cleanSchool, class: $classId');
    } catch (e) {
      debugPrint('[NotificationService] Failed to tag school/class: $e');
    }
  }

  /// Subscribe or update the specific class tag for the student
  Future<void> subscribeToClass({required String schoolCode, required String classId}) async {
    if (!_isSupportedPlatform || _appId.isEmpty) return;
    try {
      final cleanSchool = schoolCode.trim().toUpperCase();
      final cleanClass = classId.trim();
      await OneSignal.User.addTagWithKey('school_code', cleanSchool);
      await OneSignal.User.addTagWithKey('class_id', cleanClass);
      debugPrint('[NotificationService] Subscribed to class: $cleanClass in school: $cleanSchool');
    } catch (e) {
      debugPrint('[NotificationService] Failed to tag class_id: $e');
    }
  }

  /// Unsubscribe device when logging out
  Future<void> unsubscribeFromSchool() async {
    if (!_isSupportedPlatform || _appId.isEmpty) return;
    try {
      await OneSignal.User.removeTag('school_code');
      await OneSignal.User.removeTag('class_id');
      debugPrint('[NotificationService] Unsubscribed from school_code and class_id tags');
    } catch (e) {
      debugPrint('[NotificationService] Failed to remove tags: $e');
    }
  }

  /// Send a push notification.
  /// If [classId] is provided, it targets ONLY students/devices in that specific class within the school.
  /// If [classId] is omitted or null, it targets ALL students/devices in the school (e.g. general announcements).
  Future<bool> sendPushNotification({
    required String schoolCode,
    String? classId,
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
      final url = Uri.parse('https://api.onesignal.com/notifications');
      final authHeader = _restApiKey.startsWith('os_v2_')
          ? 'Key $_restApiKey'
          : 'Basic $_restApiKey';

      final cleanSchool = schoolCode.trim().toUpperCase();
      final List<Map<String, dynamic>> filters = [
        {
          'field': 'tag',
          'key': 'school_code',
          'relation': '=',
          'value': cleanSchool,
        },
      ];

      // If classId is specified, target only this class in this school
      if (classId != null && classId.trim().isNotEmpty) {
        filters.add({'operator': 'AND'});
        filters.add({
          'field': 'tag',
          'key': 'class_id',
          'relation': '=',
          'value': classId.trim(),
        });
      }

      final body = {
        'app_id': _appId,
        'filters': filters,
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
        debugPrint('[NotificationService] Notification dispatched successfully: ${response.body}');
        return true;
      } else {
        debugPrint('[NotificationService] Failed to dispatch notification: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error sending notification: $e');
      return false;
    }
  }
}
