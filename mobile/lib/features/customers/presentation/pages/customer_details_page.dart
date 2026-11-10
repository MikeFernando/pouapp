import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../../app/pou_item_edit_sheet.dart';
import '../../../../injection_container.dart' as di;
import '../../../assistant/presentation/voice_attendance.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../../catalog/presentation/produce_assets.dart';
import '../../../workspace/domain/entities/stock_board.dart';
import '../../../workspace/domain/entities/street_ledger.dart';
import '../../../workspace/presentation/bloc/company_operation_bloc.dart';
import '../../../workspace/presentation/loaded_operation.dart';
import '../../../workspace/presentation/operation_labels.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_note.dart';
import '../../domain/repositories/customer_note_repository.dart';
import '../../domain/rules/note_rules.dart';
import '../../domain/validation/customer_validators.dart';
import '../bloc/customer_details_bloc.dart';
import '../whatsapp_launch.dart';
import '../widgets/customer_account_section.dart';

String? whatsAppPhoneDigits(Customer customer) {
  final raw = onlyDigits(
    (customer.mobilePhone ?? '').trim().isNotEmpty
        ? customer.mobilePhone
        : customer.phone,
  );
  final national = raw.replaceFirst(RegExp(r'^0+'), '');
  if (national.isEmpty) return null;
  if (national.startsWith('55') && national.length > 11) return national;
  return '55$national';
}

CatalogUnit _catalogUnit(StockUnit unit) {
  return switch (unit) {
    StockUnit.kilogram => CatalogUnit.kilogram,
    StockUnit.piece => CatalogUnit.piece,
    StockUnit.bunch => CatalogUnit.bunch,
    StockUnit.box => CatalogUnit.box,
    StockUnit.dozen => CatalogUnit.dozen,
  };
}

class CustomerDetailsPage extends StatelessWidget {
  const CustomerDetailsPage({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              di.sl<CustomerDetailsBloc>()
                ..add(CustomerDetailsRequested(customerId)),
        ),
        BlocProvider.value(value: loadedCompanyOperation()),
      ],
      child: CustomerDetailsView(customerId: customerId),
    );
  }
}

class CustomerDetailsView extends StatefulWidget {
  const CustomerDetailsView({super.key, this.openWhatsApp, this.customerId});

  final Future<bool> Function(String digits)? openWhatsApp;
  final String? customerId;

  @override
  State<CustomerDetailsView> createState() => _CustomerDetailsViewState();
}

class _CustomerDetailsViewState extends State<CustomerDetailsView> {
  CustomerNote? _note;
  String? _noteError;
  var _noteRequestedFor = '';
  var _memoryLine = 0;
  VoiceVisit? _visit;

  @override
  void dispose() {
    final visit = _visit;
    if (visit != null) VoiceAttendance.unmount(visit);
    super.dispose();
  }

