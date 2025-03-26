import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:isolate';


import 'register_page.dart';
import 'forgot_password_page.dart';
import 'MainPage.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> saveCredentials(String email, String password, String fullName, String token, String role, dynamic roleSpecificData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', rememberMe);

    if (rememberMe) {
      await prefs.setString('email', email);
      await prefs.setString('password', password);
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
    }

    await prefs.setString('loggedInEmail', email);
    await prefs.setString('fullName', fullName);
    await prefs.setString('authToken', token);
    await prefs.setString('role', role);

    if (roleSpecificData != null) {
      await prefs.setString('roleSpecificData', jsonEncode(roleSpecificData));

      List<dynamic> deviceList = roleSpecificData['devices'] ?? [];
      if (deviceList.isEmpty) {
        await prefs.remove('deviceName');
        await prefs.remove('deviceId');
      }
    } else {
      await prefs.remove('roleSpecificData');
      await prefs.remove('deviceName');
      await prefs.remove('deviceId');
    }
  }

  Future<void> _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      rememberMe = prefs.getBool('rememberMe') ?? false;
      if (rememberMe) {
        emailController.text = prefs.getString('email') ?? '';
        passwordController.text = prefs.getString('password') ?? '';
      }
    });
  }

  Future<void> loginUser() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showErrorDialog('Lütfen tüm alanları doldurun.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final String url = 'https://scolisensemvpserver-azhpd3hchqgsc8bm.germanywestcentral-01.azurewebsites.net/api/Auth/login';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': emailController.text.trim(),
          'password': passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String token = data['token'] ?? '';
        String email = data['email'] ?? '';
        String fullName = data['fullName'] ?? 'Kullanıcı';
        String role = data['role'] ?? 'User';
        dynamic roleSpecificData = data['roleSpecificData'];

        print('Giriş başarılı. Token: $token');
        print('Email: $email, Full Name: $fullName, Role: $role');
        print('Role Specific Data: ${roleSpecificData ?? "None"}');

        await saveCredentials(emailController.text, passwordController.text, fullName, token, role, roleSpecificData);

        // ✅ Foreground Service başlat
        await FlutterForegroundTask.startService(
          notificationTitle: 'Skolyoz Mobil Aktif',
          notificationText: 'Veriler arka planda toplanıyor...',
          callback: startCallback,
        );

        emailController.clear();
        passwordController.clear();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainPage()),
              (route) => false,
        );
      } else {
        print('Giriş başarısız: Status Code: ${response.statusCode}');
        print('Hata Detayı: ${response.body}');
        _showErrorDialog('Giriş başarısız: ${jsonDecode(response.body)['message'] ?? 'Bilinmeyen hata'}');
      }
    } catch (e) {
      print('Hata oluştu: $e');
      _showErrorDialog('Bağlantı hatası. Lütfen tekrar deneyin.');
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          _buildLoginForm(context),
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

  Widget _buildLoginForm(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/scoli_logo.png',
              height: 150,
            ),
            SizedBox(height: 20),
            Text("Giriş Yap", style: TextStyle(color: Colors.cyanAccent, fontSize: 26, fontWeight: FontWeight.bold)),
            SizedBox(height: 30),
            _buildTextField(controller: emailController, hintText: "E-posta", icon: Icons.email),
            SizedBox(height: 15),
            _buildTextField(controller: passwordController, hintText: "Şifre", obscureText: true, icon: Icons.lock),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      onChanged: (value) {
                        setState(() {
                          rememberMe = value!;
                        });
                      },
                      activeColor: Colors.cyanAccent,
                    ),
                    Text("Beni Hatırla", style: TextStyle(color: Colors.white)),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ForgotPasswordPage())),
                  child: Text("Şifremi Unuttum", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildLoginButton(context),
            SizedBox(height: 15),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterPage())),
              child: Text("Hesabın yok mu? Kayıt Ol", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText, bool obscureText = false, required IconData icon}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.cyanAccent),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.blueGrey.shade800,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.cyanAccent, width: 2)),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : loginUser,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      child: isLoading ? CircularProgressIndicator(color: Colors.black) : Text("Giriş Yap", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }
}

/// Foreground service için callback fonksiyonu
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

/// Arka planda çalışacak görevleri yöneten sınıf
class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    debugPrint('[ForegroundService] Başladı: $timestamp');
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    debugPrint('[ForegroundService] onEvent: $timestamp');
    // Sensör verisi gönderme işlemleri buraya yazılabilir
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    debugPrint('[ForegroundService] onRepeatEvent: $timestamp');
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
