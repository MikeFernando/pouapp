import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../domain/entities/sales_board.dart';
import '../../domain/entities/street_ledger.dart';
import '../bloc/company_operation_bloc.dart';
import '../operation_labels.dart';
import '../theme/workspace_colors.dart';

class StreetBoardView extends StatefulWidget {
  const StreetBoardView({
    super.key,
    required this.valuesHidden,
    required this.onNewSale,
    required this.onComplete,
    required this.onPostpone,
    required this.onRemove,
    required this.onOpenCustomer,
    required this.onOpenSale,
  });

  final bool valuesHidden;
  final VoidCallback onNewSale;
  final ValueChanged<RouteVisit> onComplete;
  final ValueChanged<RouteVisit> onPostpone;
  final ValueChanged<RouteVisit> onRemove;
  final ValueChanged<RouteVisit> onOpenCustomer;
  final ValueChanged<RecentSale> onOpenSale;

  @override
  State<StreetBoardView> createState() => StreetBoardViewState();
}

class StreetBoardViewState extends State<StreetBoardView>
    with SingleTickerProviderStateMixin {
  final _routeKey = GlobalKey();
  late final AnimationController _entrance;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scroll = ScrollController();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _entrance.dispose();
    super.dispose();
  }

  double _span(double begin, double end) {
    final value = _entrance.value;
    if (value <= begin) return 0;
    if (value >= end) return 1;
    return Curves.easeOutCubic.transform((value - begin) / (end - begin));
  }

  Widget _rise(int index, Widget child) {
    final end = (0.46 + index * 0.12).clamp(0.0, 1.0);
    final begin = (end - 0.36).clamp(0.0, 1.0);
    final shown = _span(begin, end);
    return IgnorePointer(
      ignoring: shown < 1,
      child: Opacity(
        opacity: shown,
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - shown)),
          child: child,
        ),
      ),
    );
  }

  void showRoute() => _reveal(_routeKey);

  void _reveal(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valuesHidden = widget.valuesHidden;
    return BlocBuilder<CompanyOperationBloc, CompanyOperationState>(
      builder: (context, state) {
        final operation = state.operation;
        if (state.status == BoardStatus.initial ||
            state.status == BoardStatus.loading ||
            operation == null && state.status != BoardStatus.failure) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Carregando a rua',
            ),
          );
        }
        if (state.status == BoardStatus.failure || operation == null) {
          return _Message(
            message: state.message ?? 'Não foi possível carregar a rua.',
            onRetry: () => context.read<CompanyOperationBloc>().add(
              const CompanyOperationRequested(),
            ),
          );
        }
        final saleButton = FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: pouInk,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
        final ledger = operation.street;
        final today = visitsOnDay(ledger, ledger.day);
        final later = [
          for (final visit in ledger.visits)
            if (visit.day != ledger.day) visit,
        ]..sort((a, b) => a.day.compareTo(b.day));
        final progress = visitProgress(ledger);
        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                bottom: 0,
                child: SingleChildScrollView(
                  key: const Key('street_board_scroll'),
                  controller: _scroll,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom + 16,
                  ),
                  child: AnimatedBuilder(
                    animation: _entrance,
                    builder: (context, _) {
                      var order = 0;
                      Widget rise(Widget child) => _rise(order++, child);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          rise(
                            _DeliveryBoard(
                              titleKey: _routeKey,
                              progress: progress,
                              today: today,
                              ledger: ledger,
                              valuesHidden: valuesHidden,
                              onComplete: widget.onComplete,
                              onPostpone: widget.onPostpone,
                              onRemove: widget.onRemove,
                              onOpenCustomer: widget.onOpenCustomer,
                            ),
                          ),
                          const SizedBox(height: 16),
                          rise(
                            FilledButton.icon(
                              key: const Key('action_new_sale'),
                              style: saleButton,
                              onPressed: widget.onNewSale,
                              icon: const Icon(Icons.person_add_outlined, color: pouCanvas,),
                              label: const Text('Adicionar', style: TextStyle(color: pouCanvas,),),
                            ),
                          ),
                          if (later.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            const _SectionTitle('Reagendadas'),
                            rise(
                              _SurfaceCard(
                                child: Column(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < later.length;
                                      index++
                                    ) ...[
                                      if (index > 0) const _Hairline(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                key: Key(
                                                  'visit_customer_${later[index].id}',
                                                ),
                                                onTap: () =>
                                                    widget.onOpenCustomer(
                                                      later[index],
                                                    ),
                                                child: Text(
                                                  later[index].customerName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize:
                                                        workspaceFontPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0E0D0F),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              formatDay(
                                                dateFromIso(later[index].day),
                                              ),
                                              style: const TextStyle(
                                                fontSize:
                                                    workspaceFontSecondary,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          const _SectionTitle('Vendas recentes'),
                          rise(
                            _SurfaceCard(
                              child: operation.sales.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'Nenhuma venda recente.',
                                        style: TextStyle(
                                          fontSize: workspaceFontSecondary,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        for (
                                          var index = 0;
                                          index < operation.sales.length;
                                          index++
                                        ) ...[
                                          if (index > 0) const _Hairline(),
                                          _SaleTile(
                                            sale: operation.sales[index],
                                            hidden: valuesHidden,
                                            onTap: () => widget.onOpenSale(
                                              operation.sales[index],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VisitCard extends StatefulWidget {
  const _VisitCard({
    required this.visit,
    required this.ledger,
    required this.valuesHidden,
    required this.onComplete,
    required this.onPostpone,
    required this.onRemove,
    required this.onOpenCustomer,
  });

  final RouteVisit visit;
  final StreetLedger ledger;
  final bool valuesHidden;
  final VoidCallback onComplete;
  final VoidCallback onPostpone;
  final VoidCallback onRemove;
  final VoidCallback onOpenCustomer;

  @override
  State<_VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends State<_VisitCard> {
  static const _reveal = 228.0;
  var _offset = 0.0;
  var _dragging = false;

  void _close() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    final balance = customerBalanceCents(widget.ledger, visit.customerId);
    return Stack(
      key: Key('visit_${visit.id}'),
      children: [
        Positioned.fill(
          child: Row(
            children: [
              const Spacer(),
              SizedBox(
                width: _reveal,
                child: _VisitActions(
                  onComplete: () {
                    _close();
                    widget.onComplete();
                  },
                  onPostpone: () {
                    _close();
                    widget.onPostpone();
                  },
                  onRemove: () {
                    _close();
                    widget.onRemove();
                  },
                  completeKey: Key('done_${visit.id}'),
                  postponeKey: Key('postpone_${visit.id}'),
                  removeKey: Key('remove_visit_${visit.id}'),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: (details) {
            setState(() {
              _offset = (_offset + details.delta.dx).clamp(-_reveal, 0);
            });
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            final open =
                velocity < -300 || (velocity <= 300 && _offset < -_reveal / 2);
            setState(() {
              _dragging = false;
              _offset = open ? -_reveal : 0;
            });
          },
          child: AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 180),
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: Material(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _VisitCheck(
                      done: visit.status == VisitStatus.completed,
                      onTap: visit.status == VisitStatus.completed
                          ? null
                          : () {
                              _close();
                              widget.onComplete();
                            },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        key: Key('visit_customer_${visit.id}'),
                        onTap: widget.onOpenCustomer,
                        child: Text(
                          visit.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: workspaceFontPrimary,
                            fontWeight: FontWeight.w700,
                            color: visit.status == VisitStatus.completed
                                ? const Color(0xFF8B97C2)
                                : const Color(0xFF0E0D0F),
                            decoration: visit.status == VisitStatus.completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: const Color(0xFF8B97C2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatBrl(balance, hidden: widget.valuesHidden),
                      key: Key('visit_balance_${visit.id}'),
                      style: TextStyle(
                        fontSize: workspaceFontPrimary,
                        fontWeight: FontWeight.w700,
                        color: visit.status == VisitStatus.completed
                            ? const Color(0xFF8B97C2)
                            : const Color(0xFF0E0D0F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VisitCheck extends StatelessWidget {
  const _VisitCheck({required this.done, this.onTap});

  final bool done;
  final VoidCallback? onTap;

  static const _blue = pouAccent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: done
          ? const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFE7EDFF),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 22,
                height: 22,
                child: Icon(Icons.check, size: 15, color: _blue),
              ),
            )
          : Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _blue, width: 1.6),
              ),
            ),
    );
  }
}

class _VisitActions extends StatelessWidget {
  const _VisitActions({
    this.onComplete,
    this.onPostpone,
    this.onRemove,
    this.completeKey,
    this.postponeKey,
    this.removeKey,
  });

  final VoidCallback? onComplete;
  final VoidCallback? onPostpone;
  final VoidCallback? onRemove;
  final Key? completeKey;
  final Key? postponeKey;
  final Key? removeKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SwipeAction(
          key: completeKey,
          label: 'Feito',
          color: const Color(0xFF2E7D32),
          onTap: onComplete,
        ),
        _SwipeAction(
          key: postponeKey,
          label: 'Adiar',
          color: const Color(0xFFF9A825),
          onTap: onPostpone,
        ),
        _SwipeAction(
          key: removeKey,
          label: 'Remover',
          color: const Color(0xFFC62828),
          onTap: onRemove,
        ),
      ],
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: workspaceFontSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryBoard extends StatelessWidget {
  const _DeliveryBoard({
    required this.titleKey,
    required this.progress,
    required this.today,
    required this.ledger,
    required this.valuesHidden,
    required this.onComplete,
    required this.onPostpone,
    required this.onRemove,
    required this.onOpenCustomer,
  });

  final Key titleKey;
  final VisitProgress progress;
  final List<RouteVisit> today;
  final StreetLedger ledger;
  final bool valuesHidden;
  final ValueChanged<RouteVisit> onComplete;
  final ValueChanged<RouteVisit> onPostpone;
  final ValueChanged<RouteVisit> onRemove;
  final ValueChanged<RouteVisit> onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final colors = workspaceColorsOf(context);
    final fraction = progress.total == 0 ? 0.0 : progress.done / progress.total;
    final routeDay = formatDay(dateFromIso(ledger.day));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0E0D0F),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Visitas em $routeDay',
                          key: titleKey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: workspaceFontPrimary,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E0D0F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            '${progress.done} de ${progress.total}',
                            key: const Key('route_progress'),
                            style: TextStyle(
                              fontSize: workspaceFontSecondary,
                              fontWeight: FontWeight.w700,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFEEF2F6),
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
            if (today.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Nenhuma entrega em $routeDay.',
                  style: const TextStyle(
                    fontSize: workspaceFontSecondary,
                    color: Color(0xFF6B7280),
                  ),
                ),
              )
            else
              for (var index = 0; index < today.length; index++) ...[
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFE9E8EB),
                ),
                _VisitCard(
                  visit: today[index],
                  ledger: ledger,
                  valuesHidden: valuesHidden,
                  onComplete: () => onComplete(today[index]),
                  onPostpone: () => onPostpone(today[index]),
                  onRemove: () => onRemove(today[index]),
                  onOpenCustomer: () => onOpenCustomer(today[index]),
                ),
              ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: workspaceFontPrimary,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0E0D0F),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140E0D0F),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFE9E8EB),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.hidden,
    required this.onTap,
  });

  final RecentSale sale;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pending = sale.paymentStatus == PaymentStatus.pending;
    final colors = workspaceColorsOf(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: pending ? const Color(0xFFFFF4E5) : colors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Text(
                    sale.code.substring(sale.code.length - 2),
                    style: TextStyle(
                      fontSize: workspaceFontSecondary,
                      fontWeight: FontWeight.w700,
                      color: pending ? const Color(0xFFB45309) : colors.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: workspaceFontPrimary,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0E0D0F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paymentStatusLabel(sale.paymentStatus),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: workspaceFontSecondary,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatBrl(sale.amountCents, hidden: hidden),
              style: const TextStyle(
                fontSize: workspaceFontPrimary,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0E0D0F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    );
  }
}
