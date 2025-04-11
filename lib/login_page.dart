import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Still needed to GET the token

// Removed the import for sendFcmTokenToBackend from main.dart
// import 'main.dart';

import 'register_page.dart';
import 'forgot_password_page.dart';
import 'MainPage.dart'; // Assuming MainPage.dart is in lib/

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

  // Get the FirebaseMessaging instance
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    // We'll request permissions right before login attempt now
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // --- Request Notification Permissions ---
  // Stays the same - needed to get the token
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

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted notification permission (Status: ${settings.authorizationStatus})');
      return true;
    } else {
      print('User declined or has not accepted notification permission');
      // Optionally show a dialog, but be mindful not to annoy
      return false;
    }
  }

  // --- Save Credentials and Session Info ---
  // Stays largely the same, but we also save the FCM token locally now
  // *after* successful login, mainly for potential future checks (e.g., token refresh)
  Future<void> saveCredentialsAndSession(
      String emailInput,
      String passwordInput,
      String fullName,
      String authToken,
      String role,
      dynamic roleSpecificData,
      String? fcmToken // Pass the token used for login
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

    // Save the FCM token that was successfully used for login/sent to backend
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await prefs.setString('fcmToken', fcmToken);
      print("FCM token saved locally: $fcmToken");
    } else {
      await prefs.remove('fcmToken'); // Clear if no token was sent/available
      print("No valid FCM token provided during login, cleared local token.");
    }


    // Save role specific data
    if (roleSpecificData != null) {
      try {
        await prefs.setString('roleSpecificData', jsonEncode(roleSpecificData));
        // Extract and save device details (same logic as before)
        List<dynamic> deviceList = roleSpecificData is Map && roleSpecificData.containsKey('devices') && roleSpecificData['devices'] is List
            ? roleSpecificData['devices']
            : [];
        if (deviceList.isNotEmpty && deviceList[0] is Map) {
          var firstDevice = deviceList[0];
          await prefs.setString('deviceName', firstDevice['name']?.toString() ?? '');
          await prefs.setString('deviceId', firstDevice['id']?.toString() ?? '');
          await prefs.setBool('isPaired', firstDevice['isPaired'] ?? false);
          print("Saved device info: ${firstDevice['name']}, ${firstDevice['id']}");
        } else {
          print("No valid device info found in roleSpecificData to save.");
          await prefs.remove('deviceName');
          await prefs.remove('deviceId');
          await prefs.remove('isPaired');
        }
      } catch (e) {
        print("Error encoding or saving roleSpecificData/device info: $e");
        await prefs.remove('roleSpecificData');
        await prefs.remove('deviceName');
        await prefs.remove('deviceId');
        await prefs.remove('isPaired');
      }
    } else {
      await prefs.remove('roleSpecificData');
      await prefs.remove('deviceName');
      await prefs.remove('deviceId');
      await prefs.remove('isPaired');
    }
    print("Credentials, session info, and potentially FCM token saved.");
  }

  // --- Load Saved Credentials (for 'Remember Me') ---
  // Stays the same
  Future<void> _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      rememberMe = prefs.getBool('rememberMe') ?? false;
      if (rememberMe) {
        emailController.text = prefs.getString('email') ?? '';
        passwordController.text = prefs.getString('password') ?? '';
        print("Loaded remembered credentials.");
      } else {
        print("Remember Me is off, not loading credentials.");
      }
    });
  }

  // --- Login Logic (Modified) ---
  Future<void> loginUser() async {
    // Basic input validation (same as before)
    if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
      _showErrorDialog('Lütfen e-posta ve şifre alanlarını doldurun.');
      return;
    }
    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(emailController.text.trim())) {
      _showErrorDialog('Lütfen geçerli bir e-posta adresi girin.');
      return;
    }

    setState(() { isLoading = true; });

    String? fcmToken; // Variable to hold the FCM token

    try {
      // 1. Request Permissions before attempting to get the token
      bool permissionsGranted = await _requestNotificationPermissions();

      // 2. Get FCM Token if permissions were granted
      if (permissionsGranted) {
        try {
          fcmToken = await _firebaseMessaging.getToken();
          if (fcmToken != null && fcmToken.isNotEmpty) {
            print('FCM Token Obtained for login request: $fcmToken');
          } else {
            print('Failed to get FCM token (token was null or empty), will send null.');
            fcmToken = null; // Ensure it's null if empty or failed
          }
        } catch (e) {
          print('Error getting FCM token: $e');
          fcmToken = null; // Ensure it's null on error
        }
      } else {
        print("Notification permissions denied. Proceeding without FCM token.");
        fcmToken = null; // Explicitly set to null if permissions denied
      }

      // --- Prepare Login Request ---
      final String url = 'https://scolisensemvpserver-azhpd3hchqgsc8bm.germanywestcentral-01.azurewebsites.net/api/Auth/login';
      final String emailInput = emailController.text.trim();
      final String passwordInput = passwordController.text;

      final Map<String, dynamic> requestBody = {
        'email': emailInput,
        'password': passwordInput,
        // Include fcmToken (will be null if not obtained/granted)
        'fcmToken': fcmToken,
      };

      print('Sending login request to $url with body: ${jsonEncode(requestBody)}'); // Log the request body

      // 3. Send Login Request with FCM Token included
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 20));

      // --- Handle Login Response ---
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String authToken = data['token'] ?? '';
        String email = data['email'] ?? emailInput;
        String fullName = data['fullName'] ?? 'Kullanıcı';
        String role = data['role'] ?? 'User';
        dynamic roleSpecificData = data['roleSpecificData'];

        if (authToken.isEmpty) {
          print('Login failed: Auth token missing in response.');
          _showErrorDialog('Giriş başarısız: Sunucudan eksik bilgi alındı.');
          // No need to set isLoading false here, finally block handles it
          return; // Exit early
        }

        print('Login successful. Auth Token received.');
        print('Email: $email, Full Name: $fullName, Role: $role');

        // Save credentials, session info, AND the fcmToken that was sent
        await saveCredentialsAndSession(
            emailInput, passwordInput, fullName, authToken, role, roleSpecificData, fcmToken);

        // **REMOVED**: No separate FCM token sending needed here

        // Clear fields
        emailController.clear();
        passwordController.clear();

        // Navigate
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => MainPage()),
                (route) => false,
          );
        }

      } else {
        // Handle errors (same logic as before)
        String errorMessage = 'Bilinmeyen bir hata oluştu.';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? 'Giriş başarısız. Lütfen bilgilerinizi kontrol edin.';
        } catch(e) {
          print("Could not decode error response body: ${response.body}");
          errorMessage = 'Giriş başarısız (Kod: ${response.statusCode}). Lütfen tekrar deneyin.';
        }
        print('Login failed: Status Code: ${response.statusCode}');
        print('Error Detail: ${response.body}');
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      // Handle network/timeout errors (same as before)
      print('Login error: $e');
      _showErrorDialog('Bağlantı hatası veya sunucu yanıt vermiyor. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.');
    } finally {
      // Ensure isLoading is always set to false
      if (mounted) {
        setState(() { isLoading = false; });
      }
    }
  }

  // --- Show Error Dialog ---
  // Stays the same
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // --- Build Method ---
  // Stays the same
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

  // --- UI Building Widgets ---
  // All UI building widgets (_buildBackground, _buildLoginForm, _buildTextField, _buildLoginButton)
  // remain exactly the same as they don't depend on the FCM logic change.
  // ... (Keep the existing UI widget build methods here) ...

  // Background Gradient
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

  // Login Form Area
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
                "Giriş Yap",
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
              hintText: "E-posta",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: passwordController,
              hintText: "Şifre",
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
                      Flexible(child: Text("Beni Hatırla", style: TextStyle(color: Colors.white.withOpacity(0.9)))),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ForgotPasswordPage())
                  ),
                  child: const Text("Şifremi Unuttum?"),
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
              child: const Text("Hesabın yok mu? Kayıt Ol"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Reusable Text Field Widget
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

  // Login Button Widget
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
            color: Theme.of(context).colorScheme.onPrimary, // Use theme color
            strokeWidth: 3,
          ),
        )
            : const Text("Giriş Yap"),
      ),
    );
  }
}