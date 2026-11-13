import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/pou_alphabet_index.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../app/pou_confirm_dialog.dart';
import '../../../../app/pou_date_sheet.dart';
import '../../../../app/pou_item_edit_sheet.dart';
import '../../../../app/pou_top_snack.dart';
import '../../../../core/config/api_config.dart';
import '../../../../injection_container.dart' as di;
import '../../../assistant/presentation/voice_attendance.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../../catalog/presentation/produce_assets.dart';
import '../../../workspace/domain/entities/stock_board.dart';
import '../../../workspace/data/day_checklist_store.dart';
import '../../../workspace/domain/entities/street_ledger.dart';
import '../../../workspace/domain/rules/month_board.dart';
import '../../../workspace/domain/usecases/home_use_cases.dart';
import '../../../workspace/presentation/bloc/company_operation_bloc.dart';
import '../../../workspace/presentation/bloc/home_board_bloc.dart';
import '../../../workspace/presentation/loaded_operation.dart';
import '../../../workspace/presentation/operation_labels.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_note.dart';
import '../../domain/repositories/customer_note_repository.dart';
import '../../domain/rules/note_due_style.dart';
import '../../domain/rules/note_rules.dart';
import '../bloc/customer_details_bloc.dart';
import '../customer_messages.dart';
import '../note_share.dart';
import '../whatsapp_launch.dart';
import '../widgets/customer_account_section.dart';
import '../widgets/customer_action_card.dart';
import '../widgets/customer_new_sheet.dart';
import '../widgets/customer_status_badge.dart';
import '../widgets/customer_status_sheet.dart';
import '../widgets/deleted_notes_sheet.dart';
import '../widgets/note_summary_bar.dart';
import '../widgets/save_note_sheet.dart';

