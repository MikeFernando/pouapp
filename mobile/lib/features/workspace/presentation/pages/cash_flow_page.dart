import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';

import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/company_indicators.dart';
import '../bloc/company_operation_bloc.dart';
import '../operation_labels.dart';

class CashFlowPage extends StatefulWidget {
  const CashFlowPage({super.key});

  @override
  State<CashFlowPage> createState() => _CashFlowPageState();
}

class _CashFlowPageState extends State<CashFlowPage> {
  DateTime? _month;
  int? _selectedDay;
  int? _expandedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: pouAppBlue,
        foregroundColor: Colors.white,
        title: const Text('Fluxo de caixa diário'),
      ),
      body: BlocBuilder<CompanyOperationBloc, CompanyOperationState>(
        builder: (context, state) {
          final ledger = state.operation?.street ?? const StreetLedger();
          final month =
              _month ??
              _monthOf(ledger, state.operation?.accountPayments ?? const []);
          final receipts = receiptsByDay(
            ledger,
            month,
            more: state.operation?.accountPayments ?? const [],
          );
          final selected = _selectedDay ?? _defaultDay(receipts, month);
          final days = DateTime(month.year, month.month + 1, 0).day;
          final monthReceipts = receipts.values.fold<int>(
            0,
            (sum, value) => sum + value,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _MonthSwitcher(
                label: monthHeading(month),
                onPrevious: () => _changeMonth(month, -1),
                onNext: () => _changeMonth(month, 1),
              ),
              const SizedBox(height: 16),
              _ReceiptChart(
                days: days,
                month: month.month,
                selectedDay: selected,
                receipts: receipts,
                onSelect: (day) => setState(() {
                  _selectedDay = day;
                  _expandedDay = day;
                }),
              ),
              const SizedBox(height: 16),
              _FlowCard(
                receiptsLabel: receiptsInMonthLabel(month),
                receipts: monthReceipts,
                payments: null,
                receiptsKey: const Key('cash_flow_receipts'),
                paymentsKey: const Key('cash_flow_payments'),
                balanceKey: const Key('cash_flow_balance'),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var day = 1; day <= days; day++) ...[
                      if (day > 1) const Divider(height: 1),
                      _DayRow(
                        label: formatDay(
                          DateTime(month.year, month.month, day),
                        ),
                        receiptsLabel:
                            'Recebimentos em ${formatDay(DateTime(month.year, month.month, day))}',
                        expanded: _expandedDay == day,
                        receipts: receipts[day] ?? 0,
                        onTap: () => setState(() {
                          _selectedDay = day;
                          _expandedDay = _expandedDay == day ? null : day;
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime _monthOf(StreetLedger ledger, List<CustomerPayment> more) {
    DateTime? latest;
    for (final payment in [
      ...ledger.payments.where((payment) => !payment.fromSeed),
      ...more,
    ]) {
      final date = dateFromIso(payment.paidOn);
      if (latest == null || date.isAfter(latest)) latest = date;
    }
    final anchor = latest ?? DateTime.now();
    return DateTime(anchor.year, anchor.month);
  }

  void _changeMonth(DateTime month, int delta) {
    setState(() {
      _month = DateTime(month.year, month.month + delta);
      _selectedDay = null;
      _expandedDay = null;
    });
  }
}

int _defaultDay(Map<int, int> receipts, DateTime month) {
  var chosen = 1;
  var highest = -1;
  for (final entry in receipts.entries) {
    if (entry.value > highest) {
      highest = entry.value;
      chosen = entry.key;
    }
  }
  if (highest > 0) return chosen;
  final now = DateTime.now();
  if (now.year == month.year && now.month == month.month) return now.day;
  return 1;
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, color: pouAppBlue),
          ),
          Expanded(
            child: Text(
              label,
              key: const Key('cash_flow_month'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: pouAppBlue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Próximo mês',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, color: pouAppBlue),
          ),
        ],
      ),
    );
  }
}

class _ReceiptChart extends StatelessWidget {
  const _ReceiptChart({
    required this.days,
    required this.month,
    required this.selectedDay,
    required this.receipts,
    required this.onSelect,
  });

  final int days;
  final int month;
  final int selectedDay;
  final Map<int, int> receipts;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final start = (selectedDay - 2).clamp(1, days);
    final end = (start + 4).clamp(start, days);
    final visible = [for (var day = start; day <= end; day++) day];
    final peak = receipts.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    return SizedBox(
      height: 168,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in visible)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(day),
                child: Column(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: day == selectedDay
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 28,
                            height: _barHeight(receipts[day] ?? 0, peak),
                            color: const Color(0xFF43A047),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      day == selectedDay ? '$day/$month' : '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: day == selectedDay
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _barHeight(int cents, int peak) {
    if (cents <= 0 || peak <= 0) return 0;
    return 18 + (92 * cents / peak);
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    required this.receiptsLabel,
    required this.receipts,
    required this.payments,
    this.receiptsKey,
    this.paymentsKey,
    this.balanceKey,
  });

  final String receiptsLabel;
  final int receipts;

  /// Company expenses are not recorded yet. Null is not the same as zero.
  final int? payments;
  final Key? receiptsKey;
  final Key? paymentsKey;
  final Key? balanceKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            _FlowLine(
              color: const Color(0xFF43A047),
              label: receiptsLabel,
              value: formatBrl(receipts),
              valueKey: receiptsKey,
            ),
            const SizedBox(height: 10),
            _FlowLine(
              color: const Color(0xFFE53935),
              label: 'Pagamentos',
              value: formatOptionalBrl(payments),
              valueKey: paymentsKey,
            ),
            const SizedBox(height: 10),
            _FlowLine(
              color: pouAppBlue,
              label: 'Saldo',
              value: payments == null
                  ? indicatorUnavailable
                  : formatBrl(receipts - payments!),
              valueKey: balanceKey,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowLine extends StatelessWidget {
  const _FlowLine({
    required this.color,
    required this.label,
    required this.value,
    this.valueKey,
  });

  final Color color;
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.receiptsLabel,
    required this.expanded,
    required this.receipts,
    required this.onTap,
  });

  final String label;
  final String receiptsLabel;
  final bool expanded;
  final int receipts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 16)),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: pouAppBlue,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              _FlowLine(
                color: const Color(0xFF43A047),
                label: receiptsLabel,
                value: formatBrl(receipts),
              ),
              const SizedBox(height: 8),
              _FlowLine(
                color: const Color(0xFFE53935),
                label: 'Pagamentos',
                value: indicatorUnavailable,
              ),
              const SizedBox(height: 8),
              _FlowLine(
                color: pouAppBlue,
                label: 'Saldo',
                value: indicatorUnavailable,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
