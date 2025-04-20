import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ResetPasswordPage.dart';
import 'login_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  /// **Geçerli bir e-posta adresi olup olmadığını kontrol eder.**
  bool _isValidEmail(String email) {
    final RegExp emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  /// **Şifre sıfırlama isteğini gönderir.**
  Future<void> requestPasswordReset() async {
    final String email = emailController.text.trim();

    if (email.isEmpty) {
      _showErrorDialog('Lütfen e-posta adresinizi girin.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showErrorDialog('Lütfen geçerli bir e-posta adresi girin.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final String url = 'https://mybackendhaha.store/api/Auth/forgot-password';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        _showSuccessDialog(
            'Şifre sıfırlama isteği gönderildi. Lütfen e-postanızı kontrol edin.', email);
      } else {
        _showErrorDialog('Şifre sıfırlama başarısız.');
      }
    } catch (e) {
      _showErrorDialog('Bağlantı hatası. Lütfen tekrar deneyin.');
    }

    setState(() {
      isLoading = false;
    });
  }

  /// **Hata mesajlarını gösterir.**
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

  /// **Başarı mesajını gösterir ve ResetPasswordPage’e yönlendirir.**
  void _showSuccessDialog(String message, String email) {
    showDialog(
      context: context,
      barrierDismissible: false, // Kullanıcının dışarıya tıklayıp kapatmasını önler
      builder: (context) => AlertDialog(
        title: Text('Başarılı'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Mevcut dialog'u kapat
              _navigateToResetPasswordPage(email);
            },
            child: Text('Devam Et'),
          ),
        ],
      ),
    ).then((_) {
      _navigateToResetPasswordPage(email); // Dialog kapansa bile yönlendirir
    });
  }

  /// **ResetPasswordPage'e yönlendirir ve hangi sayfadan geldiğini belirtir.**
  void _navigateToResetPasswordPage(String email) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResetPasswordPage(email: email, previousPage: "ForgotPasswordPage"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          _buildForgotPasswordForm(),
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
  Widget _buildForgotPasswordForm() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 100, color: Colors.cyanAccent),
            SizedBox(height: 20),
            Text(
              "Şifremi Unuttum",
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30),
            _buildTextField(
              controller: emailController,
              hintText: "E-posta",
              icon: Icons.email,
            ),
            SizedBox(height: 30),
            _buildRequestButton(),
            SizedBox(height: 15),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              child: Text(
                "Geri Dön",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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

  /// **Şifre Sıfırlama Butonu**
  Widget _buildRequestButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : () {
        requestPasswordReset();
      },
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
        "Şifre Sıfırlama İsteği Gönder",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
