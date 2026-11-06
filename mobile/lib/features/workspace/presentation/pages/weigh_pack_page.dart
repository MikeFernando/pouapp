import 'package:flutter/material.dart';

import '../../../../injection_container.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/domain/rules/stock_rules.dart';
import '../../../catalog/domain/rules/weigh_rules.dart';
import '../../../catalog/presentation/catalog_messages.dart';
import '../../../catalog/presentation/produce_assets.dart';

const _ink = Color(0xFF16342C);
const _muted = Color(0xFF6B7280);
const _green = Color(0xFF1F8A4C);
const _canvas = Color(0xFFF3F6F4);
const _line = Color(0xFFE4EBE6);

const _packChoices = <int>[500, 1000, 2500, 5000];

class WeighProductsPage extends StatefulWidget {
  const WeighProductsPage({super.key});

  @override
  State<WeighProductsPage> createState() => _WeighProductsPageState();
}

class _WeighProductsPageState extends State<WeighProductsPage> {
  var _loading = true;
  String? _error;
  List<ProductStock> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<CatalogRepository>().load();
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = catalogFailureMessage(failure);
      }),
      (snapshot) => setState(() {
        _loading = false;
        _error = null;
        _rows = [
          for (final row in snapshot.products)
            if (row.product.active && row.product.unit == CatalogUnit.kilogram)
              row,
        ];
      }),
    );
  }

  Future<void> _open(ProductStock row) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WeighPackPage(productId: row.product.id),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: _weighBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Text(
                  'Escolha a mercadoria a granel.',
                  style: TextStyle(color: _muted, fontSize: 14),
                ),
                const SizedBox(height: 12),
                for (final row in _rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProductTile(row: row, onTap: () => _open(row)),
                  ),
              ],
            ),
    );
  }
}

class WeighPackPage extends StatefulWidget {
  const WeighPackPage({super.key, required this.productId});

  final String productId;

  @override
  State<WeighPackPage> createState() => _WeighPackPageState();
}

