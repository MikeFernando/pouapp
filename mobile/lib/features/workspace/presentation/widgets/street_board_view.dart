import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/api_config.dart';
import '../../../../injection_container.dart';
import '../../../customers/domain/entities/customer_note.dart';
import '../../../customers/domain/repositories/customer_note_repository.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../data/day_checklist_store.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/month_board.dart';
import '../bloc/company_operation_bloc.dart';
import '../bloc/home_board_bloc.dart';
import '../home_board_mapping.dart';
import '../operation_labels.dart';
import '../theme/workspace_colors.dart';
import 'day_receipts_card.dart';
import 'overdue_receipts_card.dart';
import 'upcoming_month_dues_card.dart';

class StreetBoardView extends StatefulWidget {
  const StreetBoardView({
    super.key,
    required this.valuesHidden,
    required this.onOpenCustomer,
    this.onChecklistChanged,
  });

  final bool valuesHidden;
  final ValueChanged<String> onOpenCustomer;
  final ValueChanged<DayChecklistSnapshot>? onChecklistChanged;

  @override
  State<StreetBoardView> createState() => StreetBoardViewState();
}

class StreetBoardViewState extends State<StreetBoardView>
    with SingleTickerProviderStateMixin {
  final _routeKey = GlobalKey();
  late final AnimationController _entrance;
  late final ScrollController _scroll;
  List<UpcomingDueCustomer> _noteDues = const [];
  Map<String, List<NoteLine>> _noteLinesByCustomer = const {};
  Set<String> _clearedNoteCustomers = const {};
  var _notesReady = false;
  final _servedCustomerIds = <String>{};
  var _dayReceiptsExpanded = false;
  var _overdueExpanded = false;
  var _upcomingExpanded = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scroll = ScrollController();
    _restoreServedChecklist();
    _loadNoteDues();
  }

  void _restoreServedChecklist() {
    if (!sl.isRegistered<DayChecklistStore>()) return;
    final stored = sl<DayChecklistStore>().loadServed(DateTime.now());
    if (stored.isEmpty) return;
    _servedCustomerIds
      ..clear()
      ..addAll(stored);
  }

  Future<void> _persistServedChecklist() async {
    if (!sl.isRegistered<DayChecklistStore>()) return;
    await sl<DayChecklistStore>().saveServed(
      DateTime.now(),
      _servedCustomerIds,
    );
  }

  void _toggleServedCustomer(String customerId) {
    setState(() {
      if (!_servedCustomerIds.add(customerId)) {
        _servedCustomerIds.remove(customerId);
      }
    });
    _persistServedChecklist();
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
    final linesByCustomer = <String, List<NoteLine>>{};
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
      linesByCustomer[note.customerId] = List.of(note.lines);
    }
    if (!mounted) return;
    setState(() {
      _noteDues = mapped;
      _noteLinesByCustomer = linesByCustomer;
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
            overdueDues: sections.overdue,
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
        final overdueDues = [
          for (final due in allUpcoming)
            if (due.dueOn.compareTo(todayIso) < 0) due,
        ];
        final tomorrowDues = [
          for (final due in allUpcoming)
            if (due.dueOn == tomorrowIso) due,
        ];
        final laterDues = [
          for (final due in allUpcoming)
            if (due.dueOn.compareTo(tomorrowIso) > 0) due,
        ];
        return _boardBody(
          context: context,
          receipts: receipts,
          overdueDues: overdueDues,
          tomorrowDues: tomorrowDues,
          laterDues: laterDues,
        );
      },
    );
  }

  Widget _boardBody({
    required BuildContext context,
    required List<DayReceiptCustomer> receipts,
    required List<UpcomingDueCustomer> overdueDues,
    required List<UpcomingDueCustomer> tomorrowDues,
    required List<UpcomingDueCustomer> laterDues,
  }) {
    final valuesHidden = widget.valuesHidden;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final progress = dayReceiptProgress(receipts);
    final monthPrefix =
        '${todayStart.year}-${todayStart.month.toString().padLeft(2, '0')}';
    final upcomingMonthDues = [
      ...tomorrowDues,
      for (final due in laterDues)
        if (due.dueOn.startsWith(monthPrefix)) due,
    ]..sort((a, b) {
        final byDate = a.dueOn.compareTo(b.dueOn);
        if (byDate != 0) return byDate;
        return a.customerName.compareTo(b.customerName);
      });
    final beyondMonthDues = [
      for (final due in laterDues)
        if (!due.dueOn.startsWith(monthPrefix)) due,
    ];
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
                        DayReceiptsCard(
                          titleKey: _routeKey,
                          progress: progress,
                          receipts: receipts,
                          valuesHidden: valuesHidden,
                          servedCustomerIds: Set.unmodifiable(
                            _servedCustomerIds,
                          ),
                          onToggleServed: _toggleServedCustomer,
                          expanded: _dayReceiptsExpanded,
                          onExpandedChanged: (value) {
                            setState(() => _dayReceiptsExpanded = value);
                          },
                          noteLinesByCustomer: _noteLinesByCustomer,
                          onOpenCustomer: widget.onOpenCustomer,
                          onChecklistChanged: widget.onChecklistChanged,
                        ),
                      ),
                      const SizedBox(height: 16),
                      rise(
                        OverdueReceiptsCard(
                          dues: overdueDues,
                          valuesHidden: valuesHidden,
                          onOpenCustomer: widget.onOpenCustomer,
                          expanded: _overdueExpanded,
                          onExpandedChanged: (value) {
                            setState(() => _overdueExpanded = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      rise(
                        UpcomingMonthDuesCard(
                          dues: upcomingMonthDues,
                          valuesHidden: valuesHidden,
                          onOpenCustomer: widget.onOpenCustomer,
                          expanded: _upcomingExpanded,
                          onExpandedChanged: (value) {
                            setState(() => _upcomingExpanded = value);
                          },
                        ),
                      ),
                      if (beyondMonthDues.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        rise(
                          _LaterDuesSection(
                            today: todayStart,
                            dues: beyondMonthDues,
                            valuesHidden: valuesHidden,
                            onOpenCustomer: widget.onOpenCustomer,
                          ),
                        ),
                      ],
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

const _duesMuted = Color(0xFF8E8E93);
const _duesBadge = Color(0xFFF0F0F2);

DateTime? _parseDueDay(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

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
          'Depois deste mês',
          style: TextStyle(
            color: Color(0xFF0E0D0F),
            fontSize: workspaceFontPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
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
