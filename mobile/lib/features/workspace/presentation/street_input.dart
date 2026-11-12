import 'package:flutter/services.dart';

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

/// Digits-as-cents mask for fields that already show `R$` via [prefixText].
/// Typing `990` becomes `9,90`; `123456` becomes `1.234,56`.
class BrlCentsInputFormatter extends TextInputFormatter {
  const BrlCentsInputFormatter({this.maxDigits = 11});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxDigits) {
      digits = digits.substring(digits.length - maxDigits);
    }
    final cents = digits.isEmpty ? 0 : int.parse(digits);
    final text = formatBrlCentsInput(cents);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Amount without the `R$` prefix, for masked money fields.
String formatBrlCentsInput(int cents) {
  final value = cents.abs();
  final whole = value ~/ 100;
  final fraction = (value % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    if (index > 0 && remaining % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return '$buffer,$fraction';
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