String? whatsAppPhoneDigits(Customer customer) =>
    customerWhatsAppDigits(customer);

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
  CustomerNote? _savedNote;
  String? _noteError;
  var _noteRequestedFor = '';
  var _memoryLine = 0;
  PaymentMethod? _paymentMethod;
  PaymentMethod? _savedPayment;
  var _allowLeave = false;
  final List<CustomerNote> _memoryDeletedNotes = [];
  VoiceVisit? _visit;

  bool get _noteDirty {
    if (_allowLeave) return false;
    final note = _note;
    final saved = _savedNote;
    if (note == null || saved == null) return false;
    if (note.status == NoteStatus.delivered) return false;
    if (note.id != saved.id) return false;
    if (_paymentMethod != _savedPayment) return true;
    if (note.dueOn != saved.dueOn) return true;
    if (note.lines.length != saved.lines.length) return true;
    for (var index = 0; index < note.lines.length; index++) {
      if (note.lines[index] != saved.lines[index]) return true;
    }
    return false;
  }

  void _rememberSavedSnapshot({
    CustomerNote? note,
    PaymentMethod? paymentMethod,
  }) {
    final current = note ?? _note;
    _savedNote = current;
    _savedPayment = paymentMethod ?? current?.paymentMethod ?? _paymentMethod;
  }

  @override
  void dispose() {
    dismissPouTopSnack();
    final visit = _visit;
    if (visit != null) VoiceAttendance.unmount(visit);
    super.dispose();
  }

  Future<bool> _confirmLeaveWithoutSaving() {
    return showPouConfirmDialog(
      context,
      title: 'Sair sem salvar?',
      message: 'Você alterou os dados desta nota. Deseja sair sem salvar?',
      confirmLabel: 'Sair sem salvar',
      cancelLabel: 'Continuar editando',
      icon: Icons.logout_rounded,
      confirmKey: const Key('confirm_leave_note'),
    );
  }

  Future<void> _handleLeaveAttempt() async {
    if (!_noteDirty) return;
    final leave = await _confirmLeaveWithoutSaving();
    if (!leave || !mounted) return;
    setState(() => _allowLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
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
        return PopScope(
          canPop: !_noteDirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop || !_noteDirty) return;
            await _handleLeaveAttempt();
          },
          child: Scaffold(
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
                      final savedId = await showCustomerQuickSheet(
                        context,
                        customer: customer,
                      );
                      if (!context.mounted) return;
                      if (savedId != null) {
                        context.read<CustomerDetailsBloc>().add(
                          CustomerDetailsRequested(customer.id),
                        );
                      }
                      return;
                    }
                    if (value == 'send_note') {
                      await _sendNote(customer);
                      return;
                    }
                    if (value == 'delete_note') {
                      await _deleteNote();
                      return;
                    }
                    if (value == 'deleted_notes') {
                      await _showDeletedNotes(customer);
                    }
                  },
                  itemBuilder: (context) {
                    final canSend = note != null && note.lines.isNotEmpty;
                    final canDelete =
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
                        key: const Key('customer_send_note_menu_item'),
                        value: 'send_note',
                        enabled: canSend,
                        child: const Text('Enviar nota'),
                      ),
                      PopupMenuItem<String>(
                        key: const Key('customer_delete_note_menu_item'),
                        value: 'delete_note',
                        enabled: canDelete,
                        child: const Text('Excluir nota'),
                      ),
                      const PopupMenuItem<String>(
                        key: Key('customer_deleted_notes_menu_item'),
                        value: 'deleted_notes',
                        child: Text('Notas excluídas'),
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
                      heightFactor:
                          bodyRadius /
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _SituationBar(
                                      status: customer.status,
                                      overdue: noteDueIsOverdue(note?.dueOn),
                                      onTap: () => _openStatus(customer),
                                    ),
                                    Builder(
                                      builder: (context) {
                                        final phone = primaryPhone(customer);
                                        if (phone.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        return _WhatsAppPhoneCard(
                                          phone: phone,
                                          onTap: () => _openWhatsApp(customer),
                                        );
                                      },
                                    ),
                                    if (note?.status ==
                                        NoteStatus.delivered) ...[
                                      const Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          16,
                                          8,
                                          16,
                                          0,
                                        ),
                                        child: Text(
                                          'Entrega confirmada. Correções desta nota ficam para a etapa própria.',
                                          key: Key('delivery_locked'),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          0,
                                        ),
                                        child: OutlinedButton(
                                          key: const Key('new_purchase'),
                                          style: noteSecondaryButton(),
                                          onPressed: () =>
                                              _newPurchase(customer.id),
                                          child: const Text('Nova compra'),
                                        ),
                                      ),
                                    ],
                                    if (_noteError != null)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          8,
                                          16,
                                          0,
                                        ),
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
                                          sales.message ?? 'Não foi possível carregar as vendas.',
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    else
                                      _SalesList(
                                        customer: customer,
                                        ledger: ledger,
                                        lines: note?.lines ?? const [],
                                        ready: note != null,
                                        paymentMethod: _paymentMethod,
                                        dueOn: note?.dueOn,
                                        onPickPayment: _pickPaymentMethod,
                                        onPickDue:
                                            note?.status == NoteStatus.delivered
                                            ? null
                                            : _openDueDate,
                                        onWhatsApp: () =>
                                            _openWhatsApp(customer),
                                        onAdd:
                                            note == null ||
                                                note.status ==
                                                    NoteStatus.delivered
                                            ? null
                                            : _addLine,
                                        onEdit:
                                            note?.status == NoteStatus.delivered
                                            ? null
                                            : _editLine,
                                      ),
                                    CustomerAccountSection(customer: customer),
                                  ],
                                ),
                              ),
                            ),
                            NoteSummaryBar(
                              customer: customer,
                              note: note,
                              paymentMethod: _paymentMethod,
                              onPickPayment: _pickPaymentMethod,
                              onPickDue: note?.status == NoteStatus.delivered
                                  ? null
                                  : _openDueDate,
                              onCommit: _commitNoteSave,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickPaymentMethod() async {
    final selected = await showModalBottomSheet<PaymentMethod>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 16),
                const Text(
                  'Forma de pagamento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: pouInk,
                  ),
                ),
                const SizedBox(height: 12),
                for (final method in PaymentMethod.values) ...[
                  ListTile(
                    key: Key('note_payment_${method.name}'),
                    contentPadding: EdgeInsets.zero,
                    leading: _PaymentMethodIcon(method: method),
                    title: Text(
                      paymentMethodLabel(method),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: pouInk,
                      ),
                    ),
                    trailing: Icon(
                      _paymentMethod == method
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _paymentMethod == method
                          ? pouBrand
                          : const Color(0xFF9CA3AF),
                    ),
                    onTap: () => Navigator.of(context).pop(method),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      _paymentMethod = selected;
      final note = _note;
      if (note != null && note.status != NoteStatus.delivered) {
        _note = note.copyWith(paymentMethod: selected);
      }
    });
  }

  Future<bool> _commitNoteSave(SaveNoteChoice choice) async {
    final note = _note;
    final method = _paymentMethod;
    if (note == null || method == null) return false;
    if (note.status == NoteStatus.delivered) return false;

    if (!di.sl.isRegistered<CustomerNoteRepository>()) {
      final saved = note.copyWith(
        paymentMethod: method,
        updatedAt: DateTime.now(),
      );
      setState(() {
        _note = saved;
        _paymentMethod = method;
        _rememberSavedSnapshot(note: saved, paymentMethod: method);
      });
    } else {
      final repo = di.sl<CustomerNoteRepository>();
      final linesResult = await repo.saveLines(
        noteId: note.id,
        lines: [for (final line in note.lines) NoteLineDraft.fromLine(line)],
      );
      if (!mounted) return false;
      if (linesResult.isLeft()) {
        _rememberFailure(null);
        return false;
      }
      var saved = linesResult.getOrElse(() => note);
      final dueOn = saved.totalCents <= 0 ? null : note.dueOn;
      final dueResult = await repo.setDueOn(noteId: saved.id, dueOn: dueOn);
      if (!mounted) return false;
      if (dueResult.isLeft()) {
        _rememberFailure(null);
        return false;
      }
      saved = dueResult.getOrElse(() => saved);
      final payResult = await repo.setPaymentMethod(
        noteId: saved.id,
        paymentMethod: method,
      );
      if (!mounted) return false;
      if (payResult.isLeft()) {
        _rememberFailure(null);
        return false;
      }
      saved = payResult.getOrElse(() => saved);
      final payment = saved.paymentMethod ?? method;
      setState(() {
        _noteError = null;
        _note = saved;
        _paymentMethod = payment;
        _rememberSavedSnapshot(note: saved, paymentMethod: payment);
      });
      unawaited(
        _syncNoteToHome(
          saved,
          cleared: saved.totalCents <= 0 || saved.dueOn == null,
        ),
      );
      if (!mounted) return false;
    }

    final sent = choice == SaveNoteChoice.sendPdf;
    await showPouTopSnack(
      context,
      message: sent ? 'Nota compartilhada.' : 'Nota salva sem enviar.',
      icon: sent ? Icons.ios_share_rounded : Icons.check_circle_rounded,
    );
    return true;
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
      final note = CustomerNote(
        id: 'memory-$customerId',
        customerId: customerId,
        status: NoteStatus.draft,
        createdAt: now,
        updatedAt: now,
        lines: const [],
      );
      setState(() {
        _noteError = null;
        _note = note;
        _paymentMethod = null;
        _allowLeave = false;
        _rememberSavedSnapshot(note: note, paymentMethod: null);
      });
      return;
    }
    final result = await di.sl<CustomerNoteRepository>().openNote(customerId);
    if (!mounted || _noteRequestedFor != customerId) return;
    result.fold(_rememberFailure, (note) {
      setState(() {
        _noteError = null;
        _note = note;
        _paymentMethod = note.paymentMethod;
        _allowLeave = false;
        _rememberSavedSnapshot(note: note, paymentMethod: note.paymentMethod);
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
    final currentDue = note.dueOn;
    final firstDate =
        currentDue != null && noteDueIsOverdue(currentDue, today)
        ? DateTime(currentDue.year, currentDue.month, currentDue.day)
        : todayStart;
    final picked = await showPouDateSheet(
      context,
      initial: currentDue ?? todayStart,
      title: 'Escolha a data de vencimento',
      firstDate: firstDate,
    );
    if (picked == null || !mounted) return;
    final dueOn = DateTime(picked.year, picked.month, picked.day);

    // Always persist vencimento to SQLite so offline home updates immediately.
    if (!di.sl.isRegistered<CustomerNoteRepository>()) {
      setState(() {
        _noteError = null;
        _note = note.copyWith(dueOn: dueOn, updatedAt: DateTime.now());
        final saved = _savedNote;
        if (saved != null) {
          _savedNote = saved.copyWith(dueOn: dueOn, updatedAt: DateTime.now());
        }
      });
      return;
    }

    final result = await di.sl<CustomerNoteRepository>().setDueOn(
      noteId: note.id,
      dueOn: dueOn,
    );
    if (!mounted) return;
    if (result.isLeft()) {
      _rememberFailure(null);
      return;
    }
    final saved = result.getOrElse(() => note);
    setState(() {
      _noteError = null;
      _note = note.copyWith(
        dueOn: saved.dueOn,
        updatedAt: saved.updatedAt,
      );
      final snapshot = _savedNote;
      if (snapshot != null) {
        _savedNote = snapshot.copyWith(
          dueOn: saved.dueOn,
          updatedAt: saved.updatedAt,
        );
      }
    });
    // API + home refresh run in the background — UI never waits on network.
    unawaited(
      _syncNoteToHome(
        saved,
        cleared: saved.totalCents <= 0 || saved.dueOn == null,
      ),
    );
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
    final sheetHeight = media.size.height - media.padding.top - kToolbarHeight;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: const Color(0xFFF6F5F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: sheetHeight,
        child: _ProductCatalogPage(
          products: products,
          onAdd: _addCatalogSelection,
        ),
      ),
    );
  }

  Future<void> _addCatalogSelection(_CatalogSelection picked) async {
    final note = _note;
    if (note == null || note.status == NoteStatus.delivered) return;
    final unit = _catalogUnit(picked.row.product.unit);
    final quantity = baseQuantityFromDisplay(unit, picked.quantity);
    if (quantity == null) {
      _rememberFailure(null);
      return;
    }
    await _persistLines(
      appendOrIncrementNoteLine(
        existing: note.lines,
        incoming: NoteLineDraft(
          productId: picked.row.product.id,
          name: picked.row.product.name,
          unit: unit,
          quantity: quantity,
          unitPriceCents: picked.unitPriceCents,
          referencePriceCents: picked.row.priceCents,
        ),
      ),
    );
  }

  Future<void> _deleteNote() async {
    final note = _note;
    if (note == null ||
        note.status == NoteStatus.delivered ||
        (note.lines.isEmpty && note.dueOn == null)) {
      return;
    }
    final confirmed = await showPouConfirmDialog(
      context,
      title: 'Excluir nota?',
      message: 'A nota atual vai para Notas excluídas e uma nota vazia abre no lugar.',
      confirmLabel: 'Excluir',
      confirmKey: const Key('confirm_delete_note'),
    );
    if (!confirmed || !mounted) return;
    await _commitReceivedNote(note);

    if (!di.sl.isRegistered<CustomerNoteRepository>()) {
      final now = DateTime.now();
      final next = CustomerNote(
        id: 'memory-draft-${now.microsecondsSinceEpoch}',
        customerId: note.customerId,
        status: NoteStatus.draft,
        createdAt: now,
        updatedAt: now,
        lines: const [],
      );
      setState(() {
        _noteError = null;
        _memoryDeletedNotes.insert(
          0,
          note.copyWith(status: NoteStatus.deleted, updatedAt: now),
        );
        _note = next;
        _paymentMethod = null;
        _rememberSavedSnapshot(note: next, paymentMethod: null);
      });
      unawaited(_syncNoteToHome(note, cleared: true));
      return;
    }

    final result = await di.sl<CustomerNoteRepository>().deleteNote(note.id);
    if (!mounted) return;
    if (result.isLeft()) {
      _rememberFailure(null);
      return;
    }
    final next = result.getOrElse(() => note);
    setState(() {
      _noteError = null;
      _note = next;
      _paymentMethod = next.paymentMethod;
      _rememberSavedSnapshot(
        note: next,
        paymentMethod: next.paymentMethod,
      );
    });
    unawaited(_syncNoteToHome(next, cleared: true));
  }

  /// A marked receipt becomes permanent in Financeiro only when the note is
  /// deleted. Unmarking before that removes it again.
  Future<void> _commitReceivedNote(CustomerNote note) async {
    if (!di.sl.isRegistered<DayChecklistStore>()) return;
    if (note.totalCents <= 0) return;
    final store = di.sl<DayChecklistStore>();
    final today = DateTime.now();
    final served = store.loadServed(today);
    if (!served.contains(note.customerId)) return;
    final products = <String, int>{};
    for (final line in note.lines) {
      final name = line.name.trim();
      if (name.isEmpty || line.totalCents <= 0) continue;
      products[name] = (products[name] ?? 0) + line.totalCents;
    }
    await store.commitReceipt(
      noteId: note.id,
      entry: DayChecklistFrozen(
        receivedCents: note.totalCents,
        productCents: products,
      ),
    );
    served.remove(note.customerId);
    await store.saveServed(today, served);
    final frozen = store.loadFrozen(today)..remove(note.customerId);
    await store.saveFrozen(today, frozen);
  }

  Future<void> _showDeletedNotes(Customer customer) async {
    List<CustomerNote> notes = List.of(_memoryDeletedNotes);
    if (di.sl.isRegistered<CustomerNoteRepository>()) {
      final result = await di.sl<CustomerNoteRepository>().deletedNotes(
        customer.id,
      );
      if (!mounted) return;
      notes = result.fold((_) => notes, (value) => value);
    }
    if (!mounted) return;
    await showDeletedNotesSheet(
      context,
      customerName: customer.name,
      notes: notes,
    );
  }

  Future<void> _persistLines(
    List<NoteLineDraft> drafts, {
    bool clearing = false,
  }) async {
    final note = _note;
    if (note == null || note.status == NoteStatus.delivered) return;
    final lines = [
      for (final draft in drafts)
        NoteLine(
          id: draft.id ?? 'local-${_memoryLine++}',
          productId: draft.productId,
          name: draft.name.trim(),
          unit: draft.unit,
          quantity: draft.quantity,
          unitPriceCents: draft.unitPriceCents,
          referencePriceCents: draft.referencePriceCents,
        ),
    ];
    final clearDue = clearing || lines.isEmpty;
    setState(() {
      _noteError = null;
      _note = note.copyWith(
        updatedAt: DateTime.now(),
        clearDueOn: clearDue,
        lines: lines,
      );
    });
  }

  Future<void> _syncNoteToHome(
    CustomerNote note, {
    bool cleared = false,
  }) async {
    // Soft-refresh home from local cache/SQLite; network sync is best-effort.
    if (di.sl.isRegistered<HomeBoardBloc>()) {
      di.sl<HomeBoardBloc>().add(const HomeBoardRequested());
    }
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
  }

  void _rememberFailure(Object? error) {
    debugPrint('note save failed: $error');
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

  Future<void> _sendNote(Customer customer) async {
    final note = _note;
    if (note == null || note.lines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione um item para enviar a nota.')),
      );
      return;
    }
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await shareCustomerNotePdf(
        customer: customer,
        note: note.copyWith(lines: List.of(note.lines)),
        sharePositionOrigin: origin,
      );
    } catch (error, stack) {
      debugPrint('send note failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível gerar a nota. Tente novamente.'),
        ),
      );
    }
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
  const _SituationBar({
    required this.status,
    required this.onTap,
    this.overdue = false,
  });

  final CustomerStatus status;
  final bool overdue;
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
                CustomerStatusBadge(status: status, overdue: overdue),
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

