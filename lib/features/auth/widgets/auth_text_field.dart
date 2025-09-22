import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;   // ✅ إضافة
  final TextInputAction textInputAction; // ✅ للتنقل بين الحقول
  final void Function(String)? onChanged; // ✅ للتعامل مع القيم

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,   // قيمة افتراضية
    this.textInputAction = TextInputAction.next,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,          // ✅ الآن مدعوم
      textInputAction: textInputAction,    // ✅ للتنقل بين الحقول
      onChanged: onChanged,                // ✅ يدعم الاستماع للتغيير
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
