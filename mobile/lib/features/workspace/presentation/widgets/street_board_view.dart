import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/api_config.dart';
import '../../../../injection_container.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../../customers/data/datasources/customer_local_data_source.dart';
import '../../../customers/domain/entities/customer_note.dart';
import '../../../customers/domain/repositories/customer_note_repository.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../data/day_checklist_store.dart';
import '../../data/home_board_cache.dart';
import '../../data/home_board_seed.dart';
import '../../data/receivable_store.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/month_board.dart';
import '../../domain/usecases/home_use_cases.dart';
import '../bloc/company_operation_bloc.dart';
import '../bloc/home_board_bloc.dart';
import '../home_board_mapping.dart';
import '../top_billed_products.dart';
import 'day_receipts_card.dart';
import 'home_top_products.dart';
import 'overdue_receipts_card.dart';
import 'upcoming_month_dues_card.dart';

class StreetBoardView extends StatefulWidget {
  const StreetBoardView({
    super.key,
    required this.valuesHidden,
    required this.onOpenCustomer,
    required this.onNewSale,
    this.onChecklistChanged,
    this.checklistProductCents = const {},
  });

  final bool valuesHidden;
  final ValueChanged<String> onOpenCustomer;
  final VoidCallback onNewSale;
  final ValueChanged<DayChecklistSnapshot>? onChecklistChanged;
  final Map<String, int> checklistProductCents;

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
  final _frozenByCustomer = <String, DayChecklistFrozen>{};
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
    final store = sl<DayChecklistStore>();
    final now = DateTime.now();
    final stored = store.loadServed(now);
    final frozen = store.loadFrozen(now);
    _servedCustomerIds
      ..clear()
      ..addAll(stored);
    _frozenByCustomer
      ..clear()
      ..addAll(frozen);
  }

  Future<void> _seedHomeDuesIfNeeded() async {
    if (!sl.isRegistered<CustomerRepository>() ||
        !sl.isRegistered<CustomerLocalDataSource>() ||
        !sl.isRegistered<CustomerNoteRepository>() ||
        !sl.isRegistered<SharedPreferences>()) {
      return;
    }
    final seeded = await seedHomeBoardDuesIfNeeded(
      customers: sl(),
      localCustomers: sl(),
      notes: sl(),
      prefs: sl(),
      createHomeNote: sl.isRegistered<CreateHomeNote>() ? sl() : null,
      clearHomeNote: sl.isRegistered<ClearHomeNote>() ? sl() : null,
    );
    if (seeded &&
        ApiConfig.useRemoteApi &&
        mounted &&
        sl.isRegistered<HomeBoardBloc>()) {
      sl<HomeBoardBloc>().add(const HomeBoardRequested());
    }
  }

  Future<void> _persistServedChecklist() async {
    if (!sl.isRegistered<DayChecklistStore>()) return;
    final store = sl<DayChecklistStore>();
    final now = DateTime.now();
    await store.saveServed(now, _servedCustomerIds);
    await store.saveFrozen(now, _frozenByCustomer);
  }

  void _toggleServedCustomer(String customerId, DayChecklistFrozen? entry) {
    setState(() {
      if (_servedCustomerIds.contains(customerId)) {
        _servedCustomerIds.remove(customerId);
        _frozenByCustomer.remove(customerId);
      } else {
        _servedCustomerIds.add(customerId);
        if (entry != null) {
          _frozenByCustomer[customerId] = entry;
        }
      }
    });
    _persistServedChecklist();
  }

  Future<void> _openCustomer(
    String customerId, {
    UpcomingDueCustomer? overdueSeed,
  }) async {
    if (overdueSeed != null) {
      await _hydrateOverdueDraft(overdueSeed);
    }
    if (!mounted) return;
    widget.onOpenCustomer(customerId);
  }

  /// Fills an empty draft with the overdue due date and open balance lines.
  Future<void> _hydrateOverdueDraft(UpcomingDueCustomer seed) async {
    if (!sl.isRegistered<CustomerNoteRepository>()) return;
    if (seed.amountCents <= 0 || seed.dueOn.trim().isEmpty) return;
    final repo = sl<CustomerNoteRepository>();
    final opened = await repo.openNote(seed.customerId);
    final note = opened.fold<CustomerNote?>((_) => null, (value) => value);
    if (note == null || note.status != NoteStatus.draft) return;

    var working = note;
    if (working.dueOn == null) {
      final due = DateTime.tryParse(seed.dueOn);
      if (due != null) {
        final saved = await repo.setDueOn(
          noteId: working.id,
          dueOn: DateTime(due.year, due.month, due.day),
        );
        working = saved.fold((_) => working, (value) => value);
      }
    }

    if (working.lines.isNotEmpty || working.totalCents > 0) return;

    final drafts = <NoteLineDraft>[];
    if (sl.isRegistered<ReceivableStore>()) {
      final today = isoDate(DateTime.now());
      final account = await sl<ReceivableStore>().account(seed.customerId);
      for (final item in account.openReceivables) {
        if (item.openCents <= 0) continue;
        final dueOn = item.dueOn;
        if (dueOn == null || dueOn.compareTo(today) >= 0) continue;
        final name = item.description.trim().isEmpty
            ? 'Saldo em atraso'
            : item.description.trim();
        drafts.add(
          NoteLineDraft(
            name: name,
            unit: CatalogUnit.piece,
            quantity: 1,
            unitPriceCents: item.openCents,
          ),
        );
      }
    }
    if (drafts.isEmpty) {
      drafts.add(
        NoteLineDraft(
          name: 'Saldo em atraso',
          unit: CatalogUnit.piece,
          quantity: 1,
          unitPriceCents: seed.amountCents,
        ),
      );
    }
    await repo.saveLines(noteId: working.id, lines: drafts);
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
    // Paint from SQLite first — seed/API never block the home spinner.
    final notesRepo = sl<CustomerNoteRepository>();
    final result = await notesRepo.draftNotesWithDue();
    final clearedResult = await notesRepo.clearedDraftCustomerIds();
    if (!mounted) return;
    if (result.isLeft()) {
      setState(() => _notesReady = true);
      unawaited(_seedHomeDuesIfNeeded());
      return;
    }
    final items = result.getOrElse(() => const []);
    final cleared = clearedResult.getOrElse(() => const <String>{});
    final mapped = <UpcomingDueCustomer>[];
    final linesByCustomer = <String, List<NoteLine>>{};
    final localCustomers = sl.isRegistered<CustomerLocalDataSource>()
        ? sl<CustomerLocalDataSource>()
        : null;
    for (final note in items) {
      if (note.dueOn == null || note.totalCents <= 0) continue;
      // Local lookup only — never wait on the network to open home.
      String? name;
      if (localCustomers != null) {
        try {
          final customer = await localCustomers.getCustomerById(
            note.customerId,
          );
          final trimmed = customer.name.trim();
          if (trimmed.isNotEmpty) name = trimmed;
        } catch (_) {
          name = null;
        }
      } else if (sl.isRegistered<CustomerRepository>()) {
        final found = await sl<CustomerRepository>().getCustomerById(
          note.customerId,
        );
        name = found.fold<String?>(
          (_) => null,
          (customer) => customer.name.trim().isEmpty ? null : customer.name,
        );
      }
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
    unawaited(_seedHomeDuesIfNeeded());
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
            // Refresh local dues in place — don't blank the home with a spinner.
            _loadNoteDues();
          }
        },
        builder: (context, state) {
          // Wait only for local SQLite notes — never for API / seed.
          if (!_notesReady) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando a home',
              ),
            );
          }
          final board = state.board ?? emptyHomeBoard();
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
    final operation = context.watch<CompanyOperationBloc>().state.operation;
    final topProducts = topBilledProducts(
      orders: operation?.street.orders ?? const [],
      checklistProductCents: widget.checklistProductCents,
      now: now,
    );
    final monthPrefix =
        '${todayStart.year}-${todayStart.month.toString().padLeft(2, '0')}';
    final upcomingMonthDues =
        [
          ...tomorrowDues,
          for (final due in laterDues)
            if (due.dueOn.startsWith(monthPrefix)) due,
        ]..sort((a, b) {
          final byDate = a.dueOn.compareTo(b.dueOn);
          if (byDate != 0) return byDate;
          return a.customerName.compareTo(b.customerName);
        });
    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            top: 16,
            left: 0,
            right: 0,
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
                      if (topProducts.isNotEmpty) ...[
                        rise(
                          HomeTopProducts(
                            products: topProducts,
                            valuesHidden: valuesHidden,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      rise(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: DayReceiptsCard(
                            titleKey: _routeKey,
                            progress: progress,
                            receipts: receipts,
                            valuesHidden: valuesHidden,
                            servedCustomerIds: Set.unmodifiable(
                              _servedCustomerIds,
                            ),
                            frozenByCustomer: Map.unmodifiable(
                              _frozenByCustomer,
                            ),
                            onToggleServed: _toggleServedCustomer,
                            expanded: _dayReceiptsExpanded,
                            onExpandedChanged: (value) {
                              setState(() => _dayReceiptsExpanded = value);
                            },
                            noteLinesByCustomer: _noteLinesByCustomer,
                            onOpenCustomer: (id) => _openCustomer(id),
                            onChecklistChanged: widget.onChecklistChanged,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      rise(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _NovaVendaButton(onPressed: widget.onNewSale),
                        ),
                      ),
                      const SizedBox(height: 16),
                      rise(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: OverdueReceiptsCard(
                            dues: overdueDues,
                            valuesHidden: valuesHidden,
                            onOpenCustomer: (id) {
                              UpcomingDueCustomer? seed;
                              for (final due in overdueDues) {
                                if (due.customerId == id) {
                                  seed = due;
                                  break;
                                }
                              }
                              _openCustomer(id, overdueSeed: seed);
                            },
                            expanded: _overdueExpanded,
                            onExpandedChanged: (value) {
                              setState(() => _overdueExpanded = value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      rise(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: UpcomingMonthDuesCard(
                            dues: upcomingMonthDues,
                            valuesHidden: valuesHidden,
                            onOpenCustomer: (id) => _openCustomer(id),
                            expanded: _upcomingExpanded,
                            onExpandedChanged: (value) {
                              setState(() => _upcomingExpanded = value);
                            },
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
  }
}

class _NovaVendaButton extends StatelessWidget {
  const _NovaVendaButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _radius = 14.0;
  static const _forest = Color(0xFF062E0C);
  static const _height = 52.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Nova Venda',
      child: Material(
        color: _forest,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('action_new_sale'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_radius),
          child: SizedBox(
            width: double.infinity,
            height: _height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/nova-venda-fundo-botanico.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stackTrace) {
                    return const ColoredBox(color: _forest);
                  },
                ),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NovaVendaCart(),
                      SizedBox(width: 8),
                      Text(
                        'Nova Venda',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NovaVendaCart extends StatelessWidget {
  const _NovaVendaCart();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/carrinho-botanico.png',
      width: 24,
      height: 24,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
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
