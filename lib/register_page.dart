import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();

  DateTime? selectedBirthDate;
  bool isMale = true;
  bool isLoading = false;

  bool _isValidEmail(String email) {
    final RegExp emailRegex =
    RegExp(r'^[a-zA-Z0-9]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
    return emailRegex.hasMatch(email);
  }

  Future<void> registerUser() async {
    if (fullNameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        birthDateController.text.isEmpty) {
      _showErrorDialog('Please fill all required fields.');
      return;
    }

    if (!_isValidEmail(emailController.text.trim())) {
      _showErrorDialog('Please enter a valid email address.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final String url =
        'https://mybackendhaha.store/api/Auth/register/patient';

    final Map<String, dynamic> orderedBody = {
      'birthDate': selectedBirthDate?.toUtc().toIso8601String(),
      'isMale': isMale,
      'phoneNumber': phoneNumberController.text.trim().isEmpty
          ? null
          : phoneNumberController.text.trim(),
      'email': emailController.text.trim(),
      'password': passwordController.text,
      'fullName': fullNameController.text.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(orderedBody),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSuccessDialog('Registration successful. You can now log in.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      } else {
        _showErrorDialog('Registration failed: ${response.body}');
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
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
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    birthDateController.dispose();
    phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Register",
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 30),
                  _buildTextField(
                    controller: fullNameController,
                    hintText: "Full Name",
                    icon: Icons.person,
                  ),
                  SizedBox(height: 15),
                  _buildTextField(
                    controller: emailController,
                    hintText: "Email",
                    icon: Icons.email,
                  ),
                  SizedBox(height: 15),
                  _buildTextField(
                    controller: passwordController,
                    hintText: "Password",
                    obscureText: true,
                    icon: Icons.lock,
                  ),
                  SizedBox(height: 15),
                  GestureDetector(
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: Colors.cyanAccent,
                                onPrimary: Colors.black,
                                surface: Colors.blueGrey.shade900,
                                onSurface: Colors.white,
                              ),
                              dialogBackgroundColor: Colors.blueGrey.shade800,
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (pickedDate != null) {
                        setState(() {
                          selectedBirthDate = pickedDate;
                          birthDateController.text =
                          "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: _buildTextField(
                        controller: birthDateController,
                        hintText: "Birth Date (YYYY-MM-DD)",
                        icon: Icons.calendar_today,
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  _buildTextField(
                    controller: phoneNumberController,
                    hintText: "Phone Number",
                    icon: Icons.phone,
                  ),
                  SizedBox(height: 15),
                  Row(
                    children: [
                      Icon(Icons.male, color: Colors.cyanAccent),
                      SizedBox(width: 10),
                      Text(
                        "Gender:",
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<bool>(
                          value: isMale,
                          dropdownColor: Colors.blueGrey.shade900,
                          style: TextStyle(color: Colors.white),
                          iconEnabledColor: Colors.cyanAccent,
                          items: [
                            DropdownMenuItem(child: Text("Male"), value: true),
                            DropdownMenuItem(child: Text("Female"), value: false),
                          ],
                          onChanged: (value) {
                            setState(() {
                              isMale = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  _buildRegisterButton(),
                  SizedBox(height: 15),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text(
                      "Already have an account? Log in",
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      readOnly: hintText.contains("Birth Date"),
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.cyanAccent),
        hintText: hintText,
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
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : registerUser,
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
        "Register",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
