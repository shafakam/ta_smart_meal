import 'package:flutter/material.dart';

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saran & Kesan TPM")),
      body: const Padding( // Tambahkan const di sini karena isinya statis
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text("Kesan Kuliah TPM:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Sangat menantang karena harus menggabungkan banyak fitur mobile dalam satu aplikasi."),
                    SizedBox(height: 10),
                    Text("Saran:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Semoga kedepannya waktu pengerjaan proyek akhir bisa lebih lama."),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}