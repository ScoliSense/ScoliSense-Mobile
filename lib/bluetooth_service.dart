import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class MyBluetoothService {
  static final MyBluetoothService _instance = MyBluetoothService._internal();
  factory MyBluetoothService() => _instance;
  MyBluetoothService._internal();

  BluetoothDevice? connectedDevice;
  String buffer = "";
  final RegExp validSensorNameRegex = RegExp(r'^FSR\d+$');
  final Map<Guid, StreamSubscription<List<int>>> _subscriptions = {};
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  final StreamController<String> _dataStreamController = StreamController.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  final StreamController<Map<String, String>> _statusStreamController = StreamController.broadcast();
  Stream<Map<String, String>> get statusStream => _statusStreamController.stream;

  Future<void> init(BluetoothDevice device) async {
    connectedDevice = device;
    _listenForDisconnection(device);
    _subscribeToConnectivity();

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          _subscriptions[characteristic.uuid]?.cancel();
          final sub = characteristic.value.listen(_handleIncomingData);
          _subscriptions[characteristic.uuid] = sub;
        }
      }
    }
  }

  void _listenForDisconnection(BluetoothDevice device) {
    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _clearSubscriptions();
        connectedDevice = null;
        print("🔌 Disconnected from BLE device.");
      }
    });
  }

  void _subscribeToConnectivity() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
          if (result == ConnectivityResult.wifi) {
            print("📶 Wi-Fi reconnected. Attempting to send stored data...");
            _trySendingUnsentData();
          }
        });
  }

  void _clearSubscriptions() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _handleIncomingData(List<int> value) {
    String newData = String.fromCharCodes(value);
    buffer += newData;

    if (buffer.contains("\n")) {
      List<String> messages = buffer.split("\n");

      for (int i = 0; i < messages.length - 1; i++) {
        String rawMessage = messages[i].trim();
        print("📥 Received: $rawMessage");

        _dataStreamController.add(rawMessage);

        if (rawMessage.contains(":")) {
          List<String> parts = rawMessage.split(":");
          if (parts.length == 2) {
            String sensorName = parts[0].trim();
            String rawValue = parts[1].trim();
            int? sensorValue = int.tryParse(rawValue);

            if (!validSensorNameRegex.hasMatch(sensorName)) continue;
            if (sensorValue == null) continue;

            _sendSensorData(sensorName, sensorValue);
          }
        }
      }

      buffer = messages.last;
    }
  }

  Future<void> _sendSensorData(String sensorName, int value) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null || token.isEmpty) return;

    final timeStamp = DateTime.now()
        .toUtc()
        .subtract(Duration(seconds: 2))
        .toIso8601String()
        .split('.')
        .first + 'Z';

    final isWifi = await _isWifiConnected();

    final dataPoint = {
      "timeStamp": timeStamp,
      "value": value.toDouble(),
    };

    if (isWifi) {
      final url = Uri.parse(
        'https://scolisensemvpserver-azhpd3hchqgsc8bm.germanywestcentral-01.azurewebsites.net/api/SensorData/by-name',
      );

      final data = {
        "sensorName": sensorName,
        "value": value.toDouble(),
        "timeStamp": timeStamp,
      };

      try {
        final response = await http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode(data),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          print("✅ Sent: $sensorName:$value @ $timeStamp");
          _statusStreamController.add({"msg": "$sensorName:$value", "status": "success"});
        } else {
          print("📦 Stored (HTTP fail): $sensorName:$value @ $timeStamp");
          await _storeUnsentData(sensorName, dataPoint);
          _statusStreamController.add({"msg": "$sensorName:$value", "status": "stored"});
        }

        await _sendUnsentSensorData(token);
      } catch (e) {
        print("❌ Error sending, storing locally: $sensorName:$value @ $timeStamp");
        await _storeUnsentData(sensorName, dataPoint);
        _statusStreamController.add({"msg": "$sensorName:$value", "status": "error"});
      }
    } else {
      print("📦 No Wi-Fi, storing: $sensorName:$value @ $timeStamp");
      await _storeUnsentData(sensorName, dataPoint);
      _statusStreamController.add({"msg": "$sensorName:$value", "status": "stored"});
    }
  }

  Future<void> _storeUnsentData(String sensorName, Map<String, dynamic> dataPoint) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = "unsent_$sensorName";
    List<String> existing = prefs.getStringList(key) ?? [];
    existing.add(jsonEncode(dataPoint));
    await prefs.setStringList(key, existing);
  }

  Future<void> _trySendingUnsentData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token != null && token.isNotEmpty) {
      await _sendUnsentSensorData(token);
    }
  }

  Future<void> _sendUnsentSensorData(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('unsent_'));

    for (String key in keys) {
      String sensorName = key.replaceFirst('unsent_', '');
      List<String> rawDataList = prefs.getStringList(key) ?? [];
      if (rawDataList.isEmpty) continue;

      List<Map<String, dynamic>> dataPoints = rawDataList
          .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
          .toList();

      bool success = await _sendBatchData(sensorName, dataPoints, token);
      if (success) {
        await prefs.remove(key);
      }
    }
  }

  Future<bool> _sendBatchData(String sensorName, List<Map<String, dynamic>> dataPoints, String token) async {
    final url = Uri.parse(
      'https://scolisensemvpserver-azhpd3hchqgsc8bm.germanywestcentral-01.azurewebsites.net/api/SensorData/batch/by-name',
    );

    final payload = {
      "sensorName": sensorName,
      "dataPoints": dataPoints,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("📤 Batch sent for $sensorName (${dataPoints.length} entries)");
        return true;
      } else {
        print("⚠️ Batch send failed for $sensorName (status: ${response.statusCode})");
        return false;
      }
    } catch (e) {
      print("❌ Error sending batch for $sensorName: $e");
      return false;
    }
  }

  Future<bool> _isWifiConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.wifi;
  }
}
