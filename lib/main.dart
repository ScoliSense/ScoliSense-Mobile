import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Servisi başlatmadan önce yapılandırma
    FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'skolyoz_service_channel',
      channelName: 'Skolyoz Servis Kanalı',
      channelDescription: 'Sensör verilerini arka planda işler',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      iconData: NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher', // mipmap/ic_launcher
      ),
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000, // 5 saniyede bir çalışacak
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  runApp(MyApp());
}

/// Arka planda çalışacak olan fonksiyon burada tanımlanıyor
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Skolyoz Mobil',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LoginPage(), // Başlangıç ekranı
    );
  }
}

/// Arka planda sürekli çalışan görevleri tanımlayan sınıf
class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    debugPrint('[ForegroundService] Başladı: $timestamp');
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    debugPrint('[ForegroundService] onEvent: $timestamp');
    // Buraya sensör verisi alma veya veri gönderme kodu gelecek
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    debugPrint('[ForegroundService] onRepeatEvent: $timestamp');
    // Sürekli tekrar edecek işler burada yapılabilir
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    debugPrint('[ForegroundService] Durduruldu: $timestamp');
  }

  @override
  void onButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
