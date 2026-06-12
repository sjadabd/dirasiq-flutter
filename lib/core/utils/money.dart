import 'package:flutter/services.dart';

/// Money formatting shared across the app.
///
/// Amounts always render with thousands separators and **no decimals**
/// (e.g. `100000.00` → `100,000`). Currency in IQD has no fractional units in
/// practice, so the `.00` the API sends is dropped for display.
String fmtMoney(dynamic v) {
  final n = num.tryParse((v ?? '').toString());
  if (n == null) return '0';
  return n
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}

/// Live thousands-separator formatter for money entry fields. Keeps only digits
/// and re-inserts commas as the user types (e.g. `50000` → `50,000`) so the
/// amount stays readable. Parse the field back with
/// `text.replaceAll(RegExp(r'[^0-9]'), '')`.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
