// notification_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static const _notificationsKey = 'fcm_notifications';
  static const _unreadCountKey = 'unread_notification_count';
  static const String backendInputDateFormat = 'MM/dd/yyyy HH:mm:ss';
  // Format for displaying the date/time in the UI (dropping seconds)
  static const String displayDateFormat = 'MM/dd/yyyy HH:mm';

  // ValueNotifier to broadcast count changes to the UI (e.g., the badge)
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier(0);

  // Initialize service (load initial count)
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    int count = prefs.getInt(_unreadCountKey) ?? 0;
    unreadCountNotifier.value = count;
  }

  // ---- Notification Storage ----

  static Future<void> saveNotification(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> allNotifications = prefs.getStringList(_notificationsKey) ?? [];

    // --- Data Extraction ---
    String title = message.notification?.title ?? "Başlık Yok"; // "No Title"
    String body = message.notification?.body ?? "İçerik Yok";  // "No Body"

    // Get the timestamp string from the message data.
    // Use the original message data timestamp for the "OriginalTimestamp" field later.
    final String? originalTimestampStr = message.data['timestamp'];
    // Use a separate variable for parsing, providing a fallback if original is null/empty.
    String timestampStrToParse = originalTimestampStr ?? '';

    DateTime? parsedUtcTimestamp; // Make nullable initially
    DateTime? localTimestamp;    // Make nullable initially
    String formattedDate = "N/A"; // Default display date

    // Define the formatters based on constants
    final inputFormat = DateFormat(backendInputDateFormat);
    final displayFormat = DateFormat(displayDateFormat);

    if (timestampStrToParse.isNotEmpty) {
      try {
        // 1. PARSE THE CUSTOM STRING AS UTC
        //    Use parseUtc() assuming the backend sent UTC time ('MM/dd/yyyy HH:mm:ss').
        //    If it's server local time, use inputFormat.parse(timestampStrToParse).
        print("Attempting to parse timestamp: '$timestampStrToParse' using format '$backendInputDateFormat'");
        parsedUtcTimestamp = inputFormat.parseUtc(timestampStrToParse);

        // 2. Convert the parsed UTC DateTime to the device's local timezone.
        localTimestamp = parsedUtcTimestamp.toLocal();

        // 3. Format the *local* time for display using the desired display format.
        formattedDate = displayFormat.format(localTimestamp);
        print("Parsed successfully. UTC: $parsedUtcTimestamp, Local: $localTimestamp, Formatted: '$formattedDate'");

      } catch (e) {
        print("Error parsing custom timestamp '$timestampStrToParse' using format '$backendInputDateFormat': $e");
        // Fallback if parsing fails: Use current time
        localTimestamp = DateTime.now(); // Use current local time
        parsedUtcTimestamp = localTimestamp.toUtc(); // Get UTC equivalent
        formattedDate = displayFormat.format(localTimestamp); // Format fallback for display
        // Update timestampStrToParse to the fallback ISO string for consistency in ParsedUtcTimestampIso below
        timestampStrToParse = parsedUtcTimestamp.toIso8601String();
        print("Using fallback time. Local: $localTimestamp, Formatted: '$formattedDate'");
      }
    } else {
      print("Timestamp string was empty or null in message data. Using fallback.");
      // Fallback if timestamp string is missing entirely: Use current time
      localTimestamp = DateTime.now(); // Use current local time
      parsedUtcTimestamp = localTimestamp.toUtc(); // Get UTC equivalent
      formattedDate = displayFormat.format(localTimestamp); // Format fallback for display
      // Update timestampStrToParse to the fallback ISO string
      timestampStrToParse = parsedUtcTimestamp.toIso8601String();
      print("Using fallback time. Local: $localTimestamp, Formatted: '$formattedDate'");
    }

    // --- Prepare Notification Data Map ---
    Map<String, String> newNotificationData = {
      "Bildirim": body,
      "Tarih": formattedDate, // Formatted *local* date/time string for display
      "Title": title,

      // Store the original string exactly as received (or empty if it was null)
      "OriginalTimestamp": originalTimestampStr ?? "",

      // Store the parsed UTC time in standard ISO format for reliable sorting later.
      // If parsing failed or timestamp was missing, this will store the fallback time's ISO string.
      "ParsedUtcTimestampIso": parsedUtcTimestamp?.toIso8601String() ?? DateTime.now().toUtc().toIso8601String(), // Ensure non-null

      "ReceivedAt": DateTime.now().toIso8601String(), // App processing time (always current)
      "id": message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString() // Unique ID
    };

    // --- Save Notification ---
    allNotifications.insert(0, jsonEncode(newNotificationData));

    // Optional: Limit the number of stored notifications
    const int maxNotifications = 50;
    if (allNotifications.length > maxNotifications) {
      // Remove the oldest items from the end of the list
      allNotifications.removeRange(maxNotifications, allNotifications.length);
    }

    // Persist the updated list to SharedPreferences
    await prefs.setStringList(_notificationsKey, allNotifications);
    print("Notification saved. Title: '$title'. OriginalTimestamp: '${newNotificationData['OriginalTimestamp']}'. Total count: ${allNotifications.length}");

    // Also increment unread count
    await incrementUnreadCount();
  }
  static Future<List<Map<String, String>>> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> notificationStrings = prefs.getStringList(_notificationsKey) ?? [];
    final List<Map<String, String>> notifications = notificationStrings.map((s) {
      try {
        // Need to cast the decoded map
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          return Map<String, String>.from(decoded.map((key, value) => MapEntry(key.toString(), value.toString())));
        }
        return <String, String>{}; // Return empty map if decode fails or isn't a map
      } catch (e) {
        print("Error decoding notification: $e");
        return <String, String>{}; // Return empty map on error
      }
    }).where((map) => map.isNotEmpty).toList(); // Filter out empty maps from errors
    return notifications;
  }

  static Future<void> clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
    await resetUnreadCount(); // Also reset count when clearing
    print("All notifications cleared.");
  }


  // ---- Unread Count Management ----

  static Future<void> incrementUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    int currentCount = prefs.getInt(_unreadCountKey) ?? 0;
    currentCount++;
    await prefs.setInt(_unreadCountKey, currentCount);
    unreadCountNotifier.value = currentCount; // Update notifier
    print("Unread count incremented: $currentCount");
  }

  static Future<void> resetUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unreadCountKey, 0);
    unreadCountNotifier.value = 0; // Update notifier
    print("Unread count reset.");
  }

  static int getCurrentUnreadCount() {
    return unreadCountNotifier.value;
  }
}