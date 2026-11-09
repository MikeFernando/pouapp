import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/stock_operation.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/rules/stock_rules.dart';
import '../catalog_messages.dart';

const _ink = Color(0xFF0E0D0F);
const _muted = Color(0xFF6B7280);
const _canvas = pouCanvas;
const _fieldFill = pouSurface;

PreferredSizeWidget _operationBar(String title, {bool implyLeading = true}) {
  return AppBar(
    automaticallyImplyLeading: implyLeading,
    backgroundColor: pouInk,
    foregroundColor: pouCanvas,
    titleTextStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    title: Text(title),
  );
}

ButtonStyle _confirmButton(Color accent) => FilledButton.styleFrom(
  backgroundColor: accent,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

ButtonStyle _addButton(Color accent) => OutlinedButton.styleFrom(
  backgroundColor: pouCanvas,
  foregroundColor: pouInk,
  side: BorderSide(color: accent),
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

InputDecoration _fieldDecoration(
  String label, {
  String? hint,
  Color accent = pouInk,
}) {
  const radius = BorderRadius.all(Radius.circular(12));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: _fieldFill,
    labelStyle: const TextStyle(fontSize: 14, color: _muted),
    floatingLabelStyle: TextStyle(color: accent),
    border: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: accent),
    ),
  );
}

class StockOperationPage extends StatefulWidget {
  const StockOperationPage({
    super.key,
    required this.kind,
    this.accent = pouInk,
  });

  final StockOperationKind kind;
  final Color accent;

  @override
  State<StockOperationPage> createState() => _StockOperationPageState();
}

class _LineEntry {
  _LineEntry({this.productId, String quantity = ''})
    : quantity = TextEditingController(text: quantity);

  String? productId;
  final TextEditingController quantity;

  void dispose() => quantity.dispose();
}

class _StockOperationPageState extends State<StockOperationPage> {
  final _reason = TextEditingController();
  final _lines = <_LineEntry>[];
  var _loading = true;
  var _saving = false;
  String? _error;
  String? _draftId;
  List<CatalogProduct> _products = const [];
  StockLocationCode _location = StockLocationCode.warehouse;