  void _rememberVisit(String id, String label) {
    final next = VoiceVisit(
      customerId: id,
      label: label,
      onChanged: () {
        _noteRequestedFor = '';
        _requestNote(id);
      },
    );
    final current = _visit;
    if (current == null) {
      VoiceAttendance.mount(next);
    } else if (current.customerId != id || current.label != label) {
      VoiceAttendance.replace(current, next);
    } else {
      return;
    }
    _visit = next;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerDetailsBloc, CustomerDetailsState>(
      builder: (context, state) {
        final customer = state.customer;
        final visitId = widget.customerId ?? customer?.id;
        if (visitId != null && visitId.isNotEmpty) {
          _rememberVisit(visitId, customer?.name ?? '');
        }
        final waiting =
            state.status == CustomerDetailsStatus.loading ||
            state.status == CustomerDetailsStatus.initial ||
            (customer == null && state.status != CustomerDetailsStatus.failure);
        if (waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando cliente',
              ),
            ),
          );
        }
        if (customer == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: pouAppBlue, foregroundColor: pouCanvas, title: const Text('Cliente')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.message ?? 'Cliente não encontrado.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        _requestNote(customer.id);
        final note = _note;
        final sales = context.watch<CompanyOperationBloc>().state;
        final operation = sales.operation;
        final loadingSales =
            operation == null &&
            (sales.status == BoardStatus.initial ||
                sales.status == BoardStatus.loading);
        final ledger = operation?.street;
        return Scaffold(
          backgroundColor: pouAppBlue,
          appBar: AppBar(
            backgroundColor: pouAppBlue,
            foregroundColor: pouCanvas,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            title: Text(customer.name),
          ),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
            child: ColoredBox(
              color: const Color(0xFFF6F5F7),
              child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 88),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SituationBar(
                        delivered: note?.status == NoteStatus.delivered,
                      ),
                      _DueDateCard(
                        date: note?.dueOn,
                        onPick: note?.status == NoteStatus.delivered
                            ? null
                            : _openDueDate,
                      ),
                      if (note?.status == NoteStatus.delivered) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            'Entrega confirmada. Correções desta nota ficam para a etapa própria.',
                            key: Key('delivery_locked'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: OutlinedButton(
                            key: const Key('new_purchase'),
                            style: noteSecondaryButton(),
                            onPressed: () => _newPurchase(customer.id),
                            child: const Text('Nova compra'),
                          ),
                        ),
                      ],
                      if (_noteError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            _noteError!,
                            key: const Key('note_save_error'),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFC62828),
                            ),
                          ),
                        ),
                      if (loadingSales)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(
                              semanticsLabel: 'Carregando vendas',
                            ),
                          ),
                        )
                      else if (ledger == null)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            sales.message ??
                                'Não foi possível carregar as vendas.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        _SalesList(
                          customer: customer,
                          ledger: ledger,
                          lines: note?.lines ?? const [],
                          ready: note != null,
                          onWhatsApp: () => _openWhatsApp(customer),
                          onAdd:
                              note == null ||
                                  note.status == NoteStatus.delivered
                              ? null
                              : _addLine,
                          onEdit: note?.status == NoteStatus.delivered
                              ? null
                              : _editLine,
                        ),
                      CustomerAccountSection(customer: customer),
                    ],
                  ),
                ),
              );
            },
              ),
            ),
          ),
        );
      },
    );
  }

  void _requestNote(String customerId) {
    if (_noteRequestedFor == customerId) return;
    _noteRequestedFor = customerId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNote(customerId);
    });
  }

  Future<void> _loadNote(String customerId) async {
    if (!di.sl.isRegistered<CustomerNoteRepository>()) {
      final now = DateTime.now();
      setState(() {
        _noteError = null;
        _note = CustomerNote(
          id: 'memory-$customerId',
          customerId: customerId,
          status: NoteStatus.draft,
          createdAt: now,
          updatedAt: now,
          lines: const [],
        );
      });
      return;
    }
    final result = await di.sl<CustomerNoteRepository>().openNote(customerId);
    if (!mounted || _noteRequestedFor != customerId) return;
    result.fold(_rememberFailure, (note) {
      setState(() {
        _noteError = null;
        _note = note;
      });
    });
  }

  Future<void> _newPurchase(String customerId) async {
    if (!di.sl.isRegistered<CustomerNoteRepository>()) return;
    await di.sl<CustomerNoteRepository>().activeDraft(customerId);
    if (!mounted) return;
    _noteRequestedFor = '';
    _requestNote(customerId);
  }

  Future<void> _openDueDate() async {
    final note = _note;
    if (note == null || note.status == NoteStatus.delivered) return;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6F5F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) =>
          _DueDateSheet(initial: note.dueOn ?? DateTime.now()),
    );
    if (picked == null || !mounted) return;
    final dueOn = DateTime(picked.year, picked.month, picked.day);
    if (!di.sl.isRegistered<CustomerNoteRepository>()) {
      setState(() => _note = note.copyWith(dueOn: dueOn));
      return;
    }
    final result = await di.sl<CustomerNoteRepository>().setDueOn(
      noteId: note.id,
      dueOn: dueOn,
    );
    if (!mounted) return;
    result.fold(_rememberFailure, (saved) {
      setState(() {
        _noteError = null;
        _note = saved;
      });
    });
  }

  Future<void> _editLine(int index) async {
    final note = _note;
    if (note == null || note.status == NoteStatus.delivered) return;
    final line = note.lines[index];
    final result = await showPouItemEditSheet(
      context,
      name: line.name,
      quantity: displayQuantity(line.unit, line.quantity),
      unitPriceCents: line.unitPriceCents,
      referencePriceCents: line.referencePriceCents,
      allowRemove: true,
      removeMessage: 'Remover ${line.name} desta nota?',
      removeButtonKey: const Key('remove_note_item'),
      confirmRemoveKey: const Key('confirm_remove_note_item'),
    );
    if (result == null || !mounted) return;
    if (result.removed) {
      await _persistLines([
        for (var position = 0; position < note.lines.length; position++)
          if (position != index) NoteLineDraft.fromLine(note.lines[position]),
      ]);
      return;
    }
    final quantity = baseQuantityFromDisplay(line.unit, result.quantity);
    if (quantity == null) {
      _rememberFailure(null);
      return;
    }
    await _persistLines([
      for (var position = 0; position < note.lines.length; position++)
        if (position == index)
          NoteLineDraft(
            id: line.id,
            productId: line.productId,
            name: line.name,
            unit: line.unit,
            quantity: quantity,
            // Practiced price on this note only. Catalog reference stays.
            unitPriceCents: result.unitPriceCents,
            referencePriceCents: line.referencePriceCents,
          )
        else
          NoteLineDraft.fromLine(note.lines[position]),
    ]);
  }

  Future<void> _addLine() async {
    final note = _note;
    if (note == null || note.status == NoteStatus.delivered) return;
    final products =
        context.read<CompanyOperationBloc>().state.operation?.products ??
        const <StockProduct>[];
    final media = MediaQuery.of(context);
    final sheetHeight =
        media.size.height - media.padding.top - kToolbarHeight;
    final picked = await showModalBottomSheet<_CatalogSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: const Color(0xFFF6F5F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: sheetHeight,
        child: _ProductCatalogPage(products: products),
      ),
    );
    if (picked == null || !mounted) return;
    final unit = _catalogUnit(picked.row.product.unit);
    final quantity = baseQuantityFromDisplay(unit, picked.quantity);
    if (quantity == null) {
      _rememberFailure(null);
      return;
    }
    await _persistLines([
      for (final line in note.lines) NoteLineDraft.fromLine(line),
      NoteLineDraft(
        productId: picked.row.product.id,
        name: picked.row.product.name,
        unit: unit,
        quantity: quantity,
        unitPriceCents: picked.unitPriceCents,
        referencePriceCents: picked.row.priceCents,
      ),
    ]);
  }

  Future<void> _persistLines(List<NoteLineDraft> drafts) async {
    final note = _note;
    if (note == null) return;
    if (!di.sl.isRegistered<CustomerNoteRepository>()) {
      setState(() {
        _noteError = null;
        _note = note.copyWith(
          updatedAt: DateTime.now(),
          lines: [
            for (final draft in drafts)
              NoteLine(
                id: draft.id ?? 'memory-${_memoryLine++}',
                productId: draft.productId,
                name: draft.name.trim(),
                unit: draft.unit,
                quantity: draft.quantity,
                unitPriceCents: draft.unitPriceCents,
                referencePriceCents: draft.referencePriceCents,
              ),
          ],
        );
      });
      return;
    }
    final result = await di.sl<CustomerNoteRepository>().saveLines(
      noteId: note.id,
      lines: drafts,
    );
    if (!mounted) return;
    result.fold(_rememberFailure, (saved) {
      setState(() {
        _noteError = null;
        _note = saved;
      });
    });
  }

  void _rememberFailure(Object? _) {
    setState(() => _noteError = 'Não foi possível gravar a nota.');
  }

  Future<void> _openWhatsApp(Customer customer) async {
    final digits = whatsAppPhoneDigits(customer);
    if (digits == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta cliente não tem telefone.')),
      );
      return;
    }
    final open = widget.openWhatsApp ?? launchCustomerWhatsApp;
    final opened = await open(digits);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }
}

