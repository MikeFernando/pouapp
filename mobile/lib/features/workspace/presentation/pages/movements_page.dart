import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../assistant/presentation/widgets/voice_mic.dart';
import '../../domain/entities/sales_board.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/company_indicators.dart';
import '../bloc/company_operation_bloc.dart';
import '../operation_labels.dart';

class MovementsPage extends StatefulWidget {
  const MovementsPage({super.key, this.onCreate});

  final VoidCallback? onCreate;

  @override
  State<MovementsPage> createState() => _MovementsPageState();
}

class _MovementsPageState extends State<MovementsPage> {
  var _searching = false;
  var _query = '';
  _MovementKind _kind = _MovementKind.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      floatingActionButtonLocation: const AboveVoiceMicLocation(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        onPressed: widget.onCreate,
        child: const Icon(Icons.add, size: 28),
      ),
      body: BlocBuilder<CompanyOperationBloc, CompanyOperationState>(
        builder: (context, state) {
          final operation = state.operation;
          final sales = operation?.sales ?? const <RecentSale>[];
          final visible = [
            for (final sale in sales)
              if (_matches(sale)) sale,
          ];
          final openCents = operation?.summary.receivableCents;
          final periodCents = operation?.summary.soldCents;
          final hasSales = sales.isNotEmpty;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                title: _searching
                    ? TextField(
                        key: const Key('movements_search'),
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          hintText: 'Buscar lançamento',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      )
                    : const Text('Movimentações'),
                actions: [
                  IconButton(
                    tooltip: 'Filtrar',
                    onPressed: _pickKind,
                    icon: const Icon(Icons.filter_alt_outlined),
                  ),
                  IconButton(
                    tooltip: 'Buscar',
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query = '';
                    }),
                    icon: Icon(_searching ? Icons.close : Icons.search),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const Text(
                      CompanyIndicators.soldScope,
                      key: Key('movements_scope'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Filtro por mês indisponível: vendas antigas não têm data.',
                      key: Key('movements_month_unavailable'),
                      style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _TypesButton(kind: _kind, onPressed: _pickKind),
                    ),
                    const SizedBox(height: 12),
                    _IncomeChart(hasAmount: (openCents ?? 0) > 0),
                    const SizedBox(height: 8),
                    _SummaryCard(
                      openCents: openCents,
                      periodCents: periodCents,
                      onOpen: () => setState(
                        () => _kind = _kind == _MovementKind.open
                            ? _MovementKind.all
                            : _MovementKind.open,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Lançamentos',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                        ),
                        Text(
                          '${visible.length} ${visible.length == 1 ? 'registro' : 'registros'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          hasSales
                              ? 'Nenhum lançamento com esse filtro.'
                              : 'Nenhum lançamento registrado.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final sale in visible) ...[
                        _MovementTile(sale: sale),
                        const SizedBox(height: 10),
                      ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matches(RecentSale sale) {
    final kindMatches = switch (_kind) {
      _MovementKind.all => true,
      _MovementKind.open => sale.paymentStatus == PaymentStatus.pending,
      _MovementKind.received => sale.paymentStatus == PaymentStatus.received,
    };
    if (!kindMatches) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return sale.customerName.toLowerCase().contains(query) ||
        sale.code.toLowerCase().contains(query);
  }

  Future<void> _pickKind() async {
    final selected = await showModalBottomSheet<_MovementKind>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in _MovementKind.values)
              ListTile(
                title: Text(kind.label),
                trailing: kind == _kind ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, kind),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _kind = selected);
  }
}

enum _MovementKind {
  all('Todas'),
  open('Em aberto'),
  received('Recebidas');

  const _MovementKind(this.label);

  final String label;
}

class _TypesButton extends StatelessWidget {
  const _TypesButton({required this.kind, required this.onPressed});

  final _MovementKind kind;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = kind == _MovementKind.all ? 'Tipos' : kind.label;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1C1C1E),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE0E3E7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}

class _IncomeChart extends StatelessWidget {
  const _IncomeChart({required this.hasAmount});

  final bool hasAmount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: const _ChartGridPainter(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: 42,
              height: hasAmount ? 128 : 6,
              color: const Color(0xFF43A047),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartGridPainter extends CustomPainter {
  const _ChartGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD5D8DE)
      ..strokeWidth = 1;
    for (var index = 0; index < 5; index++) {
      final y = 16 + index * ((size.height - 32) / 4);
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(x + 6, y), paint);
        x += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.openCents,
    required this.periodCents,
    required this.onOpen,
  });

  final int? openCents;
  final int? periodCents;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 12, color: Color(0xFF43A047)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Receitas em aberto',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 16, 12),
            child: Text(
              formatOptionalBrl(openCents),
              key: const Key('movements_open'),
              style: const TextStyle(fontSize: 16, color: Color(0xFF3A3A3C)),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  CompanyIndicators.soldLabel,
                  style: TextStyle(fontSize: 15, color: Color(0xFF3A3A3C)),
                ),
                const Text(
                  CompanyIndicators.soldScope,
                  key: Key('movements_total_scope'),
                  style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                ),
                const SizedBox(height: 4),
                Text(
                  formatOptionalBrl(periodCents),
                  key: const Key('movements_total'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.sale});

  final RecentSale sale;

  @override
  Widget build(BuildContext context) {
    final pending = sale.paymentStatus == PaymentStatus.pending;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: pending
                  ? const Color(0xFFE53935)
                  : const Color(0xFF43A047),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusChip(pending: pending),
                        const Spacer(),
                        Text(
                          formatBrl(sale.amountCents),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sale.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF3A3A3C),
                      ),
                    ),
                    Text(
                      'Venda ${sale.code}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    if (sale.occurredOn != null)
                      Text(
                        formatDay(dateFromIso(sale.occurredOn!)),
                        key: Key('movement_date_${sale.id}'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const _CategoryChip(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.pending});

  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: pending ? const Color(0xFFFFF4D6) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        pending ? 'Em aberto' : 'Recebido',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: pending ? const Color(0xFF8D6E00) : const Color(0xFF2E7D32),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Receitas de Vendas',
        style: TextStyle(fontSize: 12, color: Color(0xFF636366)),
      ),
    );
  }
}
