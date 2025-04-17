// notification_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static const _storageKey = 'receivedNotifications';
  static const _unreadCountKey = 'unreadNotificationCount';
  static const _lastClearKey = 'lastNotificationClearTime';
  static const String backendInputDateFormat = 'MM/dd/yyyy HH:mm:ss';
  static const String displayDateFormat = 'MM/dd/yyyy HH:mm';

  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  NotificationService._();

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_unreadCountKey) ?? 0;
      unreadCountNotifier.value = currentCount;
    } catch (e, stacktrace) {
      print("[NotificationService] ERROR during initialize: $e\n$stacktrace");
    }
  }

  static Future<void> saveNotification(RemoteMessage message) async {
    final String callTimestamp = DateTime.now().toIso8601String();
    print("[$callTimestamp][NotificationService] saveNotification START - ID: ${message.messageId ?? 'N/A'}");

    try {
      if (message.notification == null &&
          (message.data['title'] == null || message.data['body'] == null)) {
        print("[$callTimestamp][NotificationService] Ignoring notification with no title/body (likely swipe event)");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final List<String> allNotifications = prefs.getStringList(_storageKey) ?? [];

      String title = message.notification?.title ?? message.data['title'] ?? "Başlık Yok";
      String body = message.notification?.body ?? message.data['body'] ?? "İçerik Yok";
      final String? originalTimestampStr = message.data['timestamp'] ?? message.sentTime?.toIso8601String();
      String timestampStrToParse = originalTimestampStr ?? '';

      DateTime? parsedUtcTimestamp;
      DateTime? localTimestamp;
      String formattedDate = "Tarih Yok";
      final displayFormat = DateFormat(displayDateFormat);
      final inputFormat = DateFormat(backendInputDateFormat);

      if (timestampStrToParse.isNotEmpty) {
        try {
          parsedUtcTimestamp = inputFormat.parseUtc(timestampStrToParse);
          localTimestamp = parsedUtcTimestamp.toLocal();
          formattedDate = displayFormat.format(localTimestamp);
        } catch (e) {
          localTimestamp = DateTime.now();
          parsedUtcTimestamp = localTimestamp.toUtc();
          formattedDate = displayFormat.format(localTimestamp);
        }
      } else {
        localTimestamp = DateTime.now();
        parsedUtcTimestamp = localTimestamp.toUtc();
        formattedDate = displayFormat.format(localTimestamp);
      }

      final lastClearTime = prefs.getString(_lastClearKey);
      if (lastClearTime != null) {
        final clearedAt = DateTime.tryParse(lastClearTime);
        if (clearedAt != null && parsedUtcTimestamp != null && parsedUtcTimestamp.isBefore(clearedAt)) {
          print("[$callTimestamp][NotificationService] Notification skipped (older than last clear).");
          return;
        }
      }

      final String uniqueId = message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
      Map<String, String> newNotificationData = {
        "Bildirim": body,
        "Tarih": formattedDate,
        "Title": title,
        "OriginalTimestamp": originalTimestampStr ?? "",
        "ParsedUtcTimestampIso": parsedUtcTimestamp?.toIso8601String() ?? DateTime.now().toUtc().toIso8601String(),
        "ReceivedAt": DateTime.now().toIso8601String(),
        "id": uniqueId
      };

      bool exists = allNotifications.any((n) {
        try {
          var decoded = jsonDecode(n);
          return decoded is Map && decoded['id'] == uniqueId;
        } catch (_) {
          return false;
        }
      });

      if (!exists) {
        String notificationJson = jsonEncode(newNotificationData);
        allNotifications.insert(0, notificationJson);
        const int maxNotifications = 50;
        if (allNotifications.length > maxNotifications) {
          allNotifications.removeRange(maxNotifications, allNotifications.length);
        }

        await prefs.setStringList(_storageKey, allNotifications);
        await incrementUnreadCount();
        print("[$callTimestamp][NotificationService] Notification saved. ID: $uniqueId");
      } else {
        print("[$callTimestamp][NotificationService] Duplicate notification skipped. ID: $uniqueId");
      }
    } catch (e, stacktrace) {
      print("[$callTimestamp][NotificationService] ERROR in saveNotification: $e\n$stacktrace");
    }
  }

  static Future<List<Map<String, String>>> loadNotifications() async {
    List<Map<String, String>> loadedNotifications = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final List<String> rawList = prefs.getStringList(_storageKey) ?? [];
      for (String jsonStr in rawList) {
        try {
          var decoded = jsonDecode(jsonStr);
          if (decoded is Map) {
            loadedNotifications.add(decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')));
          }
        } catch (_) {}
      }
    } catch (e) {
      print("[NotificationService] ERROR in loadNotifications: $e");
    }
    return loadedNotifications;
  }

  static Future<void> clearAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, []);
      await prefs.setString(_lastClearKey, DateTime.now().toUtc().toIso8601String());
      await prefs.commit();
      await resetUnreadCount();
      print("[NotificationService] Notifications cleared.");
    } catch (e) {
      print("[NotificationService] ERROR in clearAllNotifications: $e");
    }
  }

  static Future<void> incrementUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int current = prefs.getInt(_unreadCountKey) ?? 0;
      current++;
      await prefs.setInt(_unreadCountKey, current);
      unreadCountNotifier.value = current;
    } catch (e) {
      print("[NotificationService] ERROR in incrementUnreadCount: $e");
    }
  }

  static Future<void> resetUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, 0);
      unreadCountNotifier.value = 0;
    } catch (e) {
      print("[NotificationService] ERROR in resetUnreadCount: $e");
    }
  }

  static int getCurrentUnreadCount() {
    return unreadCountNotifier.value;
  }

  static void forceNotifyUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // <- 🔥 critical fix
    int count = prefs.getInt(_unreadCountKey) ?? 0;
    unreadCountNotifier.value = count;
    print("[NotificationService] forceNotifyUnreadCount() -> $count");
  }
}