  @override
  void initState() {
    super.initState();
    if (widget.kind == StockOperationKind.loss) {
      _location = StockLocationCode.montana;
    }
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repository = sl<CatalogRepository>();
    final draftResult = await repository.ensureStockDraft(widget.kind);
    final catalogResult = await repository.load();
    if (!mounted) return;
    String? error;
    StockDraft? draft;
    draftResult.fold(
      (failure) => error = catalogFailureMessage(failure),
      (value) => draft = value,
    );
    CatalogSnapshot? snapshot;
    catalogResult.fold(
      (failure) => error ??= catalogFailureMessage(failure),
      (value) => snapshot = value,
    );
    if (error != null || draft == null || snapshot == null) {
      setState(() {
        _loading = false;
        _error = error ?? 'Não foi possível abrir a movimentação.';
      });
      return;
    }
    final products = [for (final row in snapshot!.products) row.product];
    final byId = {for (final product in products) product.id: product};
    for (final line in _lines) {
      line.dispose();
    }
    _lines.clear();
    if (draft!.lines.isEmpty) {
      _lines.add(_LineEntry());
    } else {
      for (final line in draft!.lines) {
        final product = byId[line.productId];
        _lines.add(
          _LineEntry(
            productId: line.productId,
            quantity: product == null
                ? '${line.quantity}'
                : editBaseQuantity(product.unit, line.quantity),
          ),
        );
      }
    }
    setState(() {
      _loading = false;
      _draftId = draft!.id;
      _products = products;
      _location = draft!.location ?? _location;
      _reason.text = draft!.reason ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final transfer = widget.kind == StockOperationKind.returnToWarehouse;
    return Scaffold(
      backgroundColor: _canvas,
      appBar: _operationBar(stockOperationTitle(widget.kind)),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: widget.accent,
                semanticsLabel: 'Carregando a movimentação',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (transfer)
                  _DirectionBanner(
                    key: const Key('stock_operation_direction'),
                    text: _direction(),
                  )
                else
                  const Text(
                    'O histórico confirmado permanece. Esta ação não gera venda, dívida, receita ou despesa.',
                    key: Key('stock_operation_direction'),
                    style: TextStyle(fontSize: 15, height: 1.35, color: _muted),
                  ),
                const SizedBox(height: 16),
                if (!transfer) ...[
                  DropdownButtonFormField<StockLocationCode>(
                    key: const Key('stock_location'),
                    initialValue: _location,
                    decoration: _fieldDecoration(
                      'Local',
                      accent: widget.accent,
                    ),
                    items: [
                      for (final location in stockLocations)
                        DropdownMenuItem(
                          value: location.code,
                          child: Text(location.name),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _location = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('stock_reason'),
                    controller: _reason,
                    style: const TextStyle(fontSize: 16, color: _ink),
                    decoration: _fieldDecoration(
                      'Motivo',
                      hint: widget.kind == StockOperationKind.loss
                          ? 'O que aconteceu com a mercadoria'
                          : 'Por que a contagem é diferente',
                      accent: widget.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                for (var index = 0; index < _lines.length; index++) ...[
                  _lineCard(index),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  key: const Key('stock_add_line'),
                  style: _addButton(widget.accent),
                  onPressed: _saving
                      ? null
                      : () => setState(() => _lines.add(_LineEntry())),
                  icon: const Icon(Icons.add),
                  label: const Text('Incluir produto'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const Key('stock_operation_error'),
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('stock_operation_confirm'),
                  style: _confirmButton(widget.accent),
                  onPressed: _saving ? null : _confirm,
                  child: Text(_saving ? 'Gravando' : 'Confirmar'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A confirmação grava a saída e a entrada juntas. Se um produto não puder sair, nada é transferido e este rascunho continua aqui.',
                  style: TextStyle(fontSize: 14, height: 1.35, color: _muted),
                ),
              ],
            ),
    );
  }

  String _direction() {
    final ends = transferEnds(widget.kind);
    return '${locationName(ends.$1)} → ${locationName(ends.$2)}';
  }

  Widget _lineCard(int index) {
    final line = _lines[index];
    final choices = [
      for (final product in _products)
        if (product.active || product.id == line.productId) product,
    ];
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              key: Key('line_product_$index'),
              initialValue: line.productId,
              style: const TextStyle(fontSize: 16, color: _ink),
              decoration: _fieldDecoration('Produto', accent: widget.accent),
              items: [
                for (final product in choices)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text(product.name),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => line.productId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              key: Key('line_quantity_$index'),
              controller: line.quantity,
              style: const TextStyle(fontSize: 16, color: _ink),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _fieldDecoration(
                widget.kind == StockOperationKind.count
                    ? 'Quantidade contada'
                    : 'Quantidade',
                accent: widget.accent,
              ),
            ),
            if (_lines.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: widget.accent),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _lines.removeAt(index).dispose();
                        }),
                  child: const Text('Remover'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final draftId = _draftId;
    if (draftId == null || _saving) return;
    _saving = true;
    final byId = {for (final product in _products) product.id: product};
    final parsed = <StockDraftLine>[];
    for (final line in _lines) {
      final productId = line.productId;
      final product = productId == null ? null : byId[productId];
      if (product == null) {
        setState(() {
          _saving = false;
          _error = 'Escolha o produto.';
        });
        return;
      }
      final quantity = parseBaseQuantity(product.unit, line.quantity.text);
      if (quantity == null) {
        setState(() {
          _saving = false;
          _error = product.unit == CatalogUnit.kilogram
              ? 'Informe o peso em quilos, por exemplo 1,5.'
              : 'Unidade, maço e caixa usam quantidade inteira.';
        });
        return;
      }
      parsed.add(StockDraftLine(productId: product.id, quantity: quantity));
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await sl<CatalogRepository>().confirmStockOperation(
      id: draftId,
      kind: widget.kind,
      location:
          widget.kind == StockOperationKind.loss ||
              widget.kind == StockOperationKind.count
          ? _location
          : null,
      reason: _reason.text,
      lines: parsed,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = catalogFailureMessage(failure);
      }),
      (record) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              record.alreadyRecorded
                  ? 'Esta confirmação já foi registrada.'
                  : 'Movimentação registrada.',
            ),
          ),
        );
      },
    );
  }
}

class _DirectionBanner extends StatelessWidget {
  const _DirectionBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pouSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: pouAccent,
          ),
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

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
