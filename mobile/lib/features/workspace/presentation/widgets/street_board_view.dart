import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../../core/config/api_config.dart';
import '../../../../injection_container.dart';
import '../../../customers/domain/repositories/customer_note_repository.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/month_board.dart';
import '../bloc/company_operation_bloc.dart';
import '../bloc/home_board_bloc.dart';
import '../home_board_mapping.dart';
import '../operation_labels.dart';
import '../theme/workspace_colors.dart';

class StreetBoardView extends StatefulWidget {
  const StreetBoardView({
    super.key,
    required this.valuesHidden,
    required this.onNewSale,
    required this.onOpenCustomer,
  });

  final bool valuesHidden;
  final VoidCallback onNewSale;
  final ValueChanged<String> onOpenCustomer;

  @override
  State<StreetBoardView> createState() => StreetBoardViewState();
}

class StreetBoardViewState extends State<StreetBoardView>
    with SingleTickerProviderStateMixin {
  final _routeKey = GlobalKey();
  late final AnimationController _entrance;
  late final ScrollController _scroll;
  List<UpcomingDueCustomer> _noteDues = const [];
  Set<String> _clearedNoteCustomers = const {};
  var _notesReady = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scroll = ScrollController();
    _loadNoteDues();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _loadNoteDues() async {
    if (!sl.isRegistered<CustomerNoteRepository>()) {
      if (mounted) setState(() => _notesReady = true);
      return;
    }
    final notesRepo = sl<CustomerNoteRepository>();
    final result = await notesRepo.draftNotesWithDue();
    final clearedResult = await notesRepo.clearedDraftCustomerIds();
    if (!mounted) return;
    if (result.isLeft()) {
      setState(() => _notesReady = true);
      return;
    }
    final items = result.getOrElse(() => const []);
    final cleared = clearedResult.getOrElse(() => const <String>{});
    final mapped = <UpcomingDueCustomer>[];
    for (final note in items) {
      if (note.dueOn == null || note.totalCents <= 0) continue;
      // Orphan / seed drafts without a real customer must not appear on home.
      if (!sl.isRegistered<CustomerRepository>()) continue;
      final found = await sl<CustomerRepository>().getCustomerById(
        note.customerId,
      );
      final name = found.fold<String?>(
        (_) => null,
        (customer) => customer.name.trim().isEmpty ? null : customer.name,
      );
      if (name == null) continue;
      mapped.add(
        UpcomingDueCustomer(
          customerId: note.customerId,
          customerName: name,
          dueOn: isoDate(note.dueOn!),
          amountCents: note.totalCents,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _noteDues = mapped;
      _clearedNoteCustomers = cleared;
      _notesReady = true;
    });
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
    if (ApiConfig.useRemoteApi) {
      return BlocConsumer<HomeBoardBloc, HomeBoardState>(
        listenWhen: (previous, current) =>
            previous.board != current.board ||
            previous.status != current.status,
        listener: (context, state) {
          if (state.status == HomeBoardStatus.ready) {
            setState(() => _notesReady = false);
            _loadNoteDues();
          }
        },
        builder: (context, state) {
          if (state.status == HomeBoardStatus.initial ||
              state.status == HomeBoardStatus.loading ||
              !_notesReady) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando a home',
              ),
            );
          }
          if (state.status == HomeBoardStatus.failure || state.board == null) {
            return _Message(
              message: state.message ?? 'Não foi possível carregar a home.',
              onRetry: () => context.read<HomeBoardBloc>().add(
                const HomeBoardRequested(),
              ),
            );
          }
          final board = state.board!;
          final sections = homeSectionsForLocalDay(
            board: board,
            localNotes: _noteDues,
            now: DateTime.now(),
            clearedCustomerIds: _clearedNoteCustomers,
          );
          return _boardBody(
            context: context,
            receipts: sections.receipts,
            tomorrowDues: sections.tomorrow,
            laterDues: sections.later,
          );
        },
      );
    }

    return BlocConsumer<CompanyOperationBloc, CompanyOperationState>(
      listenWhen: (previous, current) =>
          previous.operation?.postedSales != current.operation?.postedSales,
      listener: (context, state) => _loadNoteDues(),
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
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayIso = isoDate(todayStart);
        final tomorrowIso = isoDate(todayStart.add(const Duration(days: 1)));
        final receipts = dayReceipts(
          sales: operation.postedSales,
          notes: _noteDues,
          today: now,
        );
        final allUpcoming = [
          for (final due in upcomingDueCustomers(
            sales: operation.postedSales,
            notes: _noteDues,
            today: now,
          ))
            if (due.dueOn != todayIso) due,
        ];
        final tomorrowDues = [
          for (final due in allUpcoming)
            if (due.dueOn == tomorrowIso) due,
        ];
        final laterDues = [
          for (final due in allUpcoming)
            if (due.dueOn != tomorrowIso) due,
        ];
        return _boardBody(
          context: context,
          receipts: receipts,
          tomorrowDues: tomorrowDues,
          laterDues: laterDues,
        );
      },
    );
  }

  Widget _boardBody({
    required BuildContext context,
    required List<DayReceiptCustomer> receipts,
    required List<UpcomingDueCustomer> tomorrowDues,
    required List<UpcomingDueCustomer> laterDues,
  }) {
    final valuesHidden = widget.valuesHidden;
    final saleButton = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: pouInk,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final progress = dayReceiptProgress(receipts);
    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            bottom: 0,
            child: SingleChildScrollView(
              key: const Key('street_board_scroll'),
              controller: _scroll,
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 20,
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
                        _DayReceiptsBoard(
                          titleKey: _routeKey,
                          progress: progress,
                          receipts: receipts,
                          valuesHidden: valuesHidden,
                          onOpenCustomer: widget.onOpenCustomer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      rise(
                        FilledButton.icon(
                          key: const Key('action_new_sale'),
                          style: saleButton,
                          onPressed: widget.onNewSale,
                          icon: const Icon(
                            Icons.add_shopping_cart_outlined,
                            color: pouCanvas,
                          ),
                          label: const Text(
                            'Nova Venda',
                            style: TextStyle(color: pouCanvas),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      rise(
                        _TomorrowDuesSection(
                          tomorrow: todayStart.add(const Duration(days: 1)),
                          dues: tomorrowDues,
                          valuesHidden: valuesHidden,
                          onOpenCustomer: widget.onOpenCustomer,
                        ),
                      ),
                      const SizedBox(height: 28),
                      rise(
                        _LaterDuesSection(
                          today: todayStart,
                          dues: laterDues,
                          valuesHidden: valuesHidden,
                          onOpenCustomer: widget.onOpenCustomer,
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

class _DayReceiptsBoard extends StatelessWidget {
  const _DayReceiptsBoard({
    required this.titleKey,
    required this.progress,
    required this.receipts,
    required this.valuesHidden,
    required this.onOpenCustomer,
  });

  final Key titleKey;
  final VisitProgress progress;
  final List<DayReceiptCustomer> receipts;
  final bool valuesHidden;
  final ValueChanged<String> onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final colors = workspaceColorsOf(context);
    final fraction = progress.total == 0 ? 0.0 : progress.done / progress.total;
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
                          'Recebimentos do dia',
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
            if (receipts.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Nenhum recebimento com vencimento hoje.',
                  style: TextStyle(
                    fontSize: workspaceFontSecondary,
                    color: Color(0xFF6B7280),
                  ),
                ),
              )
            else
              for (var index = 0; index < receipts.length; index++) ...[
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFE9E8EB),
                ),
                _DayReceiptTile(
                  receipt: receipts[index],
                  valuesHidden: valuesHidden,
                  onOpenCustomer: () =>
                      onOpenCustomer(receipts[index].customerId),
                ),
              ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _DayReceiptTile extends StatelessWidget {
  const _DayReceiptTile({
    required this.receipt,
    required this.valuesHidden,
    required this.onOpenCustomer,
  });

  final DayReceiptCustomer receipt;
  final bool valuesHidden;
  final VoidCallback onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final done = receipt.done;
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _VisitCheck(done: done, onTap: done ? null : onOpenCustomer),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                key: Key('day_receipt_${receipt.customerId}'),
                onTap: onOpenCustomer,
                child: Text(
                  receipt.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: workspaceFontPrimary,
                    fontWeight: FontWeight.w700,
                    color: done
                        ? const Color(0xFF8B97C2)
                        : const Color(0xFF0E0D0F),
                    decoration: done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: const Color(0xFF8B97C2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatBrl(receipt.amountCents, hidden: valuesHidden),
              key: Key('day_receipt_amount_${receipt.customerId}'),
              style: TextStyle(
                fontSize: workspaceFontPrimary,
                fontWeight: FontWeight.w700,
                color: done ? const Color(0xFF8B97C2) : const Color(0xFF0E0D0F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _duesMuted = Color(0xFF8E8E93);
const _duesGreen = Color(0xFF1B7A45);
const _duesGreenSoft = Color(0xFFE5F6EC);
const _duesBadge = Color(0xFFF0F0F2);

const _monthShort = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

DateTime? _parseDueDay(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String _shortMonthDay(DateTime date) =>
    '${date.day} ${_monthShort[date.month - 1]}.';

String _monthDayLabel(DateTime date) {
  final month = monthNames[date.month - 1].toLowerCase();
  return '${date.day} de $month';
}

String _relativeDaysLabel(DateTime due, DateTime today) {
  final days = due.difference(today).inDays;
  if (days == 0) return 'Hoje';
  if (days == 1) return 'Amanhã';
  if (days == -1) return 'Ontem';
  if (days < -1) return 'Há ${-days} dias';
  return 'Em $days dias';
}

class _TomorrowDuesSection extends StatelessWidget {
  const _TomorrowDuesSection({
    required this.tomorrow,
    required this.dues,
    required this.valuesHidden,
    required this.onOpenCustomer,
  });

  final DateTime tomorrow;
  final List<UpcomingDueCustomer> dues;
  final bool valuesHidden;
  final ValueChanged<String> onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Amanhã',
                style: TextStyle(
                  color: Color(0xFF0E0D0F),
                  fontSize: workspaceFontPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _shortMonthDay(tomorrow),
              style: const TextStyle(
                color: _duesMuted,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (dues.isEmpty)
          const _TomorrowEmptyCard()
        else
          _DuesWhiteCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: Column(
                children: [
                  for (var index = 0; index < dues.length; index++) ...[
                    if (index > 0)
                      const Divider(height: 1, color: Color(0xFFE9E8EB)),
                    _DueCustomerRow(
                      due: dues[index],
                      hidden: valuesHidden,
                      noteLabel: '1 nota em aberto',
                      onTap: () => onOpenCustomer(dues[index].customerId),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TomorrowEmptyCard extends StatelessWidget {
  const _TomorrowEmptyCard();

  @override
  Widget build(BuildContext context) {
    return _DuesWhiteCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _duesGreenSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: _duesGreen,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tudo em dia',
                    style: TextStyle(
                      color: Color(0xFF0E0D0F),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Nenhuma cobrança para amanhã.',
                    style: TextStyle(
                      color: _duesMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaterDuesSection extends StatelessWidget {
  const _LaterDuesSection({
    required this.today,
    required this.dues,
    required this.valuesHidden,
    required this.onOpenCustomer,
  });

  final DateTime today;
  final List<UpcomingDueCustomer> dues;
  final bool valuesHidden;
  final ValueChanged<String> onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<UpcomingDueCustomer>>{};
    for (final due in dues) {
      groups.putIfAbsent(due.dueOn, () => []).add(due);
    }
    final orderedDays = groups.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Próximos vencimentos',
          style: TextStyle(
            color: Color(0xFF0E0D0F),
            fontSize: workspaceFontPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        if (dues.isEmpty)
          const Text(
            'Nenhuma nota próxima do vencimento.',
            style: TextStyle(
              color: _duesMuted,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          )
        else
          for (var dayIndex = 0; dayIndex < orderedDays.length; dayIndex++) ...[
            if (dayIndex > 0) const SizedBox(height: 14),
            _LaterDueDayCard(
              dueOn: orderedDays[dayIndex],
              today: today,
              dues: groups[orderedDays[dayIndex]]!,
              valuesHidden: valuesHidden,
              onOpenCustomer: onOpenCustomer,
            ),
          ],
      ],
    );
  }
}

class _LaterDueDayCard extends StatelessWidget {
  const _LaterDueDayCard({
    required this.dueOn,
    required this.today,
    required this.dues,
    required this.valuesHidden,
    required this.onOpenCustomer,
  });

  final String dueOn;
  final DateTime today;
  final List<UpcomingDueCustomer> dues;
  final bool valuesHidden;
  final ValueChanged<String> onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final day = _parseDueDay(dueOn) ?? today;
    final total = dues.fold<int>(0, (sum, item) => sum + item.amountCents);
    return _DuesWhiteCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _monthDayLabel(day),
                    style: const TextStyle(
                      color: _duesMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _duesBadge,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _relativeDaysLabel(day, today),
                    style: const TextStyle(
                      color: Color(0xFF5C5C62),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (var index = 0; index < dues.length; index++) ...[
              if (index > 0) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE9E8EB)),
                const SizedBox(height: 16),
              ],
              _DueCustomerRow(
                due: dues[index],
                hidden: valuesHidden,
                noteLabel: '1 nota em aberto',
                onTap: () => onOpenCustomer(dues[index].customerId),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE9E8EB)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total previsto',
                    style: TextStyle(
                      color: _duesMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  formatBrl(total, hidden: valuesHidden),
                  style: const TextStyle(
                    color: Color(0xFF0E0D0F),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DueCustomerRow extends StatelessWidget {
  const _DueCustomerRow({
    required this.due,
    required this.hidden,
    required this.noteLabel,
    required this.onTap,
  });

  final UpcomingDueCustomer due;
  final bool hidden;
  final String noteLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('upcoming_due_${due.customerId}_${due.dueOn}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  due.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0E0D0F),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  noteLabel,
                  style: const TextStyle(
                    color: _duesMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatBrl(due.amountCents, hidden: hidden),
                style: const TextStyle(
                  color: Color(0xFF0E0D0F),
                  fontSize: workspaceFontPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'A receber',
                style: TextStyle(
                  color: _duesMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFC7C7CC),
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _DuesWhiteCard extends StatelessWidget {
  const _DuesWhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: child,
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
