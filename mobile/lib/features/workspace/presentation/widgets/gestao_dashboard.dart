import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/posted_sale.dart';
import '../../domain/rules/month_board.dart';
import '../bloc/company_operation_bloc.dart';
import '../operation_labels.dart';
import '../pages/customer_debt_page.dart';
import '../pages/due_today_page.dart';

const _ink = Color(0xFF123F32);
const _label = Color(0xFF535D57);
const _caption = Color(0xFF717970);
const _summary = Color(0xFF626B64);
const _line = Color(0xFFE3E5DF);
const _receivedInk = Color(0xFF286638);
const _receivedFill = Color(0xFFEAF4EB);
const _openInk = Color(0xFFA45135);
const _openFill = Color(0xFFFCECE2);
const _barReceived = Color(0xFF4D8B50);
const _barOpen = Color(0xFFF6D8C7);
const _barEmpty = Color(0xFFE7E9E5);
const _bar = Color(0xFF4D8B50);

const _shortMonths = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

String _monthShort(DateTime month) =>
    '${_shortMonths[month.month - 1]} ${month.year}';

class GestaoDashboard extends StatefulWidget {
  const GestaoDashboard({
    super.key,
    required this.sales,
    required this.onOpenSettings,
    this.onOpenCustomer,
    this.hidden = false,
    this.clock,
  });

  final List<PostedSale> sales;
  final VoidCallback onOpenSettings;
  final ValueChanged<DueTodayCustomer>? onOpenCustomer;
  final bool hidden;
  final DateTime Function()? clock;

  @override
  State<GestaoDashboard> createState() => _GestaoDashboardState();
}

