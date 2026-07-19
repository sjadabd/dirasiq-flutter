/// Formats user-facing clock values with an explicit Arabic 12-hour suffix.
///
/// Database/API values should remain canonical 24-hour/ISO strings. Use this
/// helper only at the presentation boundary.
String formatTime12(Object? value) {
  if (value == null) return '';
  if (value is DateTime) return _formatDateTimeTime(value);

  final raw = value.toString().trim();
  if (raw.isEmpty) return '';

  final iso = DateTime.tryParse(raw);
  if (iso != null && (raw.contains('T') || raw.contains('-'))) {
    return _formatDateTimeTime(iso.toLocal());
  }

  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) return raw;
  var hour = int.tryParse(match.group(1)!) ?? 0;
  final minute = match.group(2)!;
  final lower = raw.toLowerCase();
  final hasPm =
      raw.contains('مساء') ||
      RegExp(r'(^|\s)م(\s|$)').hasMatch(raw) ||
      RegExp(r'(^|\s)pm(\s|$)').hasMatch(lower);
  final hasAm =
      raw.contains('صباح') ||
      RegExp(r'(^|\s)ص(\s|$)').hasMatch(raw) ||
      RegExp(r'(^|\s)am(\s|$)').hasMatch(lower);
  if (hasPm && hour < 12) hour += 12;
  if (hasAm && hour == 12) hour = 0;
  hour %= 24;

  final suffix = hour >= 12 ? 'م' : 'ص';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:$minute $suffix';
}

String formatDateTime12(
  DateTime value, {
  bool includeDate = true,
  String dateSeparator = '/',
}) {
  final local = value.toLocal();
  final time = _formatDateTimeTime(local);
  if (!includeDate) return time;
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day$dateSeparator$month $time';
}

String formatTimeRange12(Object? start, Object? end) {
  final from = formatTime12(start);
  final to = formatTime12(end);
  if (from.isEmpty) return to;
  if (to.isEmpty) return from;
  return '$from - $to';
}

String _formatDateTimeTime(DateTime value) {
  final suffix = value.hour >= 12 ? 'م' : 'ص';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute $suffix';
}
