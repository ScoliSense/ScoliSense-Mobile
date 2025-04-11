import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bluetooth_service.dart' as my_ble;

class ScanDevicesPage extends StatefulWidget {
  final Function(String) onDeviceConnected;

  ScanDevicesPage({
    required this.onDeviceConnected,
  });

  @override
  _ScanDevicesPageState createState() => _ScanDevicesPageState();
}

class _ScanDevicesPageState extends State<ScanDevicesPage> {
  List<ScanResult> _devices = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;
  String _connectedDeviceName = "Not Connected";

  @override
  void initState() {
    super.initState();
    _loadConnectedDevice();
  }


  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    var status = await Permission.bluetoothScan.request();
    if (status.isGranted) {
      if (!mounted) return;
      setState(() {
        _isScanning = true;
        _devices.clear();
      });

      FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
      FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          final connectedDevice = my_ble.MyBluetoothService().connectedDevice;
          _devices = results
              .where((r) =>
          r.device.name.isNotEmpty &&
              (connectedDevice == null || r.device.id != connectedDevice.id))
              .toList();

        });
      });

      await Future.delayed(Duration(seconds: 10));
      if (!mounted) return;
      setState(() => _isScanning = false);
      FlutterBluePlus.stopScan();
    } else {
      print("Bluetooth scan permission denied.");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    FlutterBluePlus.stopScan();

    try {
      await device.connect();
      BluetoothConnectionState state = await device.connectionState.first;
      if (state != BluetoothConnectionState.connected) return;

      await my_ble.MyBluetoothService().init(device);

      if (!mounted) return;
      setState(() {
        _connectedDevice = device;
        _connectedDeviceName = device.name;
        _devices.removeWhere((d) => d.device.id == device.id);
      });

      widget.onDeviceConnected(device.name);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('deviceName', device.name);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connected to ${device.name} successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Connection error: $e");
    }
  }

  void _disconnectDevice() async {
    if (_connectedDevice == null) return;
    try {
      await _connectedDevice!.disconnect();
      if (!mounted) return;
      setState(() {
        _connectedDevice = null;
        _connectedDeviceName = "Not Connected";
      });
      widget.onDeviceConnected("Not Connected");

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('deviceName');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Disconnected successfully!"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print("Disconnection error: $e");
    }
  }

  Future<void> _loadConnectedDevice() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedDeviceName = prefs.getString('deviceName');

    if (storedDeviceName != null && storedDeviceName.isNotEmpty) {
      // Try to restore connected device from the singleton service
      final device = my_ble.MyBluetoothService().connectedDevice;

      if (device != null) {
        setState(() {
          _connectedDevice = device;
          _connectedDeviceName = device.name;
        });
      } else {
        // Fallback to just showing the name if device object is not accessible
        setState(() {
          _connectedDeviceName = storedDeviceName;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scan Devices", style: TextStyle(color: Colors.cyanAccent)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.cyanAccent),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.blueGrey.shade900, Colors.blueGrey.shade800],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 20),
            if (_connectedDevice != null) _buildConnectedDeviceTile(),
            _isScanning
                ? CircularProgressIndicator(color: Colors.cyanAccent)
                : ElevatedButton(
              onPressed: _startScan,
              child: Text("Scan Devices", style: TextStyle(color: Colors.cyanAccent)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            ),
            Expanded(
              child: _devices.isEmpty
                  ? Center(child: Text("No devices found", style: TextStyle(color: Colors.white)))
                  : ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  BluetoothDevice device = _devices[index].device;
                  return ListTile(
                    title: Text(device.name, style: TextStyle(color: Colors.cyanAccent)),
                    subtitle: Text(device.id.toString(), style: TextStyle(color: Colors.white70)),
                    onTap: () => _connectToDevice(device),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedDeviceTile() {
    return Card(
      color: Colors.blueGrey.shade900,
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: Icon(Icons.bluetooth_connected, color: Colors.greenAccent),
        title: Text(
          _connectedDeviceName,
          style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
        ),
        subtitle: Text("Connected", style: TextStyle(color: Colors.white70)),
        trailing: TextButton(
          onPressed: _disconnectDevice,
          child: Text(
            "Disconnect",
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}