class _PaymentMethodIcon extends StatelessWidget {
  const _PaymentMethodIcon({required this.method});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: switch (method) {
        PaymentMethod.cash => Image.asset(
          'assets/images/payment-cash.png',
          fit: BoxFit.contain,
        ),
        PaymentMethod.card => Image.asset(
          'assets/images/payment-card.png',
          fit: BoxFit.contain,
        ),
        PaymentMethod.pix => const Icon(
          Icons.pix,
          size: 26,
          color: Color(0xFF32BCAD),
        ),
      },
    );
  }
}

class _DueDateCard extends StatelessWidget {
  const _DueDateCard({required this.date, required this.onPick});

  final DateTime? date;
  final VoidCallback? onPick;

  static const _overdue = Color(0xFF9B1C1C);
  static const _overdueTile = Color(0xFFF8E8E8);

  @override
  Widget build(BuildContext context) {
    final overdue = noteDueIsOverdue(date);
    return CustomerActionCard(
      labelFirst: true,
      label: 'Vencimento',
      title: date == null ? 'Sem vencimento' : formatDay(date!),
      titleKey: const Key('customer_due_date'),
      iconKey: const Key('due_calendar'),
      onTap: onPick,
      titleColor: overdue ? _overdue : null,
      iconTileColor: overdue ? _overdueTile : null,
      icon: DueCalendarIcon(color: overdue ? _overdue : pouBrand),
    );
  }
}

