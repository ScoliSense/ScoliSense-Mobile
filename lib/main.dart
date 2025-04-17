import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'MainPage.dart';
import 'NotificationPage.dart';
import 'notification_service.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  await NotificationService.saveNotification(message);
  NotificationService.forceNotifyUnreadCount();
  _showLocalNotification(message);
}

void _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  final android = notification?.android;
  if (notification != null && android != null) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Skolyoz notification channel',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableLights: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      autoCancel: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: 'notification_click',
    );
  }
}

void setupFcmTokenListener() {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('authToken');
    String? oldToken = prefs.getString('fcmToken');
    if (authToken != null && authToken.isNotEmpty && newToken != oldToken) {
      await prefs.setString('fcmToken', newToken);
    }
  }).onError((err) {
    print("[Main] Error listening to FCM token refresh: $err");
  });
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('[notificationTapBackground] Triggered with payload: ${notificationResponse.payload}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload == 'notification_click') {
        await Future.delayed(Duration(milliseconds: 100));
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainPage(forceBadgeRefresh: true)),
              (route) => false,
        );
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.initialize();
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: false,
    badge: true,
    sound: false,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await NotificationService.saveNotification(message);
    NotificationService.forceNotifyUnreadCount();
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await NotificationService.saveNotification(message);
    NotificationService.forceNotifyUnreadCount();
    await Future.delayed(Duration(milliseconds: 100));
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainPage(forceBadgeRefresh: true)),
          (route) => false,
    );
  });

  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await NotificationService.saveNotification(initialMessage);
    NotificationService.forceNotifyUnreadCount();
    await Future.delayed(Duration(milliseconds: 200));
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainPage(forceBadgeRefresh: true)),
          (route) => false,
    );
  }

  setupFcmTokenListener();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? authToken = prefs.getString('authToken');
  bool isLoggedIn = authToken != null && authToken.isNotEmpty;
  Widget initialHome = isLoggedIn ? MainPage(forceBadgeRefresh: false) : LoginPage();

  runApp(MyApp(initialHome: initialHome));
}

class MyApp extends StatelessWidget {
  final Widget initialHome;
  const MyApp({super.key, required this.initialHome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Skolyoz Mobil',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.blueGrey.shade900,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.cyanAccent),
          hintStyle: TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.cyanAccent, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.cyanAccent, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          filled: true,
          fillColor: Colors.blueGrey.shade800,
          prefixIconColor: Colors.cyanAccent,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.cyanAccent,
            textStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.cyanAccent;
            }
            return Colors.blueGrey.shade400;
          }),
          checkColor: WidgetStateProperty.all(Colors.black),
          side: BorderSide(color: Colors.cyanAccent),
        ),
      ),
      navigatorObservers: [routeObserver],
      home: initialHome,
    );
  }
}