class _WeighPackPageState extends State<WeighPackPage> {
  var _loading = true;
  String? _error;
  ProductStock? _row;
  var _packGrams = 2500;
  var _count = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<CatalogRepository>().getProduct(widget.productId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = catalogFailureMessage(failure);
      }),
      (row) => setState(() {
        _loading = false;
        _row = row;
        _error = null;
      }),
    );
  }

  int get _warehouse => _row?.balances[StockLocationCode.warehouse] ?? 0;

  int get _separated => _packGrams * _count;

  bool get _fits => _count > 0 && _separated <= _warehouse;

  void _setCount(int next) {
    if (next < 0) return;
    setState(() => _count = next);
  }

  Future<void> _confirm() async {
    final row = _row;
    if (row == null) return;
    if (_count <= 0) {
      setState(() => _error = 'Informe a quantidade de embalagens.');
      return;
    }
    if (_separated > _warehouse) {
      setState(() {
        _error =
            'O depósito tem ${formatBaseQuantity(row.product.unit, _warehouse)}.';
      });
      return;
    }
    setState(() => _error = null);
    final saved = await sl<CatalogRepository>().recordWeighing(
      productId: row.product.id,
      packGrams: _packGrams,
      packageCount: _count,
      warehouseGrams: _warehouse,
    );
    if (!mounted) return;
    final failure = saved.fold((error) => error, (_) => null);
    if (failure != null) {
      setState(() => _error = catalogFailureMessage(failure));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Pesagem conferida. A carga da Montana é confirmada na próxima etapa.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    return Scaffold(
      backgroundColor: _canvas,
      appBar: _weighBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : row == null
          ? Center(child: Text(_error ?? 'Produto não encontrado.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _Surface(
                  child: Row(
                    children: [
                      _Thumb(name: row.product.name),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          row.product.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('weigh_change_product'),
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(foregroundColor: _green),
                        child: const Text(
                          'Trocar produto',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _WarehouseCard(row: row, warehouse: _warehouse),
                const SizedBox(height: 18),
                const Text(
                  'Preparar embalagens',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Labeled(
                        label: 'Peso por embalagem',
                        child: DropdownButtonFormField<int>(
                          key: const Key('weigh_pack_weight'),
                          initialValue: _packGrams,
                          decoration: _fieldDecoration(),
                          items: [
                            for (final grams in _packChoices)
                              DropdownMenuItem(
                                value: grams,
                                child: Text(
                                  formatBaseQuantity(
                                    CatalogUnit.kilogram,
                                    grams,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _packGrams = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Labeled(
                        label: 'Quantidade de embalagens',
                        child: _Stepper(
                          count: _count,
                          onMinus: () => _setCount(_count - 1),
                          onPlus: () => _setCount(_count + 1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total a separar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                    Text(
                      formatBaseQuantity(row.product.unit, _separated),
                      key: const Key('weigh_separated_total'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ReadyCard(
                  name: row.product.name,
                  packGrams: _packGrams,
                  count: _count,
                ),
                const SizedBox(height: 12),
                _Summary(
                  label: 'A granel após confirmar',
                  value: formatBaseQuantity(
                    row.product.unit,
                    _warehouse - _separated,
                  ),
                  valueKey: const Key('weigh_bulk_after'),
                ),
                const SizedBox(height: 8),
                _Summary(
                  label: 'Separado para entrega',
                  value: formatBaseQuantity(row.product.unit, _separated),
                  valueKey: const Key('weigh_separated'),
                  emphasize: true,
                ),
                if (!_fits) ...[
                  const SizedBox(height: 10),
                  Text(
                    _count <= 0
                        ? 'Informe a quantidade de embalagens.'
                        : 'O depósito tem ${formatBaseQuantity(row.product.unit, _warehouse)}.',
                    key: const Key('weigh_error'),
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('weigh_confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _fits ? _confirm : null,
                  child: const Text('Confirmar pesagem'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A carga da Montana é confirmada na próxima etapa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
    );
  }
}

AppBar _weighBar() {
  return AppBar(
    backgroundColor: Colors.white,
    foregroundColor: _ink,
    elevation: 0,
    surfaceTintColor: Colors.white,
    title: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pesar e embalar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        Text(
          'Do depósito para a Montana',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _green,
          ),
        ),
      ],
    ),
  );
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.row, required this.onTap});

  final ProductStock row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warehouse = row.balances[StockLocationCode.warehouse] ?? 0;
    return _Surface(
      child: InkWell(
        key: Key('weigh_product_${row.product.id}'),
        onTap: onTap,
        child: Row(
          children: [
            _Thumb(name: row.product.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Depósito ${formatBaseQuantity(row.product.unit, warehouse)}',
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.row, required this.warehouse});

  final ProductStock row;
  final int warehouse;

  @override
  Widget build(BuildContext context) {
    final potato = _isPotato(row.product.name);
    final sacks = warehouseSacks(warehouse);
    final loose = looseBulkGrams(warehouse);
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL NO DEPÓSITO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatBaseQuantity(row.product.unit, warehouse),
                      key: const Key('weigh_warehouse_total'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const Text(
                      'Antes desta pesagem',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 12),
                    for (final sack in sacks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                              color: _green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sackLabel(sack),
                              key: Key('weigh_sack_${sack.kilograms}'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (loose > 0)
                      Text(
                        '${formatBaseQuantity(CatalogUnit.kilogram, loose)} fora dos sacos de 25 kg e 50 kg',
                        key: const Key('weigh_loose'),
                        style: const TextStyle(color: _muted, fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (potato)
                const SizedBox(
                  width: 150,
                  height: 120,
                  child: Image(
                    key: Key('weigh_pallet_image'),
                    image: AssetImage('assets/batata-palete.png'),
                    fit: BoxFit.contain,
                  ),
                ),
            ],
          ),
          if (potato) ...[
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Mercadoria a granel • armazenada em palete',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({
    required this.name,
    required this.packGrams,
    required this.count,
  });

  final String name;
  final int packGrams;
  final int count;

  @override
  Widget build(BuildContext context) {
    final potatoPack = _isPotato(name) && packGrams == 2500;
    final packages = count == 1 ? 'embalagem' : 'embalagens';
    final weight = formatBaseQuantity(CatalogUnit.kilogram, packGrams);
    return _Surface(
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pronto para entrega',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          if (potatoPack) ...[
            const SizedBox(height: 8),
            const Image(
              key: Key('weigh_packed_image'),
              image: AssetImage('assets/batata-pesada.png'),
              height: 150,
              fit: BoxFit.contain,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '$count $packages de $weight',
            key: const Key('weigh_pack_caption'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const Text(
            'Prévia da apresentação do produto',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.count,
    required this.onMinus,
    required this.onPlus,
  });

  final int count;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              key: const Key('weigh_minus'),
              onPressed: count == 0 ? null : onMinus,
              icon: const Icon(Icons.remove),
              color: _green,
            ),
            Expanded(
              child: Text(
                '$count',
                key: const Key('weigh_count'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            IconButton(
              key: const Key('weigh_plus'),
              onPressed: onPlus,
              icon: const Icon(Icons.add),
              color: _green,
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    required this.valueKey,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Key valueKey;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          Text(
            value,
            key: valueKey,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: emphasize ? _green : _ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 6),
        child,
      ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final asset = produceAsset(name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: const Color(0xFFF7F7F7),
        child: SizedBox(
          width: 56,
          height: 56,
          child: asset == null
              ? const Icon(Icons.inventory_2_outlined, color: _green)
              : Image(image: AssetImage(asset), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _line),
    ),
  );
}

bool _isPotato(String name) => name.toLowerCase().contains('batata');