class _SituationBar extends StatelessWidget {
  const _SituationBar({required this.delivered});

  final bool delivered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          key: const Key('customer_situation'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Situação',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E0D0F),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: delivered
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF4CC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    delivered ? 'Entregue' : 'Rascunho',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: delivered
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF8A6A2F),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueDateCard extends StatelessWidget {
  const _DueDateCard({required this.date, required this.onPick});

  final DateTime? date;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vencimento',
                      style: TextStyle(fontSize: 16, color: Color(0xFF0E0D0F)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date == null ? 'Sem vencimento' : formatDay(date!),
                      key: const Key('customer_due_date'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0E0D0F),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('due_calendar'),
                onPressed: onPick,
                icon: const Icon(
                  Icons.calendar_today_outlined,
                  color: pouAppBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueDateSheet extends StatefulWidget {
  const _DueDateSheet({required this.initial});

  final DateTime initial;

  @override
  State<_DueDateSheet> createState() => _DueDateSheetState();
}

class _DueDateSheetState extends State<_DueDateSheet> {
  late DateTime _selected = DateTime(
    widget.initial.year,
    widget.initial.month,
    widget.initial.day,
  );
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

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

  @override
  Widget build(BuildContext context) {
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month).weekday % 7;
    final rows = ((leading + days) / 7).ceil();
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
                child: Column(
                  children: [
                    const Text(
                      'Escolha a data de vencimento',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0E0D0F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          key: const Key('due_prev_month'),
                          onPressed: () => setState(() {
                            _month = DateTime(_month.year, _month.month - 1);
                          }),
                          icon: const Icon(
                            Icons.chevron_left,
                            color: pouAppBlue,
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _months[_month.month - 1],
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF0E0D0F),
                                ),
                              ),
                              const SizedBox(width: 28),
                              Text(
                                '${_month.year}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF0E0D0F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const Key('due_next_month'),
                          onPressed: () => setState(() {
                            _month = DateTime(_month.year, _month.month + 1);
                          }),
                          icon: const Icon(
                            Icons.chevron_right,
                            color: pouAppBlue,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          for (final label in [
                            'D',
                            'S',
                            'T',
                            'Q',
                            'Q',
                            'S',
                            'S',
                          ])
                            Expanded(
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var row = 0; row < rows; row++)
                      Row(
                        children: [
                          for (var column = 0; column < 7; column++)
                            Expanded(
                              child: _dayCell(
                                row * 7 + column - leading + 1,
                                days,
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Você escolheu',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${_selected.day} de ${_months[_selected.month - 1]} de ${_selected.year}',
                          key: const Key('due_chosen'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E0D0F),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: FilledButton(
                key: const Key('due_confirm'),
                onPressed: () => Navigator.of(context).pop(_selected),
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
      return const SizedBox(height: 40);
    }
    final date = DateTime(_month.year, _month.month, day);
    final selected = _sameDay(date, _selected);
    final today = _sameDay(date, DateTime.now());
    return SizedBox(
      height: 40,
      child: InkWell(
        key: Key('due_day_$day'),
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _selected = date),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? pouAppBlue
                  : today
                  ? const Color(0xFFE9E8EB)
                  : null,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF6B7280),
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

class _SalesList extends StatelessWidget {
  const _SalesList({
    required this.customer,
    required this.ledger,
    required this.lines,
    required this.ready,
    required this.onWhatsApp,
    required this.onAdd,
    required this.onEdit,
  });

  final Customer customer;
  final StreetLedger ledger;
  final List<NoteLine> lines;
  final bool ready;
  final VoidCallback onWhatsApp;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onEdit;

  @override
  Widget build(BuildContext context) {
    final orders = [
      for (final order in ledger.orders)
        if (order.customerId == customer.id && order.recorded) order,
    ]..sort((a, b) => b.code.compareTo(a.code));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DraftItemsCard(
            lines: lines,
            ready: ready,
            onAdd: onAdd,
            onEdit: onEdit,
          ),
          if (orders.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Nenhuma venda desta cliente.',
              key: Key('customer_sales_empty'),
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ] else
            for (final order in orders)
              _SaleCard(
                customer: customer,
                ledger: ledger,
                order: order,
                onWhatsApp: onWhatsApp,
              ),
        ],
      ),
    );
  }
}

class _DraftItemsCard extends StatefulWidget {
  const _DraftItemsCard({
    required this.lines,
    required this.ready,
    required this.onAdd,
    required this.onEdit,
  });

  final List<NoteLine> lines;
  final bool ready;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onEdit;

  @override
  State<_DraftItemsCard> createState() => _DraftItemsCardState();
}

class _DraftItemsCardState extends State<_DraftItemsCard> {
  var _open = true;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Itens (${widget.lines.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0E0D0F),
                      ),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: pouAppBlue,
                  ),
                ],
              ),
            ),
          ),
          if (_open && widget.lines.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nenhum item nesta nota.',
                  key: Key('note_items_empty'),
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ),
            ),
          if (_open)
            for (var index = 0; index < widget.lines.length; index++) ...[
              if (index > 0)
                const Divider(height: 1, indent: 16, endIndent: 16),
              _NoteLineRow(
                line: widget.lines[index],
                onEdit: widget.onEdit == null
                    ? null
                    : () => widget.onEdit!(index),
              ),
            ],
          if (_open && widget.lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total dos itens',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  Text(
                    formatBrl(
                      widget.lines.fold<int>(
                        0,
                        (sum, line) => sum + line.totalCents,
                      ),
                    ),
                    key: const Key('customer_note_total'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0E0D0F),
                    ),
                  ),
                ],
              ),
            ),
          if (_open && widget.onAdd != null)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                key: const Key('add_item'),
                onPressed: widget.ready ? widget.onAdd : null,
                style: noteQuietButton(),
                child: const Text('+ adicionar item'),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ProductCatalogPage extends StatefulWidget {
  const _ProductCatalogPage({required this.products});

  final List<StockProduct> products;

  @override
  State<_ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _CatalogRow {
  const _CatalogRow({
    required this.product,
    required this.sku,
    required this.priceCents,
  });

  final StockProduct product;
  final String sku;
  final int priceCents;
}

class _ProductCatalogPageState extends State<_ProductCatalogPage> {
  String? _filterLetter;
  var _scrubbing = false;

  List<_CatalogRow> get _rows {
    final rows = [
      for (final product in widget.products)
        _CatalogRow(
          product: product,
          sku: _skuFromId(product.id),
          priceCents: product.salePriceCents,
        ),
    ]..sort(
      (a, b) => a.product.name.toLowerCase().compareTo(
        b.product.name.toLowerCase(),
      ),
    );
    return rows;
  }

  List<_CatalogRow> _visibleRows(List<_CatalogRow> rows) {
    final letter = _filterLetter;
    if (letter == null) return rows;
    return [
      for (final row in rows)
        if (_catalogInitial(row.product.name) == letter) row,
    ];
  }

  void _setLetter(String letter) {
    if (_filterLetter == letter && _scrubbing) return;
    setState(() {
      _filterLetter = letter;
      _scrubbing = true;
    });
  }

  void _tapLetter(String letter) {
    if (_filterLetter == letter) {
      setState(() {
        _filterLetter = null;
        _scrubbing = false;
      });
      return;
    }
    setState(() {
      _filterLetter = letter;
      _scrubbing = false;
    });
  }

  void _endScrub() {
    if (!_scrubbing) return;
    setState(() => _scrubbing = false);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final visible = _visibleRows(rows);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: const Color(0xFFF6F5F7),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D1D6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum produto cadastrado.',
                      key: Key('catalog_empty'),
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  )
                : Stack(
                    children: [
                      if (visible.isEmpty)
                        Center(
                          child: Text(
                            _filterLetter == null
                                ? 'Nenhum produto cadastrado.'
                                : 'Nenhum produto com a letra $_filterLetter.',
                            key: const Key('catalog_letter_empty'),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            28,
                            16 + bottomInset,
                          ),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final row = visible[index];
                            return _ProductCard(
                              row: row,
                              onTap: () => _open(row),
                            );
                          },
                        ),
                      Positioned(
                        key: const Key('catalog_alphabet'),
                        right: 0,
                        top: 8,
                        bottom: 8 + bottomInset,
                        child: _AlphabetIndex(
                          activeLetter: _filterLetter,
                          scrubbing: _scrubbing,
                          onDragLetter: _setLetter,
                          onTapLetter: _tapLetter,
                          onDragEnd: _endScrub,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(_CatalogRow row) async {
    final result = await showPouItemEditSheet(
      context,
      name: row.product.name,
      quantity: 1,
      unitPriceCents: row.priceCents,
      referencePriceCents: row.priceCents,
    );
    if (!mounted || result == null) return;
    Navigator.of(context).pop(
      _CatalogSelection(
        row: row,
        quantity: result.quantity,
        unitPriceCents: result.unitPriceCents,
      ),
    );
  }
}

class _CatalogSelection {
  const _CatalogSelection({
    required this.row,
    required this.quantity,
    required this.unitPriceCents,
  });

  final _CatalogRow row;
  final double quantity;
  final int unitPriceCents;
}

const _alphabetLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

class _AlphabetIndex extends StatefulWidget {
  const _AlphabetIndex({
    required this.activeLetter,
    required this.scrubbing,
    required this.onDragLetter,
    required this.onTapLetter,
    required this.onDragEnd,
  });

  final String? activeLetter;
  final bool scrubbing;
  final ValueChanged<String> onDragLetter;
  final ValueChanged<String> onTapLetter;
  final VoidCallback onDragEnd;

  @override
  State<_AlphabetIndex> createState() => _AlphabetIndexState();
}

class _AlphabetIndexState extends State<_AlphabetIndex> {
  var _moved = false;
  String? _pressed;
  double? _focusY;

  @override
  void didUpdateWidget(covariant _AlphabetIndex oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.scrubbing && _focusY != null && !_moved) {
      _focusY = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        if (height <= 0) return const SizedBox.shrink();
        final focusY = _focusY ?? _focusForLetter(widget.activeLetter, height);
        final waving = focusY != null;
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            _AlphabetDragRecognizer:
                GestureRecognizerFactoryWithHandlers<_AlphabetDragRecognizer>(
                  _AlphabetDragRecognizer.new,
                  (_AlphabetDragRecognizer instance) {
                    instance
                      ..onDown = (details) {
                        _moved = false;
                        _pressed = _letterAt(details.localPosition.dy, height);
                        setState(() => _focusY = details.localPosition.dy);
                      }
                      ..onStart = (details) {
                        final letter = _letterAt(
                          details.localPosition.dy,
                          height,
                        );
                        _moved = true;
                        widget.onDragLetter(_pressed ?? letter);
                        setState(() => _focusY = details.localPosition.dy);
                      }
                      ..onUpdate = (details) {
                        final letter = _letterAt(
                          details.localPosition.dy,
                          height,
                        );
                        if (!_moved) {
                          _moved = true;
                          widget.onDragLetter(_pressed ?? letter);
                        }
                        widget.onDragLetter(letter);
                        setState(() => _focusY = details.localPosition.dy);
                      }
                      ..onEnd = (_) {
                        _finishDrag();
                      }
                      ..onCancel = _finishDrag;
                  },
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  TapGestureRecognizer.new,
                  (TapGestureRecognizer instance) {
                    instance.onTapUp = (details) {
                      widget.onTapLetter(
                        _letterAt(details.localPosition.dy, height),
                      );
                    };
                  },
                ),
          },
          child: SizedBox(
            width: waving ? 48 : 26,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < _alphabetLetters.length; i++)
                  _AlphabetWaveLetter(
                    key: ValueKey(_alphabetLetters[i]),
                    letter: _alphabetLetters[i],
                    index: i,
                    count: _alphabetLetters.length,
                    height: height,
                    focusY: focusY,
                    active: widget.activeLetter == _alphabetLetters[i],
                    scrubbing: widget.scrubbing || _focusY != null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _finishDrag() {
    if (_moved) widget.onDragEnd();
    _pressed = null;
    _moved = false;
    if (_focusY != null) setState(() => _focusY = null);
  }

  String _letterAt(double dy, double height) {
    final clamped = dy.clamp(0, height - 0.001);
    final index = (clamped / height * _alphabetLetters.length).floor().clamp(
      0,
      _alphabetLetters.length - 1,
    );
    return _alphabetLetters[index];
  }

  double? _focusForLetter(String? letter, double height) {
    if (letter == null) return null;
    final index = _alphabetLetters.indexOf(letter);
    if (index < 0) return null;
    return (index + 0.5) / _alphabetLetters.length * height;
  }
}

/// Wins the gesture arena so the bottom sheet does not drag-dismiss.
class _AlphabetDragRecognizer extends VerticalDragGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}

class _AlphabetWaveLetter extends StatelessWidget {
  const _AlphabetWaveLetter({
    super.key,
    required this.letter,
    required this.index,
    required this.count,
    required this.height,
    required this.focusY,
    required this.active,
    required this.scrubbing,
  });

  final String letter;
  final int index;
  final int count;
  final double height;
  final double? focusY;
  final bool active;
  final bool scrubbing;

  @override
  Widget build(BuildContext context) {
    final slot = height / count;
    final centerY = (index + 0.5) * slot;
    final wave = _wave(centerY, slot);
    final shift = scrubbing || active ? -16 * wave : 0.0;
    final scale = 1 + 1.1 * wave;
    return Positioned(
      top: centerY - slot / 2,
      right: 2,
      height: slot,
      child: Transform.translate(
        offset: Offset(shift, 0),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.centerRight,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              letter,
              key: Key('catalog_letter_$letter'),
              style: TextStyle(
                fontSize: 13,
                height: 1,
                fontWeight: wave > 0.75
                    ? FontWeight.w900
                    : FontWeight.w700,
                color: Color.lerp(
                  const Color(0xFF4B5563),
                  const Color(0xFF0E0D0F),
                  wave.clamp(0.0, 1.0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Peak on the focused letter, then steps down on each neighbor.
  double _wave(double centerY, double slot) {
    final focus = focusY;
    if (focus == null) return active ? 0.28 : 0.0;
    final distSlots = (centerY - focus).abs() / slot;
    if (distSlots >= 3) return 0.0;
    // Quadratic falloff: selected=1, ±1≈0.44, ±2≈0.11
    final t = 1 - distSlots / 3;
    return t * t;
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.row, required this.onTap});

  final _CatalogRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('catalog_${row.product.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _CatalogPhoto(name: row.product.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0E0D0F),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFD8F5E4),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Text(
                              'Ativo',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF146C43),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SKU: ${row.sku}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Estoque: ${_formatStock(row.product.available)} ${_stockUnitLabel(row.product)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        Text(
                          formatBrl(row.priceCents),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E0D0F),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogPhoto extends StatelessWidget {
  const _CatalogPhoto({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final photo = produceAsset(name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: const Color(0xFFE9E8EB),
        child: SizedBox(
          width: 64,
          height: 64,
          child: photo == null
              ? const Icon(Icons.eco_outlined, color: Color(0xFF9CA3AF))
              : Image.asset(photo, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

String _skuFromId(String id) {
  final raw = id.startsWith('product-') ? id.substring('product-'.length) : id;
  return raw.toUpperCase();
}

String _catalogInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '#';
  final raw = trimmed[0].toUpperCase();
  const from = 'ÁÀÂÃÄÅÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'AAAAAAEEEEIIIIOOOOOUUUUCN';
  final index = from.indexOf(raw);
  final letter = index >= 0 ? to[index] : raw;
  if (letter.compareTo('A') < 0 || letter.compareTo('Z') > 0) return '#';
  return letter;
}

String _stockUnitLabel(StockProduct product) {
  return switch (product.unit) {
    StockUnit.kilogram => 'kg',
    StockUnit.piece => 'un',
    StockUnit.bunch => product.available == 1 ? 'maço' : 'maços',
    StockUnit.box => 'cx',
    StockUnit.dozen => product.available == 1 ? 'dúzia' : 'dúzias',
  };
}

String _formatStock(double value) {
  if (value != value.roundToDouble()) {
    return value.toStringAsFixed(3).replaceAll('.', ',');
  }
  final negative = value < 0;
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    if (index > 0 && remaining % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

class _NoteLineRow extends StatelessWidget {
  const _NoteLineRow({required this.line, required this.onEdit});

  final NoteLine line;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final quantity = displayQuantity(
      line.unit,
      line.quantity,
    ).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CatalogPhoto(name: line.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E0D0F),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$quantity x ${formatBrl(line.unitPriceCents)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                  ),
                ),
                if (line.discountCents > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    line.quantity == 1 && line.unit != CatalogUnit.kilogram
                        ? 'Desconto ${formatBrl(line.discountCents)}'
                        : 'Desconto ${formatBrl(line.discountCents)} por ${line.unit == CatalogUnit.kilogram ? 'quilo' : 'unidade'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (onEdit != null)
            _Pill(
              label: 'Editar',
              background: const Color(0xFFFFF4CC),
              foreground: const Color(0xFF8A6A2F),
              tapKey: Key('edit_${line.name}'),
              onTap: onEdit,
            ),
        ],
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.customer,
    required this.ledger,
    required this.order,
    required this.onWhatsApp,
  });

  final Customer customer;
  final StreetLedger ledger;
  final SaleOrder order;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final day = _saleDate(ledger, order);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('customer_sale_${order.id}'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _SaleItemsPage(order: order),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (day != null) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  customer.name,
                  key: Key('customer_sale_name_${order.id}'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    InkWell(
                      key: Key('customer_whatsapp_${order.id}'),
                      onTap: onWhatsApp,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _WhatsAppIcon(),
                          SizedBox(width: 6),
                          Text(
                            'mandar mensagem',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatBrl(order.totalCents),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _saleDate(StreetLedger ledger, SaleOrder order) {
  final visitId = order.createdVisitId;
  if (visitId == null) return null;
  for (final visit in ledger.visits) {
    if (visit.id == visitId) return formatDay(dateFromIso(visit.day));
  }
  return null;
}

class _WhatsAppIcon extends StatelessWidget {
  const _WhatsAppIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/whatsapp.svg', width: 20, height: 20);
  }
}

class _SaleItemsPage extends StatefulWidget {
  const _SaleItemsPage({required this.order});

  final SaleOrder order;

  @override
  State<_SaleItemsPage> createState() => _SaleItemsPageState();
}

class _SaleItemsPageState extends State<_SaleItemsPage> {
  var _open = true;
  late final List<SaleLine> _lines = [...widget.order.lines];

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F7),
      appBar: AppBar(backgroundColor: pouAppBlue, foregroundColor: pouCanvas, titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        title: Text('Venda ${order.code}'),),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE6E8EC)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _open = !_open),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Itens (${_lines.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(_open ? Icons.expand_less : Icons.expand_more),
                      ],
                    ),
                  ),
                ),
                if (_open)
                  for (var index = 0; index < _lines.length; index++) ...[
                    if (index > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    _ItemRow(line: _lines[index], onEdit: () => _edit(index)),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(int index) async {
    final line = _lines[index];
    final result = await showPouItemEditSheet(
      context,
      name: line.productName,
      quantity: line.quantity,
      unitPriceCents: line.unitPriceCents,
    );
    if (result == null || !mounted) return;
    setState(() {
      _lines[index] = SaleLine(
        productName: line.productName,
        quantity: result.quantity,
        unit: line.unit,
        unitPriceCents: result.unitPriceCents,
      );
    });
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.line, required this.onEdit});

  final SaleLine line;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final quantity = line.quantity.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CatalogPhoto(name: line.productName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.productName, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  '$quantity x ${formatBrl(line.unitPriceCents)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Pill(
                label: 'Editar',
                background: const Color(0xFFFFF4D6),
                foreground: const Color(0xFF8A6A00),
                tapKey: Key('edit_${line.productName}'),
                onTap: onEdit,
              ),
              const SizedBox(height: 8),
              Text(
                formatBrl(line.totalCents),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.onTap,
    this.tapKey,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: tapKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
