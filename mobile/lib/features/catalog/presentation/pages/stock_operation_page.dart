import 'package:flutter/material.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/stock_operation.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/rules/stock_rules.dart';
import '../catalog_messages.dart';
import 'load_montana_view.dart';

const _street = Color(0xFF1E88E5);
const _ink = Color(0xFF1C1C1E);
const _muted = Color(0xFF6B7280);
const _canvas = Color(0xFFF3F5F8);
const _fieldFill = Color(0xFFF3F4F6);

AppBar _operationBar(String title, {Color header = _street}) {
  return AppBar(
    backgroundColor: header,
    foregroundColor: Colors.white,
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
  backgroundColor: Colors.white,
  foregroundColor: accent,
  side: BorderSide(color: accent),
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

InputDecoration _fieldDecoration(
  String label, {
  String? hint,
  Color accent = _street,
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
    this.header = _street,
    this.accent = _street,
  });

  final StockOperationKind kind;
  final Color header;
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
  final _amounts = <String, TextEditingController>{};
  var _loading = true;
  var _saving = false;
  String? _error;
  String? _draftId;
  var _query = '';
  List<CatalogProduct> _products = const [];
  List<ProductStock> _rows = const [];
  final _onMontana = <String, int>{};
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
    for (final amount in _amounts.values) {
      amount.dispose();
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
    for (final amount in _amounts.values) {
      amount.dispose();
    }
    _amounts.clear();
    _onMontana.clear();
    for (final row in snapshot!.products) {
      final onTruck = row.balances[StockLocationCode.montana] ?? 0;
      if (onTruck > 0) _onMontana[row.product.id] = onTruck;
    }
    if (widget.kind == StockOperationKind.load) {
      if (draft!.lines.isNotEmpty) {
        for (final line in draft!.lines) {
          if (line.quantity <= 0) continue;
          final product = byId[line.productId];
          _amounts[line.productId] = TextEditingController(
            text: product == null
                ? '${line.quantity}'
                : editBaseQuantity(product.unit, line.quantity),
          );
        }
      } else {
        for (final entry in _onMontana.entries) {
          final product = byId[entry.key];
          _amounts[entry.key] = TextEditingController(
            text: product == null
                ? '${entry.value}'
                : editBaseQuantity(product.unit, entry.value),
          );
        }
      }
    } else if (draft!.lines.isEmpty) {
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
      _rows = snapshot!.products;
      _location = draft!.location ?? _location;
      _reason.text = draft!.reason ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == StockOperationKind.load) {
      return Scaffold(
        backgroundColor: _canvas,
        appBar: _operationBar(
          stockOperationTitle(widget.kind),
          header: widget.header,
        ),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: widget.accent,
                  semanticsLabel: 'Carregando a movimentação',
                ),
              )
            : _draftId == null
            ? Center(child: Text(_error ?? 'Não foi possível abrir a carga.'))
            : LoadMontanaView(
                accent: widget.accent,
                rows: [
                  for (final row in _rows)
                    if (row.product.active ||
                        _amounts.containsKey(row.product.id))
                      row,
                ],
                amounts: _amounts,
                query: _query,
                onQueryChanged: (value) => setState(() => _query = value),
                onAdd: _addToLoad,
                onStep: _stepLoad,
                onAmountEdited: () => setState(() {}),
                saving: _saving,
                error: _error,
                onConfirm: _confirm,
              ),
      );
    }
    final transfer = widget.kind == StockOperationKind.returnToWarehouse;
    return Scaffold(
      backgroundColor: _canvas,
      appBar: _operationBar(
        stockOperationTitle(widget.kind),
        header: widget.header,
      ),
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

  void _addToLoad(String productId) {
    if (_amounts.containsKey(productId) || _saving) return;
    setState(() {
      _error = null;
      _amounts[productId] = TextEditingController(text: '1');
    });
  }

  void _stepLoad(String productId, int direction) {
    final amount = _amounts[productId];
    final product = _product(productId);
    if (amount == null || product == null || _saving) return;
    final current = parseBaseQuantity(product.unit, amount.text) ?? 0;
    final step = product.unit == CatalogUnit.kilogram ? 1000 : 1;
    final ceiling = _loadCeiling(productId);
    var next = current + direction * step;
    if (next > ceiling) next = ceiling;
    if (next <= 0) {
      setState(() {
        _amounts.remove(productId)?.dispose();
      });
      return;
    }
    amount.text = editBaseQuantity(product.unit, next);
    setState(() => _error = null);
  }

  CatalogProduct? _product(String productId) {
    for (final row in _rows) {
      if (row.product.id == productId) return row.product;
    }
    return null;
  }

  int _available(String productId) {
    for (final row in _rows) {
      if (row.product.id == productId) {
        return row.balances[StockLocationCode.warehouse] ?? 0;
      }
    }
    return 0;
  }

  int _loadCeiling(String productId) {
    return _available(productId) + (_onMontana[productId] ?? 0);
  }

  Future<void> _confirmLoad(String draftId) async {
    final desired = <StockDraftLine>[];
    final seen = <String>{};
    for (final entry in _amounts.entries) {
      final product = _product(entry.key);
      if (product == null) {
        setState(() => _error = 'Escolha o produto.');
        return;
      }
      final quantity = parseBaseQuantity(product.unit, entry.value.text);
      if (quantity == null) {
        setState(() {
          _error = product.unit == CatalogUnit.kilogram
              ? 'Informe o peso em quilos, por exemplo 1,5.'
              : 'Unidade, maço, caixa e dúzia usam quantidade inteira.';
        });
        return;
      }
      if (quantity < 0) continue;
      seen.add(product.id);
      desired.add(StockDraftLine(productId: product.id, quantity: quantity));
    }
    for (final entry in _onMontana.entries) {
      if (seen.contains(entry.key) || entry.value <= 0) continue;
      desired.add(StockDraftLine(productId: entry.key, quantity: 0));
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await sl<CatalogRepository>().adjustMontanaLoad(
      id: draftId,
      desired: desired,
    );
    if (!mounted) return;
    result.fold(
      (failure) {
        final message = catalogFailureMessage(failure);
        if (message == 'A carga da Montana continua igual.') {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop(false);
          messenger.showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        setState(() {
          _saving = false;
          _error = message;
        });
      },
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

  Future<void> _confirm() async {
    final draftId = _draftId;
    if (draftId == null || _saving) return;
    if (widget.kind == StockOperationKind.load) {
      await _confirmLoad(draftId);
      return;
    }
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

class StockOperationDetailPage extends StatefulWidget {
  const StockOperationDetailPage({
    super.key,
    required this.operationId,
    this.header = _street,
  });

  final String operationId;
  final Color header;

  @override
  State<StockOperationDetailPage> createState() =>
      _StockOperationDetailPageState();
}

class _StockOperationDetailPageState extends State<StockOperationDetailPage> {
  var _loading = true;
  String? _error;
  StockOperationRecord? _record;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<CatalogRepository>().stockOperation(
      widget.operationId,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = catalogFailureMessage(failure);
      }),
      (record) => setState(() {
        _loading = false;
        _record = record;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return Scaffold(
      backgroundColor: _canvas,
      appBar: _operationBar(
        record == null ? 'Movimentação' : stockOperationTitle(record.kind),
        header: widget.header,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || record == null
          ? Center(child: Text(_error ?? 'Movimentação não encontrada.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _when(record.occurredOn),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (record.origin != null && record.destination != null)
                  Text(
                    '${locationName(record.origin!)} → ${locationName(record.destination!)}',
                    key: const Key('operation_direction'),
                  ),
                if (record.location != null)
                  Text(
                    locationName(record.location!),
                    key: const Key('operation_location'),
                  ),
                if (record.reason != null) ...[
                  const SizedBox(height: 8),
                  Text(record.reason!, key: const Key('operation_reason')),
                ],
                const SizedBox(height: 16),
                for (final line in record.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Surface(
                      child: ListTile(
                        key: Key('operation_line_${line.productId}'),
                        title: Text(
                          line.productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        subtitle: Text(
                          _lineText(record.kind, line),
                          style: const TextStyle(fontSize: 14, color: _muted),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Esta movimentação não gera venda, dívida, receita ou despesa.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ],
            ),
    );
  }

  String _lineText(StockOperationKind kind, StockOperationLine line) {
    if (kind == StockOperationKind.count) {
      final counted = formatBaseQuantity(line.unit, line.quantity);
      final previous = formatBaseQuantity(
        line.unit,
        line.previousQuantity ?? 0,
      );
      final delta = formatBaseQuantity(line.unit, line.delta ?? 0);
      return 'Contado $counted · saldo anterior $previous · diferença $delta';
    }
    return formatBaseQuantity(line.unit, line.quantity);
  }

  String _when(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _DirectionBanner extends StatelessWidget {
  const _DirectionBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1565C0),
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
            color: Color(0x0F1565C0),
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
