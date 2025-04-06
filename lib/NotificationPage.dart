// -------- Start of NotificationPage.dart --------
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:intl/intl.dart';

// Import the notification service
import 'notification_service.dart'; // Make sure this path is correct

class NotificationPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, String>> _receivedNotifications = [];
  StreamSubscription? _fcmSubscription;
  bool _isLoading = true; // Loading state

  @override
  void initState() {
    super.initState();
    _loadAndSetupNotifications();
  }

  Future<void> _loadAndSetupNotifications() async {
    // Load existing notifications from storage
    final loadedNotifications = await NotificationService.loadNotifications();
    if (mounted) {
      setState(() {
        _receivedNotifications = loadedNotifications;
        _isLoading = false; // Done loading
      });
    }

    // Reset the unread count now that the user is viewing the page
    await NotificationService.resetUnreadCount();

    // Setup listener for new foreground messages while this page is open
    _setupFcmListeners();
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    super.dispose();
  }

  /// Sets up the listener for foreground FCM messages while page is active.
  void _setupFcmListeners() {
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground Message received on NotificationPage!');

      // NotificationService already saved it and updated count via main.dart listener.
      // We just need to update the local UI list immediately.

      // Extract data (duplicate logic from service, could be refactored)
      String title = message.notification?.title ?? "No Title";
      String body = message.notification?.body ?? "No Body";
      String timestampStr = message.data['timestamp'] ?? DateTime.now().toIso8601String();
      DateTime timestamp;
      String formattedDate = "N/A";
      try {
        timestamp = DateTime.parse(timestampStr).toLocal();
        formattedDate = DateFormat('MM/dd/yyyy HH:mm').format(timestamp);
      } catch (e) {
        timestamp = DateTime.now();
        formattedDate = DateFormat('MM/dd/yyyy HH:mm').format(timestamp);
        print("Error parsing timestamp in NotificationPage listener: $e"); // Log parsing error
      }
      Map<String, String> newNotification = {
        "Bildirim": body,
        "Tarih": formattedDate,
        "Title": title,
        "OriginalTimestamp": timestampStr,
        "ReceivedAt": DateTime.now().toIso8601String(),
        "id": message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString()
      };


      // Add to local list for immediate UI update if mounted
      if (mounted) {
        setState(() {
          // Avoid duplicates if message handled multiple times (rarely needed but safe)
          bool exists = _receivedNotifications.any((n) => n['id'] == newNotification['id']);
          if (!exists) {
            _receivedNotifications.insert(0, newNotification);
          }
        });
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.cyanAccent),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        "Bildirimler",
        style: TextStyle(
          color: Colors.cyanAccent,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      actions: [ // Optional: Add a clear all button
        IconButton(
            icon: Icon(Icons.delete_sweep, color: Colors.redAccent.withOpacity(0.8)),
            tooltip: "Clear All Notifications",
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.blueGrey.shade800,
                  title: Text("Clear Notifications?", style: TextStyle(color: Colors.white)),
                  content: Text("This will remove all notifications from this list.", style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: ()=> Navigator.of(ctx).pop(false), child: Text("Cancel", style: TextStyle(color: Colors.cyanAccent))),
                    TextButton(onPressed: ()=> Navigator.of(ctx).pop(true), child: Text("Clear All", style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await NotificationService.clearAllNotifications();
                setState(() {
                  _receivedNotifications = []; // Clear local list
                });
              }
            }
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      width: double.infinity, // Ensure container takes full width
      height: double.infinity, // Ensure container takes full height
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Colors.blueGrey.shade900,
            Colors.blueGrey.shade800,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            Expanded( // Allow table container to take available space
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              // *** CHANGE: Always call _buildNotificationTable when not loading ***
                  : _buildNotificationTable(),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates the container and the Table structure for notifications.
  /// This widget is now always built when not loading.
  Widget _buildNotificationTable() {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.blueGrey.shade900.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.8), width: 1.5), // Thinner border
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.15),
              blurRadius: 6,
              spreadRadius: 1,
            )
          ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9), // Slightly smaller radius for clipping
        // *** CHANGE: Use a Column to hold the header and the list/empty message ***
        child: Column(
          children: [
            // 1. Always build the Header Row
            _buildTableRowWidget("Bildirim", "Tarih", isHeader: true),

            // 2. Build the list *or* the empty message
            Expanded( // Let the content fill the remaining space
              child: _receivedNotifications.isEmpty
              // Show "No notifications" message if list is empty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0), // Add some padding
                  child: Text(
                    "Henüz bildirim yok.", // "No notifications yet."
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              )
              // Otherwise, build the list using ListView.builder
                  : ListView.builder(
                // *** CHANGE: itemCount is now just the data length ***
                itemCount: _receivedNotifications.length,
                itemBuilder: (context, index) {
                  // *** CHANGE: Index directly maps to the data list ***
                  final notification = _receivedNotifications[index];
                  return _buildTableRowWidget(
                    notification["Bildirim"] ?? '', // Use null safety
                    notification["Tarih"] ?? '',    // Use null safety
                    isHeader: false,
                    // *** CHANGE: isLastRow logic based on index in data list ***
                    isLastRow: index == _receivedNotifications.length - 1,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// Creates a single visual row using Widgets (suitable for header or ListView.builder items)
  Widget _buildTableRowWidget(String text1, String text2, {bool isHeader = false, bool isLastRow = false}) {
    return Container(
      decoration: BoxDecoration(
        // Header has a distinct background
        color: isHeader ? Colors.blueGrey.shade800.withOpacity(0.7) : Colors.transparent,
        // Apply bottom border to header and all data rows except the last one
        border: isHeader || !isLastRow // Apply if header OR if it's NOT the last data row
            ? Border(bottom: BorderSide(color: Colors.cyanAccent.withOpacity(0.3), width: 0.5))
            : null, // No bottom border for the very last data row
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
      child: Row(
        children: [
          Expanded( // Notification text takes flexible space
            flex: 3, // Matches column width ratio
            child: Text(
              text1,
              style: TextStyle(
                color: isHeader ? Colors.cyanAccent : Colors.white.withOpacity(0.9),
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                fontSize: isHeader ? 17 : 15,
              ),
            ),
          ),
          SizedBox(width: 10), // Spacer
          Expanded( // Date text takes flexible space
            flex: 2, // Matches column width ratio
            child: Text(
              text2,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isHeader ? Colors.cyanAccent : Colors.white.withOpacity(0.7),
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                fontSize: isHeader ? 17 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

// --- Original Table implementation (kept commented for reference) ---
// Widget _buildNotificationTable_OriginalTable() { ... }
// List<TableRow> _buildTableRows() { ... }
// TableRow _buildTableRow(String text1, String text2, {bool isHeader = false, bool isLastRow = false}) { ... }
}
// -------- End of NotificationPage.dart --------