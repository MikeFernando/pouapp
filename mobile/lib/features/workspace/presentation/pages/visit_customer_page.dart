import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/entities/customer_note.dart';
import '../../../customers/domain/repositories/customer_note_repository.dart';
import '../../../customers/domain/rules/note_rules.dart';
import '../../../customers/domain/usecases/customer_use_cases.dart';
import '../../../customers/domain/validation/customer_validators.dart';
import '../../../customers/presentation/customer_messages.dart';
import '../../../assistant/presentation/voice_attendance.dart';
import '../../../customers/presentation/whatsapp_launch.dart';
import '../../domain/entities/street_ledger.dart';
import '../bloc/company_operation_bloc.dart';
import '../operation_labels.dart';

class VisitCustomerPage extends StatefulWidget {
  const VisitCustomerPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<VisitCustomerPage> createState() => _VisitCustomerPageState();
}

class _VisitCustomerPageState extends State<VisitCustomerPage> {
  var _loading = true;
  String? _error;
  Customer? _customer;
  CustomerNote? _note;
  List<CatalogProduct> _products = const [];
  VoiceVisit? _visit;

  @override
  void initState() {
    super.initState();
    _rememberVisit(widget.customerName);
    _load();
  }

  @override
  void dispose() {
    final visit = _visit;
    if (visit != null) VoiceAttendance.unmount(visit);
    super.dispose();
  }

  void _rememberVisit(String label) {
    final next = VoiceVisit(
      customerId: widget.customerId,
      label: label.trim().isEmpty ? widget.customerName : label.trim(),
      onChanged: _load,
    );
    final current = _visit;
    if (current == null) {
      VoiceAttendance.mount(next);
    } else if (current.customerId != next.customerId ||
        current.label != next.label) {
      VoiceAttendance.replace(current, next);
    } else {
      return;
    }
    _visit = next;
  }

