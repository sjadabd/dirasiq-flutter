import 'package:flutter/material.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:dirasiq/features/auth/screens/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _logout(BuildContext context) async {
    final authService = AuthService();
    await authService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الرئيسية - درس عراق"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "أهلاً بك في تطبيق درس عراق 🎓",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // لاحقًا ممكن نفتح صفحة الدورات أو الملف الشخصي
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("قريبًا: صفحة الدورات 🚀")),
                );
              },
              child: const Text("ابدأ الآن"),
            ),
          ],
        ),
      ),
    );
  }
}