class _SalesList extends StatelessWidget {
  const _SalesList({
    required this.customer,
    required this.ledger,
    required this.lines,
    required this.ready,
    required this.paymentMethod,
    required this.dueOn,
    required this.onPickPayment,
    required this.onPickDue,
    required this.onWhatsApp,
    required this.onAdd,
    required this.onEdit,
  });

  final Customer customer;
  final StreetLedger ledger;
  final List<NoteLine> lines;
  final bool ready;
  final PaymentMethod? paymentMethod;
  final DateTime? dueOn;
  final VoidCallback onPickPayment;
  final VoidCallback? onPickDue;
  final VoidCallback onWhatsApp;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onEdit;

  @override
  Widget build(BuildContext context) {
    final orders = [
      for (final order in ledger.orders)
        if (order.customerId == customer.id && order.recorded) order,
    ]..sort((a, b) => b.code.compareTo(a.code));
    final paymentDescription = paymentMethod == null
        ? 'Selecione dinheiro, cartão ou Pix'
        : paymentMethodLabel(paymentMethod!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _DraftItemsCard(
            lines: lines,
            ready: ready,
            onAdd: onAdd,
            onEdit: onEdit,
          ),
        ),
        CustomerActionCard(
          inkWellKey: const Key('note_payment_method'),
          labelFirst: false,
          title: 'Forma de pagamento',
          label: paymentDescription,
          onTap: onPickPayment,
          iconTiled: false,
          icon: const Icon(
            Icons.expand_more_rounded,
            color: Color(0xFF6B7280),
            size: 28,
          ),
        ),
        _DueDateCard(date: dueOn, onPick: onPickDue),
        if (orders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: [
                for (final order in orders)
                  _SaleCard(
                    customer: customer,
                    ledger: ledger,
                    order: order,
                    onWhatsApp: onWhatsApp,
                  ),
              ],
            ),
          ),
      ],
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
  var _open = false;

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
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 8),
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
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Icon(
                        _open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: const Color(0xFF6B7280),
                        size: 28,
                      ),
                    ),
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
  const _ProductCatalogPage({required this.products, required this.onAdd});

  final Future<void> Function(_CatalogSelection selection) onAdd;

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
    final rows =
        [
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
                      if (visible.isEmpty && _filterLetter == null)
                        const Center(
                          child: Text(
                            'Nenhum produto cadastrado.',
                            key: Key('catalog_letter_empty'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        )
                      else if (visible.isNotEmpty)
                        ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            28,
                            16 + bottomInset,
                          ),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final row = visible[index];
                            return _ProductCard(
                              row: row,
                              onTap: () => _open(row),
                            );
                          },
                        ),
                      if (_filterLetter != null &&
                          (visible.isEmpty || _scrubbing))
                        IgnorePointer(
                          child: Center(
                            child: PouAlphabetLetterPreview(
                              key: Key(
                                visible.isEmpty
                                    ? 'catalog_letter_empty'
                                    : 'catalog_letter_scrub',
                              ),
                              letter: _filterLetter!,
                              faint: visible.isNotEmpty,
                            ),
                          ),
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
    if (!mounted || result == null || result.removed) return;
    await widget.onAdd(
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
      appBar: AppBar(
        backgroundColor: pouAppBlue,
        foregroundColor: pouCanvas,
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        title: Text('Venda ${order.code}'),
      ),
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
