import 'package:flutter/material.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _loading = false;

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("أدخل رمز التحقق")),
      );
      return;
    }

    setState(() => _loading = true);
    final error = await _authService.verifyEmail(widget.email, code);
    setState(() => _loading = false);

    if (error == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم التحقق بنجاح")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    final error = await _authService.resendVerification(widget.email);
    setState(() => _loading = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إرسال رمز جديد إلى بريدك")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("التحقق من البريد")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("تم إرسال رمز التحقق إلى ${widget.email}"),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "رمز التحقق",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : Column(
              children: [
                ElevatedButton(
                  onPressed: _verify,
                  child: const Text("تأكيد"),
                ),
                TextButton(
                  onPressed: _resend,
                  child: const Text("إعادة إرسال الرمز"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
