import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ResetPasswordPage.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String fullName = "Yükleniyor...";
  String email = "Yükleniyor...";
  String birthDate = "Yükleniyor...";
  String gender = "Yükleniyor...";
  String phoneNumber = "Yükleniyor...";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      fullName = prefs.getString('fullName') ?? 'Bilinmeyen Kullanıcı';
      email = prefs.getString('loggedInEmail') ?? 'Bilinmeyen E-posta';

      String? roleDataString = prefs.getString('roleSpecificData');
      if (roleDataString != null) {
        try {
          Map<String, dynamic> roleData = jsonDecode(roleDataString);

          birthDate = roleData['birthDate'] != null
              ? _formatDate(roleData['birthDate'])
              : "Yok";
          gender = roleData['isMale'] == true ? "Erkek" : "Kadın";
          phoneNumber = roleData['phoneNumber']?.toString() ?? "Yok";
        } catch (e) {
          print("❌ Hata: Kullanıcı bilgileri ayrıştırılamadı: $e");
        }
      }
    });
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
    } catch (e) {
      return "Geçersiz tarih";
    }
  }

  Future<void> _resetPassword() async {
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
        _showSuccessDialog('Şifre sıfırlama isteği gönderildi. Lütfen e-postanızı kontrol edin.');
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Tamam')),
        ],
      ),
    );
  }

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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResetPasswordPage(email: email, previousPage: "ProfilePage"),
                ),
              );
            },
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.cyanAccent),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        "Profil",
        style: TextStyle(
          color: Colors.cyanAccent,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black,
            Colors.blueGrey.shade900,
            Colors.blueGrey.shade800,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView( // 🔥 Add this
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileImage(),
            SizedBox(height: 20),
            Text(
              fullName,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
            ),
            SizedBox(height: 30),
            _buildInfoCard(Icons.email, "E-posta", email),
            _buildInfoCard(Icons.phone, "Telefon", phoneNumber),
            _buildInfoCard(Icons.cake, "Doğum Tarihi", birthDate),
            _buildInfoCard(Icons.wc, "Cinsiyet", gender),
            SizedBox(height: 30),
            _buildResetPasswordButton(),
            SizedBox(height: 20), // Extra padding for bottom space
          ],
        ),
      ),
    );
  }


  Widget _buildProfileImage() {
    String assetPath = gender == "Erkek" ? "assets/boypp.png" : "assets/girlpp.png";
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.cyanAccent,
      child: CircleAvatar(
        radius: 56,
        backgroundImage: AssetImage(assetPath),
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Card(
      color: Colors.blueGrey.shade700,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.cyanAccent),
        title: Text(label, style: TextStyle(color: Colors.white70, fontSize: 14)),
        subtitle: Text(value, style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
    );
  }

  Widget _buildResetPasswordButton() {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : _resetPassword,
      icon: Icon(Icons.lock_reset, color: Colors.black),
      label: Text(
        isLoading ? "Gönderiliyor..." : "Şifreyi Sıfırla",
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyanAccent,
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
