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