class _GestaoDashboardState extends State<GestaoDashboard> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final today = _today;
    _month = DateTime(today.year, today.month);
  }

  DateTime get _today {
    final now = widget.clock?.call() ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final month = monthSnapshot(
      sales: widget.sales,
      month: _month,
      today: today,
    );
    final due = duesToday(sales: widget.sales, today: today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthHeading(month: _month, onShift: _shift),
        const SizedBox(height: 16),
        _BillingCard(snapshot: month, monthDate: _month, hidden: widget.hidden),
        const SizedBox(height: 24),
        _DueHeader(
          due: due,
          hidden: widget.hidden,
          onOpenAll: () {
            final bloc = context.read<CompanyOperationBloc>();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: bloc,
                  child: DueTodayPage(clock: widget.clock),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _DueList(due: due, hidden: widget.hidden, onOpen: _openDebt),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('open_settings_button'),
            style: TextButton.styleFrom(
              foregroundColor: _ink,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text(
              'Ajustes',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  void _openDebt(DueTodayCustomer customer) {
    final override = widget.onOpenCustomer;
    if (override != null) {
      override(customer);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerDebtPage(
          customerId: customer.customerId,
          customerName: customer.customerName,
        ),
      ),
    );
  }
}

class _MonthHeading extends StatelessWidget {
  const _MonthHeading({required this.month, required this.onShift});

  final DateTime month;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final title = const Text(
      'Resumo do mês',
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: _ink,
        height: 1.2,
      ),
    );
    final selector = _MonthSelector(month: month, onShift: onShift);
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth = _textWidth(context, title);
        final selectorWidth = _selectorWidth(context, _monthShort(month));
        final stacked = titleWidth + 8 + selectorWidth > constraints.maxWidth;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 8), selector],
          );
        }
        return Row(
          children: [title, const Spacer(), const SizedBox(width: 8), selector],
        );
      },
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.onShift});

  final DateTime month;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MonthArrow(
          key: const Key('month_previous'),
          tooltip: 'Mês anterior',
          icon: Icons.chevron_left,
          onPressed: () => onShift(-1),
        ),
        Text(
          _monthShort(month),
          key: const Key('month_label'),
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        _MonthArrow(
          key: const Key('month_next'),
          tooltip: 'Próximo mês',
          icon: Icons.chevron_right,
          onPressed: () => onShift(1),
        ),
      ],
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22, color: _ink),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _BillingCard extends StatelessWidget {
  const _BillingCard({
    required this.snapshot,
    required this.monthDate,
    required this.hidden,
  });

  final MonthSnapshot snapshot;
  final DateTime monthDate;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final percent = snapshot.receivedPercent;
    final monthName = monthNames[monthDate.month - 1].toLowerCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Faturamento do mês',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _label,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatBrl(snapshot.billedCents, hidden: hidden),
                key: const Key('month_billed'),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              snapshot.empty
                  ? 'Nenhuma venda confirmada em $monthName'
                  : 'Vendas realizadas em $monthName',
              style: const TextStyle(fontSize: 12, color: _caption),
            ),
            const _Rule(),
            _IndicatorRow(snapshot: snapshot, hidden: hidden),
            const SizedBox(height: 12),
            const Text(
              'Recebimentos das vendas deste mês',
              style: TextStyle(fontSize: 12, color: _caption),
            ),
            const SizedBox(height: 8),
            _ShareBar(percent: snapshot.empty ? null : percent),
            const SizedBox(height: 8),
            Text(
              snapshot.empty
                  ? 'Sem faturamento no período'
                  : '$percent% do faturamento recebido',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const _Rule(),
            const Text(
              'Vendas no mês',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _chartHeight(context),
              width: double.infinity,
              child: snapshot.empty || snapshot.chartDays == 0
                  ? const Center(
                      child: Text(
                        'Nenhuma venda neste mês.',
                        key: Key('month_chart_empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: _caption),
                      ),
                    )
                  : _Bars(month: snapshot, hidden: hidden),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(color: _line),
        child: SizedBox(height: 1, width: double.infinity),
      ),
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({required this.snapshot, required this.hidden});

  final MonthSnapshot snapshot;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final received = _Indicator(
      label: 'Já recebido',
      value: formatBrl(snapshot.receivedCents, hidden: hidden),
      valueKey: const Key('month_received'),
      fill: _receivedFill,
      ink: _receivedInk,
    );
    final open = _Indicator(
      label: 'Falta receber',
      value: formatBrl(snapshot.openCents, hidden: hidden),
      valueKey: const Key('month_open'),
      fill: _openFill,
      ink: _openInk,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final half = (constraints.maxWidth - 12) / 2;
        if (half < 108 || scale > 1.3) {
          return Column(children: [received, const SizedBox(height: 12), open]);
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: received),
              const SizedBox(width: 12),
              Expanded(child: open),
            ],
          ),
        );
      },
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.fill,
    required this.ink,
  });

  final String label;
  final String value;
  final Key valueKey;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                key: valueKey,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ink,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.percent});

  final int? percent;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 12,
        width: double.infinity,
        child: value == null
            ? const ColoredBox(color: _barEmpty)
            : Row(
                children: [
                  if (value > 0)
                    Expanded(
                      flex: value,
                      child: const ColoredBox(color: _barReceived),
                    ),
                  if (value < 100)
                    Expanded(
                      flex: 100 - value,
                      child: const ColoredBox(color: _barOpen),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Bars extends StatefulWidget {
  const _Bars({required this.month, required this.hidden});

  final MonthSnapshot month;
  final bool hidden;

  @override
  State<_Bars> createState() => _BarsState();
}

class _BarsState extends State<_Bars> {
  int? _day;

  @override
  Widget build(BuildContext context) {
    final days = widget.month.chartDays;
    final selected = _day != null && _day! >= 1 && _day! <= days
        ? _day!
        : _defaultDay(widget.month);
    final amount = widget.month.salesByDay[selected] ?? 0;
    final peak = widget.month.salesByDay.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              const Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_GridLine(), _GridLine(), _GridLine(), _GridLine()],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var day = 1; day <= days; day++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _day = day),
                        behavior: HitTestBehavior.opaque,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: _factor(
                              widget.month.salesByDay[day] ?? 0,
                              peak,
                            ),
                            widthFactor: 0.55,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: day == selected ? _receivedInk : _bar,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var day = 1; day <= days; day++)
              Expanded(
                child: Text(
                  day == 1 || day == days || day % 5 == 0 ? '$day' : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: day == selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _caption,
                  ),
                ),
              ),
          ],
        ),
        Text(
          'Dia ${selected.toString().padLeft(2, '0')} · ${formatBrl(amount, hidden: widget.hidden)}',
          key: const Key('month_chart_value'),
          style: const TextStyle(fontSize: 11, color: _caption),
        ),
      ],
    );
  }
}

