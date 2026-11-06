import 'package:flutter/material.dart';

import '../../../../injection_container.dart';
import '../../../assistant/presentation/widgets/voice_mic.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/rules/stock_rules.dart';
import '../../domain/entities/stock_operation.dart';
import '../catalog_messages.dart';
import '../produce_assets.dart';
import 'product_detail_page.dart';
import 'product_form_page.dart';
import 'stock_operation_page.dart';

const _header = Color(0xFF1B3A2F);
const _green = _header;
const _ink = Color(0xFF1C1C1E);
const _muted = Color(0xFF6B7280);
const _canvas = Color(0xFFF3F5F8);

final _primaryButton = FilledButton.styleFrom(
  backgroundColor: _green,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

final _outlineButton = OutlinedButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: _green,
  side: const BorderSide(color: _green),
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _search = TextEditingController();
  var _loading = true;
  String? _error;
  CatalogSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<CatalogRepository>().load();
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = catalogFailureMessage(failure);
      }),
      (snapshot) => setState(() {
        _loading = false;
        _snapshot = snapshot;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final query = _search.text.trim().toLowerCase();
    final rows = [
      if (snapshot != null)
        for (final row in snapshot.products)
          if (query.isEmpty ||
              row.product.name.toLowerCase().contains(query) ||
              (row.product.sku ?? '').toLowerCase().contains(query))
            row,
    ];
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _header,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        title: const Text('Estoque'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando o estoque',
              ),
            )
          : _error != null
          ? _Message(
              text: _error!,
              action: 'Tentar novamente',
              onPressed: _load,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TextField(
                    key: const Key('catalog_search'),
                    controller: _search,
                    style: const TextStyle(fontSize: 16, color: _ink),
                    decoration: InputDecoration(
                      hintText: 'Buscar produto',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF9CA3AF),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _green),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    key: const Key('catalog_list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _stockActions(snapshot)),
                      if (rows.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _Message(
                            text: query.isEmpty
                                ? 'Nenhum produto cadastrado.'
                                : 'Nenhum produto encontrado.',
                            action: query.isEmpty ? 'Cadastrar produto' : null,
                            onPressed: query.isEmpty ? _create : null,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                          sliver: SliverList.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              return _ProductTile(
                                row: row,
                                onTap: () => _open(row.product.id),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButtonLocation: const AboveVoiceMicLocation(),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              key: const Key('register_catalog_product'),
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text(
                'Cadastrar produto',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  Future<void> _create() async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const ProductFormPage()));
    if (saved == true) _load();
  }

  Future<void> _openOperation(StockOperationKind kind) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            StockOperationPage(kind: kind, header: _header, accent: _green),
      ),
    );
    if (changed == true) _load();
  }

  Widget _stockActions(CatalogSnapshot? snapshot) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('action_load'),
              style: _primaryButton,
              onPressed: () => _openOperation(StockOperationKind.load),
              child: const Text('Carregar Montana'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('action_returnToWarehouse'),
              style: _outlineButton,
              onPressed: () =>
                  _openOperation(StockOperationKind.returnToWarehouse),
              child: const Text('Retornar ao depósito'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('action_loss'),
                  style: _outlineButton.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  onPressed: () => _openOperation(StockOperationKind.loss),
                  child: const Text('Registrar perda'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('action_count'),
                  style: _outlineButton.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  onPressed: () => _openOperation(StockOperationKind.count),
                  child: const Text('Conferir estoque'),
                ),
              ),
            ],
          ),
          if (snapshot?.updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Atualizado em ${_clockLabel(snapshot!.updatedAt!)}',
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(String id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductDetailPage(productId: id)),
    );
    if (changed == true) _load();
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.row, required this.onTap});

  final ProductStock row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = row.product;
    final where = [
      for (final location in StockLocationCode.values)
        if ((row.balances[location] ?? 0) != 0)
          '${locationName(location)} ${formatBaseQuantity(product.unit, row.balances[location]!)}',
    ];
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
        child: InkWell(
          key: Key('stock_${product.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _StockPhoto(name: product.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                          ),
                          Text(
                            formatBaseQuantity(product.unit, row.total),
                            key: Key('stock_total_${product.id}'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        where.isEmpty ? 'Sem saldo' : where.join(' · '),
                        style: const TextStyle(fontSize: 14, color: _muted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _Badge(
                            label: product.active ? 'Ativo' : 'Inativo',
                            background: product.active
                                ? const Color(0xFFD8F5E4)
                                : const Color(0xFFE5E7EB),
                            foreground: product.active
                                ? const Color(0xFF146C43)
                                : const Color(0xFF4B5563),
                          ),
                          if (row.low)
                            const _Badge(
                              label: 'Estoque baixo',
                              background: Color(0xFFFFF3D6),
                              foreground: Color(0xFF8A5A00),
                            ),
                          Text(
                            formatReais(product.salePriceCents),
                            style: const TextStyle(fontSize: 14, color: _ink),
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
      ),
    );
  }
}

class _StockPhoto extends StatelessWidget {
  const _StockPhoto({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final asset = produceAsset(name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: const Color(0xFFF7F8FA),
        child: SizedBox(
          width: 64,
          height: 64,
          child: asset == null
              ? const Icon(Icons.inventory_2_outlined, color: _muted)
              : Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onPressed});

  final String text;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onPressed, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _clockLabel(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} $hour:$minute';
}
