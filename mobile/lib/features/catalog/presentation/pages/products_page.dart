import 'package:flutter/material.dart';

import '../../../../app/pou_alphabet_index.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../app/pou_item_edit_sheet.dart';
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
  String? _filterLetter;
  var _scrubbing = false;

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

  Future<void> _edit(CatalogProduct product) async {
    final result = await showPouItemEditSheet(
      context,
      name: product.name,
      unitPriceCents: product.salePriceCents,
      allowRemove: true,
      showAvailability: true,
      available: product.active,
      removeTitle: 'Remover produto',
      removeMessage: 'Remover ${product.name} do catálogo?',
      removeButtonKey: Key('remove_product_${product.id}'),
      confirmRemoveKey: Key('confirm_remove_product_${product.id}'),
    );
    if (result == null || !mounted) return;
    if (result.removed) {
      await _delete(product);
      return;
    }
    final catalog = sl<CatalogRepository>();
    final saved = await catalog.setSalePrice(
      id: product.id,
      salePriceCents: result.unitPriceCents,
    );
    if (!mounted) return;
    final priceFailed = saved.fold((failure) {
      _tell(catalogFailureMessage(failure));
      return true;
    }, (_) => false);
    if (priceFailed) return;
    if (result.available != product.active) {
      final toggled = await catalog.setActive(
        id: product.id,
        active: result.available,
      );
      if (!mounted) return;
      toggled.fold(
        (failure) => _tell(catalogFailureMessage(failure)),
        (_) => _load(silent: true),
      );
      return;
    }
    await _load(silent: true);
  }

  Future<void> _addProduct() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const _NewProductSheet(),
    );
    if (created == true && mounted) await _load(silent: true);
  }

  void _tell(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  List<ProductStock> _filteredProducts() {
    final query = _search.text.trim().toLowerCase();
    final letter = _filterLetter;
    final rows = [
      for (final row in _snapshot?.products ?? const <ProductStock>[])
        if ((query.isEmpty ||
                row.product.name.toLowerCase().contains(query) ||
                _sku(row.product).toLowerCase().contains(query)) &&
            (letter == null ||
                pouAlphabetInitial(row.product.name) == letter))
          row,
    ]..sort(
      (a, b) => a.product.name.toLowerCase().compareTo(
        b.product.name.toLowerCase(),
      ),
    );
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts();
    return ColoredBox(
      color: pouCanvas,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
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
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                key: const Key('product_add'),
                heroTag: 'product_add',
                tooltip: 'Novo produto',
                backgroundColor: pouInk,
                foregroundColor: Colors.white,
                onPressed: _addProduct,
                child: const Icon(Icons.add),
              ),
            ),
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
    final hasSource = (_snapshot?.products ?? const <ProductStock>[]).isNotEmpty;
    if (!hasSource) {
      return const Center(child: Text('Nenhum produto encontrado.'));
    }
    return Stack(
      children: [
        if (products.isEmpty)
          Center(
            child: Text(
              _filterLetter == null
                  ? 'Nenhum produto encontrado.'
                  : 'Nenhum produto com a letra $_filterLetter.',
              key: const Key('products_letter_empty'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          )
        else
          ListView.separated(
            key: const Key('products_list'),
            padding: const EdgeInsets.fromLTRB(16, 0, 28, 88),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final row = products[index];
              return _ProductCard(
                row: row,
                onToggle: () => _setAvailable(row.product, !row.product.active),
                onDelete: () => _delete(row.product),
                onEdit: () => _edit(row.product),
              );
            },
          ),
        Positioned(
          key: const Key('products_alphabet'),
          right: 0,
          top: 0,
          bottom: 72,
          child: PouAlphabetIndex(
            keyPrefix: 'products',
            activeLetter: _filterLetter,
            scrubbing: _scrubbing,
            onDragLetter: _setLetter,
            onTapLetter: _tapLetter,
            onDragEnd: _endScrub,
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.row,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  final ProductStock row;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _EditPill(
                    key: Key('product_edit_${product.id}'),
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(height: 8),
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

class _EditPill extends StatelessWidget {
  const _EditPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            'Editar',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A6A00),
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

class _NewProductSheet extends StatefulWidget {
  const _NewProductSheet();

  @override
  State<_NewProductSheet> createState() => _NewProductSheetState();
}

class _NewProductSheetState extends State<_NewProductSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  var _unit = CatalogUnit.kilogram;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe o nome do produto.');
      return;
    }
    final price = parseReaisToCents(_price.text);
    if (price == null) {
      setState(() => _error = 'Informe um preço válido.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await sl<CatalogRepository>().createProduct(
      ProductDraft(
        name: name,
        unit: _unit,
        salePriceCents: price,
        openingLocation: StockLocationCode.warehouse,
        openingQuantity: 0,
      ),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = catalogFailureMessage(failure);
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E7EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Novo produto',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: pouInk,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('new_product_name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration('Nome'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CatalogUnit>(
                key: const Key('new_product_unit'),
                initialValue: _unit,
                isDense: true,
                iconSize: 20,
                decoration: _fieldDecoration('Unidade'),
                items: [
                  for (final unit in CatalogUnit.values)
                    DropdownMenuItem(
                      value: unit,
                      child: Text(_unitLabel(unit)),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _unit = value);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('new_product_price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saving ? null : _save(),
                decoration: _fieldDecoration('Preço').copyWith(
                  prefixText: 'R\$ ',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFC62828),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: FilledButton(
                  key: const Key('new_product_save'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Salvando…' : 'Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF6F5F7),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    ),
  );
}

String _unitLabel(CatalogUnit unit) {
  return switch (unit) {
    CatalogUnit.kilogram => 'Quilo (kg)',
    CatalogUnit.piece => 'Unidade',
    CatalogUnit.bunch => 'Maço',
    CatalogUnit.box => 'Caixa',
    CatalogUnit.dozen => 'Dúzia',
  };
}
