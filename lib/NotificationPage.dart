import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class NotificationPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, String>> _receivedNotifications = [];
  StreamSubscription? _fcmSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print("[NotificationPage] initState called.");

    _loadAndSetupNotifications();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshNotifications();
      }
    });

    NotificationService.unreadCountNotifier.addListener(() {
      if (mounted) {
        _refreshNotifications();
        print("[NotificationPage] Refreshed due to unread count change.");
      }
    });
  }

  @override
  void dispose() {
    print("[NotificationPage] Dispose called.");
    _fcmSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAndSetupNotifications() async {
    setState(() => _isLoading = true);
    final loaded = await NotificationService.loadNotifications();
    setState(() {
      _receivedNotifications = loaded;
      _isLoading = false;
    });

    await NotificationService.resetUnreadCount();
    NotificationService.forceNotifyUnreadCount();

    _setupFcmListeners();
  }

  Future<void> _refreshNotifications() async {
    if (mounted) setState(() => _isLoading = true);
    final loaded = await NotificationService.loadNotifications();

    if (mounted) {
      setState(() {
        _receivedNotifications = loaded;
        _isLoading = false;
      });

      // ✅ Mark all as read when refreshed
      await NotificationService.resetUnreadCount();
      NotificationService.forceNotifyUnreadCount();
      print("[NotificationPage] Unread count reset after refresh.");
    }
  }

  void _setupFcmListeners() {
    _fcmSubscription?.cancel();
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final String callTimestamp = DateTime.now().toIso8601String();
      print("[$callTimestamp][NotificationPage] Foreground notification received: ${message.messageId}");

      Future.delayed(Duration(milliseconds: 300), () async {
        if (mounted) {
          print("[$callTimestamp][NotificationPage] Triggering delayed refresh after foreground message.");
          NotificationService.forceNotifyUnreadCount();
          await _refreshNotifications();
        }
      });
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
      actions: [
        IconButton(
          icon: Icon(Icons.delete_sweep, color: Colors.redAccent.withOpacity(0.8)),
          tooltip: "Tüm Bildirimleri Temizle",
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.blueGrey.shade800,
                title: Text("Bildirimleri Temizle", style: TextStyle(color: Colors.white)),
                content: Text("Tüm bildirimleri silmek istediğinize emin misiniz?",
                    style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text("İptal", style: TextStyle(color: Colors.cyanAccent))),
                  TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text("Sil", style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            );

            if (confirm == true && mounted) {
              await NotificationService.clearAllNotifications();
              await _refreshNotifications();
            }
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.blueGrey.shade900, Colors.blueGrey.shade800],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : _buildNotificationTable(),
    );
  }

  Widget _buildNotificationTable() {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.15),
            blurRadius: 6,
            spreadRadius: 1,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          children: [
            _buildTableRow("Bildirim", "Tarih", isHeader: true),
            Expanded(
              child: _receivedNotifications.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text("Henüz bildirim yok.",
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                ),
              )
                  : ListView.builder(
                itemCount: _receivedNotifications.length,
                itemBuilder: (context, index) {
                  final n = _receivedNotifications[index];
                  return _buildTableRow(n["Bildirim"] ?? '', n["Tarih"] ?? '', isLastRow: index == _receivedNotifications.length - 1);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(String text1, String text2, {bool isHeader = false, bool isLastRow = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isHeader ? Colors.blueGrey.shade800.withOpacity(0.7) : Colors.transparent,
        border: isHeader || !isLastRow
            ? Border(bottom: BorderSide(color: Colors.cyanAccent.withOpacity(0.3), width: 0.5))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              text1,
              style: TextStyle(
                color: isHeader ? Colors.cyanAccent : Colors.white.withOpacity(0.9),
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                fontSize: isHeader ? 17 : 15,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 2,
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
}
