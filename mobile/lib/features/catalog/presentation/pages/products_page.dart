import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/rules/stock_rules.dart';
import '../catalog_messages.dart';
import '../produce_assets.dart';

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

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
        _snapshot = snapshot;
      }),
    );
  }

  Future<void> _setAvailable(CatalogProduct product, bool active) async {
    final result = await sl<CatalogRepository>().setActive(
      id: product.id,
      active: active,
    );
    if (!mounted) return;
    result.fold(
      (failure) => _tell(catalogFailureMessage(failure)),
      (_) => _load(silent: true),
    );
  }

  Future<void> _delete(CatalogProduct product) async {
    final result = await sl<CatalogRepository>().deleteProduct(product.id);
    if (!mounted) return;
    result.fold(
      (failure) => _tell(catalogFailureMessage(failure)),
      (_) => _load(silent: true),
    );
  }

  void _tell(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final products = [
      for (final row in _snapshot?.products ?? const <ProductStock>[])
        if (query.isEmpty ||
            row.product.name.toLowerCase().contains(query) ||
            _sku(row.product).toLowerCase().contains(query))
          row,
    ];
    return ColoredBox(
      color: pouCanvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                key: const Key('products_search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar produto',
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
                ),
              ),
            ),
            Expanded(child: _body(products)),
          ],
        ),
      ),
    );
  }

  Widget _body(List<ProductStock> products) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: pouInk,
          semanticsLabel: 'Carregando os produtos',
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }
    if (products.isEmpty) {
      return const Center(child: Text('Nenhum produto encontrado.'));
    }
    return ListView.separated(
      key: const Key('products_list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final row = products[index];
        return _ProductCard(
          row: row,
          onToggle: () => _setAvailable(row.product, !row.product.active),
          onDelete: () => _delete(row.product),
        );
      },
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.row,
    required this.onToggle,
    required this.onDelete,
  });

  final ProductStock row;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  static const _reveal = 210.0;
  var _offset = 0.0;
  var _dragging = false;

  void _close() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) {
    final product = widget.row.product;
    final unavailable = !product.active;
    final titleColor = unavailable ? const Color(0xFF6B7280) : pouInk;
    final detailColor = unavailable
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
    final photo = _Photo(name: product.name);
    final card = Material(
      color: unavailable ? const Color(0xFFE4E4E7) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Opacity(
          opacity: unavailable ? 0.55 : 1,
          child: Row(
            children: [
              unavailable
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.matrix(_gray),
                      child: photo,
                    )
                  : photo,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _ActiveBadge(active: product.active),
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${_sku(product)}',
                      style: TextStyle(fontSize: 13, color: detailColor),
                    ),
                    Text(
                      'Estoque: ${formatBaseQuantity(product.unit, widget.row.total)}',
                      style: TextStyle(fontSize: 13, color: detailColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatReais(product.salePriceCents),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                const Spacer(),
                SizedBox(
                  width: _reveal,
                  child: Row(
                    children: [
                      _ProductAction(
                        key: Key('product_toggle_${product.id}'),
                        label: unavailable ? 'Disponível' : 'Indisponível',
                        color: unavailable
                            ? const Color(0xFF146C43)
                            : const Color(0xFF6B7280),
                        onTap: () {
                          _close();
                          widget.onToggle();
                        },
                      ),
                      _ProductAction(
                        key: Key('product_delete_${product.id}'),
                        label: 'Excluir',
                        color: const Color(0xFFC62828),
                        onTap: () {
                          _close();
                          widget.onDelete();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (details) {
              setState(() {
                _offset = (_offset + details.delta.dx).clamp(-_reveal, 0);
              });
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final open =
                  velocity < -300 ||
                  (velocity <= 300 && _offset < -_reveal / 2);
              setState(() {
                _dragging = false;
                _offset = open ? -_reveal : 0;
              });
            },
            child: AnimatedContainer(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              transform: Matrix4.translationValues(_offset, 0, 0),
              child: card,
            ),
          ),
        ],
      ),
    );
  }
}

const _gray = <double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

class _ProductAction extends StatelessWidget {
  const _ProductAction({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD8F5E4) : const Color(0xFFE5E7EB),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          active ? 'Ativo' : 'Indisponível',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? const Color(0xFF146C43) : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final photo = produceAsset(name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: const Color(0xFFF7F8FA),
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

String _sku(CatalogProduct product) {
  final sku = product.sku?.trim();
  if (sku != null && sku.isNotEmpty) return sku.toUpperCase();
  return product.id.replaceFirst('product-', '').toUpperCase();
}
