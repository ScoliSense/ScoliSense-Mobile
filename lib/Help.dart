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
        "Yardım",
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
              "Sıkça Sorulan Sorular",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 20),
            _buildExpansionTile(
              title: "Scoliosis Brace nedir?",
              content: "Scoliosis Brace, omurga eğriliğini düzeltmek için kullanılan bir cihazdır.",
            ),
            _buildExpansionTile(
              title: "Cihaz bağlantı hatası alıyorum, ne yapmalıyım?",
              content: "Cihazınızı Bluetooth ile tekrar bağlamayı deneyin veya uygulamayı yeniden başlatın.",
            ),
            _buildExpansionTile(
              title: "Uygulamayı nasıl güncelleyebilirim?",
              content: "App Store veya Google Play'den güncellemeleri kontrol edebilirsiniz.",
            ),
            _buildExpansionTile(
              title: "Verilerim güvende mi?",
              content: "Verileriniz güvenli bir şekilde şifrelenir ve gizliliğiniz korunur.",
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
              alignment: Alignment.centerLeft, // Aligns text to the left
              padding: EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 20.0),
              child: Text(
                content,
                textAlign: TextAlign.left, // Ensures left alignment
                style: TextStyle(
                  color: Colors.cyanAccent.withOpacity(0.8),
                  fontSize: 17, // Slightly larger font size
                  height: 1.6, // Increased line height for better readability
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


