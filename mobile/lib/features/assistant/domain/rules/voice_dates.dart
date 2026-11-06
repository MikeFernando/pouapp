class SpokenDate {
  const SpokenDate({this.day, this.month, this.year, this.plusDays});

  final int? day;
  final int? month;
  final int? year;
  final int? plusDays;
}

class ResolvedDate {
  const ResolvedDate({this.date, this.question, this.alternative});

  final DateTime? date;
  final String? question;

  /// Offered when the spoken month already passed this year.
  final DateTime? alternative;
}

const _months = {
  'janeiro': 1,
  'fevereiro': 2,
  'marco': 3,
  'abril': 4,
  'maio': 5,
  'junho': 6,
  'julho': 7,
  'agosto': 8,
  'setembro': 9,
  'outubro': 10,
  'novembro': 11,
  'dezembro': 12,
};

const _monthNames = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Reads a due date from a folded phrase. Money amounts are left alone.
SpokenDate? readSpokenDate(String text) {
  final plus = RegExp(
    r'(?:daqui a|em)\s+([a-z0-9]+(?:\s+e\s+[a-z0-9]+)?)\s+dias?\b',
  ).firstMatch(text);
  if (plus != null) {
    final days = _number(plus.group(1)!);
    if (days != null) return SpokenDate(plusDays: days);
  }
  final dated = RegExp(
    '(?:dia )?([a-z0-9]+(?: e [a-z0-9]+)?) de '
    '(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|'
    'outubro|novembro|dezembro)(?: de ([0-9]{4}))?',
  ).firstMatch(text);
  if (dated != null) {
    final day = _number(dated.group(1)!);
    final month = _months[dated.group(2)!];
    final year = int.tryParse(dated.group(3) ?? '');
    if (day != null && month != null) {
      return SpokenDate(day: day, month: month, year: year);
    }
  }
  final only = RegExp(r'\bdia\s+([a-z0-9]+(?:\s+e\s+[a-z0-9]+)?)\b')
      .firstMatch(text);
  if (only != null) {
    final day = _number(only.group(1)!);
    if (day != null) return SpokenDate(day: day);
  }
  return null;
}

ResolvedDate resolveSpokenDate(SpokenDate spoken, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  if (spoken.plusDays != null) {
    if (spoken.plusDays! <= 0) {
      return const ResolvedDate(
        question: 'Diga um prazo de pelo menos um dia.',
      );
    }
    return ResolvedDate(date: day.add(Duration(days: spoken.plusDays!)));
  }
  final number = spoken.day;
  if (number == null || number < 1 || number > 31) {
    return const ResolvedDate(question: 'Qual é o dia do vencimento?');
  }
  if (spoken.month != null) {
    final year = spoken.year ?? day.year;
    final date = _safeDate(year, spoken.month!, number);
    if (date == null) {
      return const ResolvedDate(
        question: 'Essa data não existe. Qual é o vencimento?',
      );
    }
    if (date.isBefore(day)) {
      if (spoken.year != null) {
        return ResolvedDate(
          question: '${formatSpokenDate(date)} já passou. Qual é o vencimento?',
        );
      }
      final next = _safeDate(year + 1, spoken.month!, number);
      return ResolvedDate(
        question:
            '${formatSpokenDate(date)} já passou. É ${formatSpokenDate(next!)}?',
        alternative: next,
      );
    }
    return ResolvedDate(date: date);
  }
  var candidate = _safeDate(day.year, day.month, number);
  if (candidate == null || candidate.isBefore(day)) {
    final nextMonth = DateTime(day.year, day.month + 1, 1);
    candidate = _safeDate(nextMonth.year, nextMonth.month, number);
    if (candidate == null) {
      final after = DateTime(nextMonth.year, nextMonth.month + 1, 1);
      candidate = _safeDate(after.year, after.month, number);
    }
  }
  if (candidate == null) {
    return const ResolvedDate(
      question: 'Essa data não existe. Qual é o vencimento?',
    );
  }
  return ResolvedDate(date: candidate);
}

String formatSpokenDate(DateTime date) {
  return '${date.day} de ${_monthNames[date.month - 1]} de ${date.year}';
}

DateTime? _safeDate(int year, int month, int day) {
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

int? _number(String raw) {
  final digits = int.tryParse(raw);
  if (digits != null) return digits;
  const ones = {
    'um': 1,
    'uma': 1,
    'dois': 2,
    'duas': 2,
    'tres': 3,
    'quatro': 4,
    'cinco': 5,
    'seis': 6,
    'sete': 7,
    'oito': 8,
    'nove': 9,
    'dez': 10,
    'onze': 11,
    'doze': 12,
    'treze': 13,
    'quatorze': 14,
    'catorze': 14,
    'quinze': 15,
    'dezesseis': 16,
    'dezessete': 17,
    'dezoito': 18,
    'dezenove': 19,
  };
  const tens = {
    'vinte': 20,
    'trinta': 30,
    'quarenta': 40,
    'cinquenta': 50,
    'sessenta': 60,
    'setenta': 70,
    'oitenta': 80,
    'noventa': 90,
  };
  if (ones.containsKey(raw)) return ones[raw];
  if (tens.containsKey(raw)) return tens[raw];
  final parts = raw.split(' e ');
  if (parts.length == 2 && tens[parts[0]] != null && ones[parts[1]] != null) {
    return tens[parts[0]]! + ones[parts[1]]!;
  }
  return null;
}