  Future<void> _load() async {
    final customer = await sl<GetCustomerById>()(widget.customerId);
    final note = sl.isRegistered<CustomerNoteRepository>()
        ? await sl<CustomerNoteRepository>().currentNote(widget.customerId)
        : null;
    final catalog = await sl<CatalogRepository>().load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      customer.fold(
        (failure) => _error = 'Não foi possível carregar o cliente.',
        (value) => _customer = value,
      );
      final opened = note?.fold<CustomerNote?>((_) => null, (value) => value);
      _note = opened != null && opened.status == NoteStatus.draft
          ? opened
          : null;
      _products = catalog.fold(
        (_) => const [],
        (snapshot) => [
          for (final row in snapshot.products)
            if (row.product.active) row.product,
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final title = customer?.name ?? widget.customerName;
    _rememberVisit(title);
    final mobile = formatPhone(customer?.mobilePhone);
    final ledger = context
        .watch<CompanyOperationBloc>()
        .state
        .operation
        ?.street;
    final orders = [
      for (final order in ledger?.orders ?? const <SaleOrder>[])
        if (order.customerId == widget.customerId) order,
    ];
    final draft = _note;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        title: Text(title),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando cliente',
              ),
            )
          : ListView(
              key: const Key('visit_customer_profile'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB42318),
                      ),
                    ),
                  ),
                const _SectionTitle('Cadastro'),
                _Card(
                  child: Column(
                    children: [
                      _Fact('Nome', title),
                      _PhoneRow(
                        number: mobile.isEmpty ? 'Não informado' : mobile,
                        enabled: mobile.isNotEmpty,
                        onWhatsApp: mobile.isEmpty ? null : _openWhatsApp,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionTitle('Notas'),
                for (var index = 0; index < orders.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  _Card(child: _OrderNote(order: orders[index])),
                ],
                if (orders.isNotEmpty) const SizedBox(height: 12),
                _Card(
                  child: _DraftNote(
                    lines: draft?.lines ?? const [],
                    totalCents: draft?.totalCents ?? 0,
                    onAdd: _addProduct,
                    onEdit: _editLine,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openWhatsApp() async {
    final customer = _customer;
    final digits = _mobileDigits(customer?.mobilePhone);
    if (digits == null) {
      _snack('Esta cliente não tem celular.');
      return;
    }
    final opened = await launchCustomerWhatsApp(digits);
    if (!opened && mounted) {
      _snack(
        'Não foi possível abrir o WhatsApp. Os registros continuam neste aparelho.',
      );
    }
  }

  Future<void> _addProduct() async {
    final note = await _draft();
    if (note == null || !mounted) return;
    final picked = await Navigator.of(context).push<CatalogProduct>(
      MaterialPageRoute(builder: (_) => _ProductPicker(products: _products)),
    );
    if (picked == null || !mounted) return;
    final result = await _editSheet(
      name: picked.name,
      quantity: 1,
      unitPriceCents: picked.salePriceCents,
    );
    if (result == null || !mounted) return;
    final quantity = baseQuantityFromDisplay(picked.unit, result.quantity);
    if (quantity == null) {
      _snack('Não foi possível gravar a nota.');
      return;
    }
    await _save([
      for (final line in note.lines) NoteLineDraft.fromLine(line),
      NoteLineDraft(
        productId: picked.id,
        name: picked.name,
        unit: picked.unit,
        quantity: quantity,
        unitPriceCents: result.unitPriceCents,
      ),
    ], note);
  }

  Future<void> _editLine(int index) async {
    final note = _note;
    if (note == null || index >= note.lines.length) return;
    final line = note.lines[index];
    final result = await _editSheet(
      name: line.name,
      quantity: displayQuantity(line.unit, line.quantity),
      unitPriceCents: line.unitPriceCents,
    );
    if (result == null || !mounted) return;
    final quantity = baseQuantityFromDisplay(line.unit, result.quantity);
    if (quantity == null) {
      _snack('Não foi possível gravar a nota.');
      return;
    }
    await _save([
      for (var position = 0; position < note.lines.length; position++)
        if (position == index)
          NoteLineDraft(
            id: line.id,
            productId: line.productId,
            name: line.name,
            unit: line.unit,
            quantity: quantity,
            unitPriceCents: result.unitPriceCents,
          )
        else
          NoteLineDraft.fromLine(note.lines[position]),
    ], note);
  }

  Future<CustomerNote?> _draft() async {
    final current = _note;
    if (current != null && current.status == NoteStatus.draft) return current;
    if (!sl.isRegistered<CustomerNoteRepository>()) return null;
    final created = await sl<CustomerNoteRepository>().activeDraft(
      widget.customerId,
    );
    if (!mounted) return null;
    return created.fold(
      (_) {
        _snack('Não foi possível gravar a nota.');
        return null;
      },
      (note) {
        setState(() => _note = note);
        return note;
      },
    );
  }

  Future<void> _save(List<NoteLineDraft> lines, CustomerNote note) async {
    if (!sl.isRegistered<CustomerNoteRepository>()) return;
    final result = await sl<CustomerNoteRepository>().saveLines(
      noteId: note.id,
      lines: lines,
    );
    if (!mounted) return;
    result.fold((_) => _snack('Não foi possível gravar a nota.'), (saved) {
      setState(() => _note = saved);
    });
  }

  Future<_LineEdit?> _editSheet({
    required String name,
    required double quantity,
    required int unitPriceCents,
  }) {
    return showModalBottomSheet<_LineEdit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _LineSheet(
        name: name,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

String? _mobileDigits(String? mobile) {
  final national = onlyDigits(mobile).replaceFirst(RegExp(r'^0+'), '');
  if (national.isEmpty) return null;
  if (national.startsWith('55') && national.length > 11) return national;
  return '55$national';
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
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1C1C1E),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1565C0),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.number,
    required this.enabled,
    required this.onWhatsApp,
  });

  final String number;
  final bool enabled;
  final VoidCallback? onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('customer_whatsapp'),
      onTap: onWhatsApp,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const SizedBox(
              width: 88,
              child: Text(
                'Celular',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            Expanded(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled
                      ? const Color(0xFF1B8A4B)
                      : const Color(0xFF1C1C1E),
                ),
              ),
            ),
            Icon(
              Icons.chat,
              size: 20,
              color: enabled
                  ? const Color(0xFF1B8A4B)
                  : const Color(0xFFB0B7C3),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderNote extends StatelessWidget {
  const _OrderNote({required this.order});

  final SaleOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('customer_note_${order.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nota ${order.code}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 10),
        for (final line in order.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    line.productName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                Text(
                  '${formatSaleQuantity(line.quantity, line.unit)} · ${formatBrl(line.totalCents)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        _Total(cents: order.totalCents),
      ],
    );
  }
}

class _DraftNote extends StatelessWidget {
  const _DraftNote({
    required this.lines,
    required this.totalCents,
    required this.onAdd,
    required this.onEdit,
  });

  final List<NoteLine> lines;
  final int totalCents;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nesta visita',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 10),
        if (lines.isEmpty)
          const Text(
            'Nenhum produto nesta nota.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          )
        else
          for (var index = 0; index < lines.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lines[index].name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        Text(
                          '${_quantity(lines[index])} · ${formatBrl(lines[index].totalCents)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: Key('edit_${lines[index].name}'),
                    onPressed: () => onEdit(index),
                    child: const Text('Editar'),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 8),
        _Total(cents: totalCents),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            key: const Key('add_visit_product'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar produto'),
          ),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Valor da nota',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Text(
          formatBrl(cents),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ],
    );
  }
}

String _quantity(NoteLine line) {
  final quantity = displayQuantity(line.unit, line.quantity);
  final text = quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(1).replaceAll('.', ',');
  final unit = switch (line.unit) {
    CatalogUnit.kilogram => 'kg',
    CatalogUnit.piece => 'un',
    CatalogUnit.bunch => quantity == 1 ? 'maço' : 'maços',
    CatalogUnit.box => 'cx',
    CatalogUnit.dozen => quantity == 1 ? 'dúzia' : 'dúzias',
  };
  return '$text $unit';
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.products});

  final List<CatalogProduct> products;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        title: const Text('Adicionar produto'),
      ),
      body: products.isEmpty
          ? const Center(child: Text('Nenhum produto cadastrado.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = products[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: Key('visit_product_${product.id}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(product),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            formatBrl(product.salePriceCents),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _LineEdit {
  const _LineEdit({required this.quantity, required this.unitPriceCents});

  final double quantity;
  final int unitPriceCents;
}

class _LineSheet extends StatefulWidget {
  const _LineSheet({
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
  });

  final String name;
  final double quantity;
  final int unitPriceCents;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  late var _quantity = widget.quantity;
  late final _price = TextEditingController(
    text: _priceText(widget.unitPriceCents),
  );
  var _error = false;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              widget.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  key: const Key('item_quantity_minus'),
                  onPressed: _quantity <= 1
                      ? null
                      : () => setState(() => _quantity -= 1),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    _quantity.toStringAsFixed(1).replaceAll('.', ','),
                    key: const Key('item_quantity'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('item_quantity_plus'),
                  onPressed: () => setState(() => _quantity += 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('item_price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Preço',
                prefixText: 'R\$ ',
              ),
            ),
          ),
          if (_error)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Informe um preço válido.',
                style: TextStyle(color: Color(0xFFB42318)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: FilledButton(
              key: const Key('item_save'),
              onPressed: _save,
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final price = _parsePrice(_price.text);
    if (price == null) {
      setState(() => _error = true);
      return;
    }
    Navigator.of(context)
        .pop(_LineEdit(quantity: _quantity, unitPriceCents: price));
  }
}

String _priceText(int cents) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '$whole,$fraction';
}

int? _parsePrice(String raw) {
  final cleaned = raw.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (cleaned.isEmpty) return null;
  final normalized = cleaned.contains(',')
      ? cleaned.replaceAll('.', '').replaceAll(',', '.')
      : cleaned;
  final value = double.tryParse(normalized);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}
