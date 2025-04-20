import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'forgot_password_page.dart';
import 'ProfilePage.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String previousPage; // Önceki sayfayı takip etmek için

  ResetPasswordPage({required this.email, required this.previousPage});

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  bool isLoading = false;

  /// **Şifreyi sıfırlama isteği gönderir**
  Future<void> resetPassword() async {
    if (codeController.text.isEmpty || newPasswordController.text.isEmpty) {
      _showErrorDialog('Lütfen tüm alanları doldurun.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final String url =
        'https://mybackendhaha.store/api/Auth/reset-password';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': widget.email,
          'code': codeController.text.trim(),
          'newPassword': newPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessDialog('Şifre sıfırlama başarılı.');
      } else {
        _showErrorDialog('Şifre sıfırlama başarısız.');
      }
    } catch (e) {
      _showErrorDialog('Bağlantı hatası.');
    }

    setState(() {
      isLoading = false;
    });
  }

  /// **Başarı mesajını gösterir**
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Başarılı'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
            child: Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

  /// **Hata mesajını gösterir**
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

  /// **Geri butonuna basınca önceki sayfaya yönlendirir**
  void _goBack() {
    if (widget.previousPage == "ProfilePage") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ForgotPasswordPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.cyanAccent),
          onPressed: _goBack, // Geri butonu önceki sayfaya yönlendirecek
        ),
        title: Text(
          "Şifreyi Sıfırla",
          style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          _buildBackground(),
          _buildPasswordResetForm(),
        ],
      ),
    );
  }

  /// **Arkaplan Tasarımı**
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

  /// **Form Tasarımı**
  Widget _buildPasswordResetForm() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_reset, size: 100, color: Colors.cyanAccent),
            SizedBox(height: 20),
            Text(
              "Şifreyi Sıfırla",
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30),
            _buildTextField(
              controller: codeController,
              hintText: "Kod",
              icon: Icons.vpn_key,
            ),
            SizedBox(height: 15),
            _buildTextField(
              controller: newPasswordController,
              hintText: "Yeni Şifre",
              obscureText: true,
              icon: Icons.lock,
            ),
            SizedBox(height: 30),
            _buildResetButton(),
          ],
        ),
      ),
    );
  }

  /// **Özel TextField Bileşeni**
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(50), // KÖŞELERİ TAM YUVARLAK YAPIYORUZ
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: Colors.white),
        cursorColor: Colors.cyanAccent,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.cyanAccent),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.blueGrey.shade800,
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20), // İçeriği daha ortalar
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50), // Köşeler tamamen yuvarlak
            borderSide: BorderSide(color: Colors.cyanAccent, width: 2), // Çerçeve rengi
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.5), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
          ),
        ),
      ),
    );
  }

  /// **Şifreyi sıfırla butonu**
  Widget _buildResetButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : resetPassword,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        minimumSize: Size(double.infinity, 50),
        shadowColor: Colors.cyanAccent.withOpacity(0.5),
        elevation: 10,
      ),
      child: isLoading
          ? CircularProgressIndicator(color: Colors.black)
          : Text(
        "Şifreyi Sıfırla",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
