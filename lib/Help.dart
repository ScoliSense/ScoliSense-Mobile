import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(),
    );
  }

  /// Creates a futuristic dark app bar with a back button.
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.cyanAccent),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Text(
        "Help",
        style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  /// Creates the main futuristic body content.
  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black, // Dark futuristic background
            Colors.blueGrey.shade900,
            Colors.blueGrey.shade800,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              "Frequently Asked Questions",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 20),
            _buildExpansionTile(
              title: "What is a Scoliosis Brace?",
              content: "A Scoliosis Brace is a device used to correct spinal curvature.",
            ),
            _buildExpansionTile(
              title: "I am getting a device connection error, what should I do?",
              content: "Try reconnecting your device via Bluetooth or restarting the app.",
            ),
            _buildExpansionTile(
              title: "How can I update the app?",
              content: "You can check for updates via the App Store or Google Play Store.",
            ),
            _buildExpansionTile(
              title: "Is my data safe?",
              content: "Your data is securely encrypted and your privacy is protected.",
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a futuristic ExpansionTile with neon cyan glow and left-aligned text.
  Widget _buildExpansionTile({required String title, required String content}) {
    return Theme(
      data: ThemeData().copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade800.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ExpansionTile(
          iconColor: Colors.cyanAccent,
          collapsedIconColor: Colors.cyanAccent,
          title: Text(
            title,
            style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          children: [
            Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 20.0),
              child: Text(
                content,
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Colors.cyanAccent.withOpacity(0.8),
                  fontSize: 17,
                  height: 1.6,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
