int? parseBrlToCents(String raw) {
  final text = raw.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (text.isEmpty) return null;
  final normalized = text.contains(',')
      ? text.replaceAll('.', '').replaceAll(',', '.')
      : text;
  final value = double.tryParse(normalized);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}

double? parseDecimalQuantity(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  final value = double.tryParse(text);
  if (value == null || value <= 0) return null;
  return value;
}

DateTime? parseBrazilianDay(String raw) {
  final parts = raw.trim().split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31 || year < 2000) {
    return null;
  }
  final date = DateTime(year, month, day);
  if (date.day != day || date.month != month || date.year != year) return null;
  return date;
}
