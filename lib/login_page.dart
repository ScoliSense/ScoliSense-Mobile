import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'register_page.dart';
import 'forgot_password_page.dart';
import 'MainPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool rememberMe = false;
  bool _isPasswordVisible = false;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<bool> _requestNotificationPermissions() async {
    print("Requesting notification permissions...");
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> saveCredentialsAndSession(
      String emailInput,
      String passwordInput,
      String fullName,
      String authToken,
      String role,
      dynamic roleSpecificData,
      String? fcmToken
      ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', rememberMe);

    if (rememberMe) {
      await prefs.setString('email', emailInput);
      await prefs.setString('password', passwordInput);
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
    }

    await prefs.setString('loggedInEmail', emailInput);
    await prefs.setString('fullName', fullName);
    await prefs.setString('authToken', authToken);
    await prefs.setString('role', role);

    if (fcmToken != null && fcmToken.isNotEmpty) {
      await prefs.setString('fcmToken', fcmToken);
    } else {
      await prefs.remove('fcmToken');
    }

    if (roleSpecificData != null) {
      try {
        await prefs.setString('roleSpecificData', jsonEncode(roleSpecificData));
        List<dynamic> deviceList = roleSpecificData is Map && roleSpecificData.containsKey('devices') ? roleSpecificData['devices'] : [];
        if (deviceList.isNotEmpty && deviceList[0] is Map) {
          var firstDevice = deviceList[0];
          await prefs.setString('deviceName', firstDevice['name']?.toString() ?? '');
          await prefs.setString('deviceId', firstDevice['id']?.toString() ?? '');
          await prefs.setBool('isPaired', firstDevice['isPaired'] ?? false);
        }
      } catch (e) {
        await prefs.remove('roleSpecificData');
      }
    } else {
      await prefs.remove('roleSpecificData');
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
    if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
      _showErrorDialog('Please fill in both email and password.');
      return;
    }
    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(emailController.text.trim())) {
      _showErrorDialog('Please enter a valid email address.');
      return;
    }

    setState(() { isLoading = true; });

    String? fcmToken;

    try {
      bool permissionsGranted = await _requestNotificationPermissions();

      if (permissionsGranted) {
        try {
          fcmToken = await _firebaseMessaging.getToken();
        } catch (e) {
          fcmToken = null;
        }
      }

      final String url = 'https://mybackendhaha.store/api/Auth/login';
      final String emailInput = emailController.text.trim();
      final String passwordInput = passwordController.text;

      final Map<String, dynamic> requestBody = {
        'email': emailInput,
        'password': passwordInput,
        'fcmToken': fcmToken,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String authToken = data['token'] ?? '';
        String email = data['email'] ?? emailInput;
        String fullName = data['fullName'] ?? 'User';
        String role = data['role'] ?? 'User';
        dynamic roleSpecificData = data['roleSpecificData'];

        if (authToken.isEmpty) {
          _showErrorDialog('Login failed: Missing information from server.');
          return;
        }

        await saveCredentialsAndSession(emailInput, passwordInput, fullName, authToken, role, roleSpecificData, fcmToken);

        emailController.clear();
        passwordController.clear();

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => MainPage()),
                (route) => false,
          );
        }

      } else {
        String errorMessage = 'An unknown error occurred.';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? 'Login failed. Please check your details.';
        } catch(e) {
          errorMessage = 'Login failed (Code: ${response.statusCode}). Please try again.';
        }
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      _showErrorDialog('Connection error or server not responding. Please check your internet connection and try again.');
    } finally {
      if (mounted) {
        setState(() { isLoading = false; });
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            _buildBackground(),
            _buildLoginForm(context),
          ],
        ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/scoli_logo.png',
              height: 150,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.error, size: 100, color: Colors.redAccent),
            ),
            const SizedBox(height: 20),
            const Text(
                "Login",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                )
            ),
            const SizedBox(height: 30),
            _buildTextField(
              controller: emailController,
              hintText: "Email",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: passwordController,
              hintText: "Password",
              icon: Icons.lock_outline,
              obscureText: !_isPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.cyanAccent.withOpacity(0.7),
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: rememberMe,
                        onChanged: isLoading ? null : (value) {
                          if (value != null) {
                            setState(() {
                              rememberMe = value;
                            });
                          }
                        },
                      ),
                      Flexible(child: Text("Remember Me", style: TextStyle(color: Colors.white.withOpacity(0.9)))),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ForgotPasswordPage())
                  ),
                  child: const Text("Forgot Password?"),
                ),
              ],
            ),
            const SizedBox(height: 25),
            _buildLoginButton(),
            const SizedBox(height: 20),
            TextButton(
              onPressed: isLoading ? null : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterPage())
              ),
              child: const Text("Don't have an account? Sign Up"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hintText,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : loginUser,
        child: isLoading
            ? SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.onPrimary,
            strokeWidth: 3,
          ),
        )
            : const Text("Login"),
      ),
    );
  }
}
