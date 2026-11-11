import 'package:flutter/material.dart';

import 'pou_app_colors.dart';

const _muted = Color(0xFF9CA3AF);
const _dayText = Color(0xFF6B7280);

Future<DateTime?> showPouDateSheet(
  BuildContext context, {
  required DateTime initial,
  required String title,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => PouDateSheet(
      initial: initial,
      title: title,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class PouDateSheet extends StatefulWidget {
  const PouDateSheet({
    super.key,
    required this.initial,
    required this.title,
    this.firstDate,
    this.lastDate,
  });

  final DateTime initial;
  final String title;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<PouDateSheet> createState() => _PouDateSheetState();
}

class _PouDateSheetState extends State<PouDateSheet> {
  late DateTime _selected;
  late DateTime _month;

  static const _months = [
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

  DateTime get _first {
    final value = widget.firstDate ?? DateTime(2020);
    return DateTime(value.year, value.month, value.day);
  }

  DateTime get _last {
    final value = widget.lastDate ?? DateTime(2100);
    return DateTime(value.year, value.month, value.day);
  }

  @override
  void initState() {
    super.initState();
    final initial = DateTime(
      widget.initial.year,
      widget.initial.month,
      widget.initial.day,
    );
    _selected = initial.isBefore(_first)
        ? _first
        : initial.isAfter(_last)
        ? _last
        : initial;
    _month = DateTime(_selected.year, _selected.month);
  }

  @override
  Widget build(BuildContext context) {
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month).weekday % 7;
    final rows = ((leading + days) / 7).ceil();
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: pouInk,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                IconButton(
                  key: const Key('due_prev_month'),
                  onPressed: () {
                    final previous = DateTime(_month.year, _month.month - 1);
                    if (DateTime(previous.year, previous.month + 1, 0)
                        .isBefore(_first)) {
                      return;
                    }
                    setState(() => _month = previous);
                  },
                  icon: const Icon(Icons.chevron_left, color: pouInk),
                ),
                Expanded(
                  child: Text(
                    '${_months[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: pouInk,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('due_next_month'),
                  onPressed: () {
                    final next = DateTime(_month.year, _month.month + 1);
                    if (DateTime(next.year, next.month).isAfter(_last)) {
                      return;
                    }
                    setState(() => _month = next);
                  },
                  icon: const Icon(Icons.chevron_right, color: pouInk),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final label in ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var row = 0; row < rows; row++)
              Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: _dayCell(row * 7 + column - leading + 1, days),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Você escolheu',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _dayText,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selected.day} de ${_months[_selected.month - 1]} de ${_selected.year}',
                key: const Key('due_chosen'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: pouInk,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: FilledButton(
                key: const Key('due_confirm'),
                onPressed: () => Navigator.of(context).pop(_selected),
                style: FilledButton.styleFrom(
                  backgroundColor: pouInk,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Confirmar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: 44);
    }
    final date = DateTime(_month.year, _month.month, day);
    final selected = _sameDay(date, _selected);
    final enabled = !date.isBefore(
          DateTime(_first.year, _first.month, _first.day),
        ) &&
        !date.isAfter(DateTime(_last.year, _last.month, _last.day));

    return SizedBox(
      height: 44,
      child: InkWell(
        key: Key('due_day_$day'),
        customBorder: const CircleBorder(),
        onTap: enabled ? () => setState(() => _selected = date) : null,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? pouInk : null,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: !enabled
                        ? const Color(0xFFD1D5DB)
                        : selected
                        ? Colors.white
                        : _dayText,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
