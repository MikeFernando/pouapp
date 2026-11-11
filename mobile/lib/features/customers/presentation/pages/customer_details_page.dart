import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/pou_alphabet_index.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../app/pou_confirm_dialog.dart';
import '../../../../app/pou_date_sheet.dart';
import '../../../../app/pou_item_edit_sheet.dart';
import '../../../../core/config/api_config.dart';
import '../../../../injection_container.dart' as di;
import '../../../assistant/presentation/voice_attendance.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../../catalog/presentation/produce_assets.dart';
import '../../../workspace/domain/entities/stock_board.dart';
import '../../../workspace/domain/entities/street_ledger.dart';
import '../../../workspace/domain/usecases/home_use_cases.dart';
import '../../../workspace/presentation/bloc/company_operation_bloc.dart';
import '../../../workspace/presentation/bloc/home_board_bloc.dart';
import '../../../workspace/presentation/loaded_operation.dart';
import '../../../workspace/presentation/operation_labels.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_note.dart';
import '../../domain/repositories/customer_note_repository.dart';
import '../../domain/rules/note_rules.dart';
import '../../domain/validation/customer_validators.dart';
import '../bloc/customer_details_bloc.dart';
import '../customer_messages.dart';
import '../whatsapp_launch.dart';
import '../widgets/customer_account_section.dart';
import '../widgets/customer_new_sheet.dart';
import '../widgets/customer_status_badge.dart';
import '../widgets/customer_status_sheet.dart';

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
            backgroundColor: pouLeafChrome,
            appBar: pouLeafAppBar(title: const Text('Cliente')),
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
        const bodyRadius = 32.0;
        return Scaffold(
          backgroundColor: pouLeafChrome,
          appBar: pouLeafAppBar(
            title: Text(customer.name),
            actions: [
              PopupMenuButton<String>(
                key: const Key('customer_details_menu'),
                icon: const Icon(Icons.more_vert),
                color: Colors.white,
                onSelected: (value) async {
                  if (value == 'edit') {
                    final saved = await showCustomerQuickSheet(
                      context,
                      customer: customer,
                    );
                    if (!context.mounted) return;
                    if (saved == true) {
                      context.read<CustomerDetailsBloc>().add(
                        CustomerDetailsRequested(customer.id),
                      );
                    }
                    return;
                  }
                  if (value == 'clear_note') {
                    await _clearNote();
                  }
                },
                itemBuilder: (context) {
                  final canClear =
                      note != null &&
                      note.status != NoteStatus.delivered &&
                      (note.lines.isNotEmpty || note.dueOn != null);
                  return [
                    const PopupMenuItem<String>(
                      key: Key('customer_edit_menu_item'),
                      value: 'edit',
                      child: Text('Editar cadastro'),
                    ),
                    PopupMenuItem<String>(
                      key: const Key('customer_clear_note_menu_item'),
                      value: 'clear_note',
                      enabled: canClear,
                      child: const Text('Limpar nota'),
                    ),
                  ];
                },
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Leaf continues into the rounded-card corner reveals.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: bodyRadius,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: bodyRadius /
                        (MediaQuery.paddingOf(context).top + kToolbarHeight),
                    child: SizedBox(
                      height:
                          MediaQuery.paddingOf(context).top + kToolbarHeight,
                      width: double.infinity,
                      child: pouLeafBackdrop(),
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(bodyRadius),
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
                        status: customer.status,
                        onTap: () => _openStatus(customer),
                      ),
                      Builder(
                        builder: (context) {
                          final phone = primaryPhone(customer);
                          if (phone.isEmpty) return const SizedBox.shrink();
                          return _WhatsAppPhoneCard(
                            phone: phone,
                            onTap: () => _openWhatsApp(customer),
                          );
                        },
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
                      CustomerAccountSection(
                        customer: customer,
                        itemsTotalCents: note?.totalCents ?? 0,
                        onRemainingDueSet: (dueOn) async {
                          final current = _note;
                          if (current == null ||
                              current.status == NoteStatus.delivered) {
                            return;
                          }
                          if (!di.sl.isRegistered<CustomerNoteRepository>()) {
                            setState(
                              () => _note = current.copyWith(dueOn: dueOn),
                            );
                            return;
                          }
                          final result =
                              await di.sl<CustomerNoteRepository>().setDueOn(
                            noteId: current.id,
                            dueOn: dueOn,
                          );
                          if (!mounted) return;
                          result.fold(_rememberFailure, (saved) {
                            setState(() {
                              _noteError = null;
                              _note = saved;
                            });
                            _syncNoteToHome(saved);
                          });
                        },
                      ),
                    ],
                  ),
                ),
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
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final picked = await showPouDateSheet(
      context,
      initial: note.dueOn ?? todayStart,
      title: 'Escolha a data de vencimento',
      firstDate: todayStart,
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
      _syncNoteToHome(saved);
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

  Future<void> _clearNote() async {
    final note = _note;
    if (note == null ||
        note.status == NoteStatus.delivered ||
        (note.lines.isEmpty && note.dueOn == null)) {
      return;
    }
    final confirmed = await showPouConfirmDialog(
      context,
      title: 'Limpar nota?',
      message:
          'Todos os itens desta nota serão removidos e o vencimento voltará para sem data.',
      confirmLabel: 'Limpar',
      confirmKey: const Key('confirm_clear_note'),
    );
    if (!confirmed || !mounted) return;
    await _persistLines(const [], clearing: true);
  }

  Future<void> _persistLines(
    List<NoteLineDraft> drafts, {
    bool clearing = false,
  }) async {
    final note = _note;
    if (note == null) return;
    if (!di.sl.isRegistered<CustomerNoteRepository>()) {
      setState(() {
        _noteError = null;
        _note = note.copyWith(
          updatedAt: DateTime.now(),
          clearDueOn: clearing,
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
    if (result.isLeft()) {
      _rememberFailure(null);
      return;
    }
    var next = result.getOrElse(() => note);
    if (clearing || next.totalCents <= 0) {
      final dueCleared = await di.sl<CustomerNoteRepository>().setDueOn(
        noteId: next.id,
        dueOn: null,
      );
      next = dueCleared.fold(
        (_) => next.copyWith(clearDueOn: true),
        (value) => value,
      );
    }
    if (!mounted) return;
    setState(() {
      _noteError = null;
      _note = next;
    });
    await _syncNoteToHome(next, cleared: clearing || next.totalCents <= 0);
  }

  Future<void> _syncNoteToHome(
    CustomerNote note, {
    bool cleared = false,
  }) async {
    if (!ApiConfig.useRemoteApi) return;
    try {
      if (cleared || note.dueOn == null || note.totalCents <= 0) {
        if (di.sl.isRegistered<ClearHomeNote>()) {
          await di.sl<ClearHomeNote>()(customerId: note.customerId);
        }
      } else if (di.sl.isRegistered<CreateHomeNote>()) {
        await di.sl<CreateHomeNote>()(
          customerId: note.customerId,
          dueOn: isoDate(note.dueOn!),
          totalCents: note.totalCents,
        );
      }
    } catch (_) {
      // Local note already saved; home sync must not crash the clear flow.
    }
    if (di.sl.isRegistered<HomeBoardBloc>()) {
      di.sl<HomeBoardBloc>().add(const HomeBoardRequested());
    }
  }

  void _rememberFailure(Object? _) {
    setState(() => _noteError = 'Não foi possível gravar a nota.');
  }

  Future<void> _openStatus(Customer customer) async {
    final next = await showCustomerStatusSheet(
      context,
      current: customer.status,
    );
    if (!mounted || next == null || next == customer.status) return;
    context.read<CustomerDetailsBloc>().add(
      CustomerStatusChangeRequested(next),
    );
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
  const _SituationBar({required this.status, required this.onTap});

  final CustomerStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const Key('customer_situation'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
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
                CustomerStatusBadge(status: status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WhatsAppPhoneCard extends StatelessWidget {
  const _WhatsAppPhoneCard({required this.phone, required this.onTap});

  final String phone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('customer_whatsapp_card'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const _WhatsAppIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    phone,
                    key: const Key('customer_whatsapp_phone'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0E0D0F),
                    ),
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
        if (pouAlphabetInitial(row.product.name) == letter) row,
    ];
  }

  void _setLetter(String? letter) {
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
                        child: PouAlphabetIndex(
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
