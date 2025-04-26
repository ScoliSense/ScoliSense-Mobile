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
  String fullName = "Loading...";
  String email = "Loading...";
  String birthDate = "Loading...";
  String gender = "Loading...";
  String phoneNumber = "Loading...";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      fullName = prefs.getString('fullName') ?? 'Unknown User';
      email = prefs.getString('loggedInEmail') ?? 'Unknown Email';

      String? roleDataString = prefs.getString('roleSpecificData');
      if (roleDataString != null) {
        try {
          Map<String, dynamic> roleData = jsonDecode(roleDataString);

          birthDate = roleData['birthDate'] != null
              ? _formatDate(roleData['birthDate'])
              : "Not available";
          gender = roleData['isMale'] == true ? "Male" : "Female";
          phoneNumber = roleData['phoneNumber']?.toString() ?? "Not available";
        } catch (e) {
          print("❌ Error: Failed to parse user details: $e");
        }
      }
    });
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
    } catch (e) {
      return "Invalid date";
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
        _showSuccessDialog('Password reset request sent. Please check your email.');
      } else {
        _showErrorDialog('Password reset failed.');
      }
    } catch (e) {
      _showErrorDialog('Connection error. Please try again.');
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('OK')),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Success'),
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
            child: Text('OK'),
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
        "Profile",
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
      child: SingleChildScrollView(
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
            _buildInfoCard(Icons.email, "Email", email),
            _buildInfoCard(Icons.phone, "Phone", phoneNumber),
            _buildInfoCard(Icons.cake, "Birth Date", birthDate),
            _buildInfoCard(Icons.wc, "Gender", gender),
            SizedBox(height: 30),
            _buildResetPasswordButton(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    String assetPath = gender == "Male" ? "assets/boypp.png" : "assets/girlpp.png";
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
        isLoading ? "Sending..." : "Reset Password",
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
