import 'package:flutter/material.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/rules/stock_rules.dart';
import '../catalog_messages.dart';
import 'stock_operation_page.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  var _loading = true;
  var _saving = false;
  String? _error;
  ProductStock? _stock;
  List<StockMovement> _movements = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repository = sl<CatalogRepository>();
    final result = await repository.getProduct(widget.productId);
    final history = await repository.productMovements(widget.productId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = catalogFailureMessage(failure);
      }),
      (stock) => setState(() {
        _loading = false;
        _stock = stock;
        history.fold((_) {}, (movements) => _movements = movements);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = _stock;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2F),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        title: Text(stock?.product.name ?? 'Produto'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando o produto',
              ),
            )
          : _error != null || stock == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error ?? 'Produto não encontrado.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  formatBaseQuantity(stock.product.unit, stock.total),
                  key: const Key('product_total'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stock.low ? 'Estoque baixo' : 'Saldo físico',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Por local',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final location in stockLocations)
                  Card(
                    child: ListTile(
                      title: Text(location.name),
                      subtitle: stock.product.minimums[location.code] == null
                          ? null
                          : Text(
                              'Mínimo ${formatBaseQuantity(stock.product.unit, stock.product.minimums[location.code]!)}',
                            ),
                      trailing: Text(
                        formatBaseQuantity(
                          stock.product.unit,
                          stock.balances[location.code] ?? 0,
                        ),
                        key: Key('balance_${location.code.name}'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Preço de venda'),
                  trailing: Text(formatReais(stock.product.salePriceCents)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Situação'),
                  trailing: Text(stock.product.active ? 'Ativo' : 'Inativo'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Histórico',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_movements.isEmpty)
                  const Text(
                    'Nenhuma movimentação confirmada.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  )
                else
                  for (final movement in _movements.reversed)
                    Card(
                      child: ListTile(
                        key: Key('history_${movement.id}'),
                        title: Text(
                          '${movementKindLabel(movement.kind)} · ${formatBaseQuantity(stock.product.unit, movement.quantity)}',
                        ),
                        subtitle: Text(
                          [
                            locationName(movement.location),
                            _dayLabel(movement.occurredOn),
                            if (movement.reason != null) movement.reason!,
                          ].join(' · '),
                        ),
                        trailing: movement.operationId == null
                            ? null
                            : const Icon(Icons.chevron_right),
                        onTap: movement.operationId == null
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => StockOperationDetailPage(
                                      operationId: movement.operationId!,
                                      header: const Color(0xFF1B3A2F),
                                    ),
                                  ),
                                );
                              },
                      ),
                    ),
                const SizedBox(height: 12),
                const Text(
                  'O saldo vem dos lançamentos confirmados. Ver o produto não altera o estoque.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const Key('toggle_product_active'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B3A2F),
                    side: const BorderSide(color: Color(0xFF1B3A2F)),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _saving ? null : () => _toggle(stock),
                  child: Text(
                    stock.product.active
                        ? 'Inativar produto'
                        : 'Reativar produto',
                  ),
                ),
              ],
            ),
    );
  }

  String _dayLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _toggle(ProductStock stock) async {
    setState(() => _saving = true);
    final result = await sl<CatalogRepository>().setActive(
      id: stock.product.id,
      active: !stock.product.active,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = catalogFailureMessage(failure);
      }),
      (updated) => setState(() {
        _saving = false;
        _stock = updated;
      }),
    );
    if (result.isRight()) {
      Navigator.of(context).pop(true);
    }
  }
}
