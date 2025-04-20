import 'package:flutter/services.dart';

class BackgroundService {
  static const String _tag = "BackgroundService";
  static const platform = MethodChannel('com.example.skolyozmobil/background_service');

  static Future<void> startService() async {
    print("[$_tag] Attempting to start background service");
    try {
      await platform.invokeMethod('startService');
      print("[$_tag] Background service start request successful");
    } on PlatformException catch (e) {
      print("[$_tag] Failed to start service - PlatformException: ${e.message}");
      print("[$_tag] Error details: ${e.details}");
      print("[$_tag] Error code: ${e.code}");
      rethrow; // Rethrow to let the caller handle the error
    } catch (e) {
      print("[$_tag] Failed to start service - Unexpected error: $e");
      rethrow; // Rethrow to let the caller handle the error
    }
  }

  static Future<void> stopService() async {
    print("[$_tag] Attempting to stop background service");
    try {
      await platform.invokeMethod('stopService');
      print("[$_tag] Background service stop request successful");
    } on PlatformException catch (e) {
      print("[$_tag] Failed to stop service - PlatformException: ${e.message}");
      print("[$_tag] Error details: ${e.details}");
      print("[$_tag] Error code: ${e.code}");
      rethrow; // Rethrow to let the caller handle the error
    } catch (e) {
      print("[$_tag] Failed to stop service - Unexpected error: $e");
      rethrow; // Rethrow to let the caller handle the error
    }
  }
}