class _GridLine extends StatelessWidget {
  const _GridLine();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: _line),
      child: SizedBox(height: 1, width: double.infinity),
    );
  }
}

double _chartHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  if (scale <= 1) return 140;
  return 140 + (scale - 1) * 56;
}

double _factor(int amount, int peak) {
  if (amount <= 0 || peak <= 0) return 0;
  final value = amount / peak;
  if (value < 0.08) return 0.08;
  return value;
}

int _defaultDay(MonthSnapshot month) {
  var chosen = 1;
  for (final day in month.salesByDay.keys) {
    if (day > chosen) chosen = day;
  }
  return chosen;
}

class _DueHeader extends StatelessWidget {
  const _DueHeader({
    required this.due,
    required this.hidden,
    required this.onOpenAll,
  });

  final List<DueTodayCustomer> due;
  final bool hidden;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final count = due.length;
    final people = count == 1 ? '1 cliente' : '$count clientes';
    final total = due.fold<int>(0, (sum, customer) => sum + customer.dueCents);
    const title = Text(
      'A receber hoje',
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: _ink,
        height: 1.2,
      ),
    );
    final action = TextButton(
      key: const Key('due_today_all'),
      style: TextButton.styleFrom(
        foregroundColor: _receivedInk,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onOpenAll,
      child: const Text(
        'Ver todos',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
    final summary = Text(
      '$people • ${formatBrl(total, hidden: hidden)}',
      key: const Key('due_today_total'),
      maxLines: 1,
      softWrap: false,
      style: const TextStyle(fontSize: 13, color: _summary),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth = _textWidth(context, title);
        final actionWidth = _textWidth(context, action.child! as Text) + 24;
        final fits = titleWidth + 8 + actionWidth <= constraints.maxWidth;
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              Row(
                children: [
                  Expanded(child: summary),
                  action,
                ],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                title,
                const Spacer(),
                const SizedBox(width: 8),
                action,
              ],
            ),
            summary,
          ],
        );
      },
    );
  }
}

class _DueList extends StatelessWidget {
  const _DueList({
    required this.due,
    required this.hidden,
    required this.onOpen,
  });

  final List<DueTodayCustomer> due;
  final bool hidden;
  final ValueChanged<DueTodayCustomer> onOpen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: due.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nenhum recebimento previsto para hoje.',
                key: Key('due_today_empty'),
                style: TextStyle(fontSize: 14, color: _caption),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < due.length; index++) ...[
                  if (index > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: _line),
                        child: SizedBox(height: 1, width: double.infinity),
                      ),
                    ),
                  DueTodayTile(
                    customer: due[index],
                    hidden: hidden,
                    embedded: true,
                    onTap: () => onOpen(due[index]),
                  ),
                ],
              ],
            ),
    );
  }
}

class DueTodayTile extends StatelessWidget {
  const DueTodayTile({
    super.key,
    required this.customer,
    required this.onTap,
    this.hidden = false,
    this.embedded = false,
  });

  final DueTodayCustomer customer;
  final VoidCallback onTap;
  final bool hidden;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final count = customer.purchaseCount;
    final detail = count == 0
        ? 'Vence hoje'
        : count == 1
        ? 'Vence hoje · 1 compra'
        : 'Vence hoje · $count compras';
    final row = InkWell(
      key: Key('due_customer_${customer.customerId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            _Avatar(name: customer.customerName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _caption),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatBrl(customer.dueCents, hidden: hidden),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: _caption),
          ],
        ),
      ),
    );
    if (embedded) return row;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: row,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFD7F2DF),
      Color(0xFFFFF3C9),
      Color(0xFFFFE3D4),
      Color(0xFFE3F2FD),
    ];
    final index = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return CircleAvatar(
      radius: 20,
      backgroundColor: colors[index % colors.length],
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.single;
    return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

double _textWidth(BuildContext context, Text text) {
  final painter = TextPainter(
    text: TextSpan(text: text.data, style: text.style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

double _selectorWidth(BuildContext context, String label) {
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width + 72;
}
