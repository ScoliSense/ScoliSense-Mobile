import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EnterCodePage extends StatefulWidget {
  @override
  _EnterCodePageState createState() => _EnterCodePageState();
}

class _EnterCodePageState extends State<EnterCodePage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('authToken');
    final String licenseKey = _codeController.text.trim();

    if (token == null || token.isEmpty) {
      print("DEBUG: Token bulunamadı!");
      setState(() {
        _errorMessage =
        "Oturum doğrulaması bulunamadı. Lütfen yeniden giriş yapın.";
        _isLoading = false;
      });
      return;
    }

    final String apiUrl =
        "https://mybackendhaha.store/api/Device/pair-device";

    final payload = {"licenseKey": licenseKey};

    print("DEBUG: Sending pairing request to: $apiUrl");
    print("DEBUG: Token: $token");
    print("DEBUG: Payload: ${jsonEncode(payload)}");

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      print("DEBUG: Status Code: ${response.statusCode}");
      print("DEBUG: Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String deviceName = responseData['deviceName'];
        final String deviceId = responseData['deviceId'];

        // Store device info in SharedPreferences
        await prefs.setString('deviceName', deviceName);
        await prefs.setString('deviceId', deviceId);

        print("DEBUG: Device name saved: $deviceName");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cihaz başarıyla eşleştirildi!")),
        );

        // Navigate to Scan Devices page or another appropriate screen
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage =
          "Cihaz eşleştirilemedi: ${jsonDecode(response.body)['message'] ?? 'Bilinmeyen hata'}";
        });
      }
    } catch (error) {
      print("DEBUG: Exception during pairing: $error");
      setState(() {
        _errorMessage = "Bir hata oluştu. Lütfen tekrar deneyin.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          _buildBackButton(context),
          _buildFormContent(context),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
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
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.cyanAccent),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                "Cihaz Eşleştir",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 30),
              TextField(
                controller: _codeController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.vpn_key, color: Colors.cyanAccent),
                  hintText: "Lisans Anahtarını Girin",
                  hintStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.blueGrey.shade800,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator(color: Colors.cyanAccent)
                  : ElevatedButton(
                onPressed: _submitCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: Size(double.infinity, 50),
                  shadowColor: Colors.cyanAccent.withOpacity(0.5),
                  elevation: 10,
                ),
                child: Text(
                  "Gönder",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
