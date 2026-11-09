import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';

import '../../domain/entities/catalog.dart';
import '../../domain/rules/stock_rules.dart';
import '../produce_assets.dart';

const _ink = pouInk;
const _muted = Color(0xFF6B7280);
const _canvas = pouCanvas;
const _green = pouAccent;
const _greenSoft = pouSurface;

class LoadMontanaView extends StatelessWidget {
  const LoadMontanaView({
    super.key,
    required this.rows,
    required this.amounts,
    required this.query,
    required this.onQueryChanged,
    required this.onAdd,
    required this.onStep,
    required this.onAmountEdited,
    required this.saving,
    required this.error,
    required this.onConfirm,
    this.accent = pouInk,
  });

  final Color accent;
  final List<ProductStock> rows;
  final Map<String, TextEditingController> amounts;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onAdd;
  final void Function(String productId, int direction) onStep;
  final VoidCallback onAmountEdited;
  final bool saving;
  final String? error;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final row in rows)
        if (_matches(row, query)) row,
    ];
    final selected = _selected(rows, amounts);
    return ColoredBox(
      color: _canvas,
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Depósito → Montana',
                          key: Key('stock_operation_direction'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _TruckBanner(selected: selected.length),
                        const SizedBox(height: 18),
                        const Text(
                          'Adicionar à carga',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const Key('load_search'),
                          onChanged: onQueryChanged,
                          style: const TextStyle(fontSize: 16, color: _ink),
                          decoration: InputDecoration(
                            hintText: 'Buscar produto',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF9CA3AF),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
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
                              borderSide: BorderSide(color: accent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum produto encontrado.',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            mainAxisExtent: 228,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final row = visible[index];
                        return _ProductCard(
                          row: row,
                          amount: amounts[row.product.id],
                          accent: accent,
                          saving: saving,
                          onAdd: () => onAdd(row.product.id),
                          onStep: (direction) =>
                              onStep(row.product.id, direction),
                          onAmountEdited: onAmountEdited,
                        );
                      }, childCount: visible.length),
                    ),
                  ),
              ],
            ),
          ),
          _Footer(
            selected: selected,
            saving: saving,
            error: error,
            accent: accent,
            onConfirm: onConfirm,
          ),
        ],
      ),
    );
  }
}

bool _matches(ProductStock row, String query) {
  final text = query.trim().toLowerCase();
  if (text.isEmpty) return true;
  return row.product.name.toLowerCase().contains(text);
}

List<({ProductStock row, int quantity})> _selected(
  List<ProductStock> rows,
  Map<String, TextEditingController> amounts,
) {
  final chosen = <({ProductStock row, int quantity})>[];
  for (final row in rows) {
    final amount = amounts[row.product.id];
    if (amount == null) continue;
    final quantity = parseBaseQuantity(row.product.unit, amount.text);
    if (quantity == null || quantity <= 0) continue;
    chosen.add((row: row, quantity: quantity));
  }
  return chosen;
}

class _TruckBanner extends StatelessWidget {
  const _TruckBanner({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context) {
    final label = selected == 1 ? '1 produto' : '$selected produtos';
    return SizedBox(
      height: 188,
      child: Stack(
        children: [
          const Positioned.fill(
            child: Image(
              image: AssetImage('assets/montana.png'),
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 0,
            top: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A0E0D0F),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sua carga',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _greenSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          label,
                          key: const Key('load_cargo_count'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.row,
    required this.amount,
    required this.accent,
    required this.saving,
    required this.onAdd,
    required this.onStep,
    required this.onAmountEdited,
  });

  final ProductStock row;
  final TextEditingController? amount;
  final Color accent;
  final bool saving;
  final VoidCallback onAdd;
  final ValueChanged<int> onStep;
  final VoidCallback onAmountEdited;

  @override
  Widget build(BuildContext context) {
    final product = row.product;
    final selected = amount != null;
    final available = row.balances[StockLocationCode.warehouse] ?? 0;
    final ceiling = available + (row.balances[StockLocationCode.montana] ?? 0);
    final photo = produceAsset(product.name);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? _green : const Color(0xFFE9E8EB),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 78,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: photo == null
                        ? Icon(
                            Icons.inventory_2_outlined,
                            color: accent,
                            size: 28,
                          )
                        : Image.asset(photo, fit: BoxFit.contain),
                  ),
                  if (selected)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(Icons.check_circle, color: _green, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            Text(
              'Saldo no depósito: ${formatBaseQuantity(product.unit, available)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, height: 1.2, color: _muted),
            ),
            const Spacer(),
            if (!selected)
              SizedBox(
                width: double.infinity,
                height: 32,
                child: OutlinedButton(
                  key: Key('load_add_${product.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pouInk,
                    backgroundColor: pouCanvas,
                    side: const BorderSide(color: pouInk),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: saving || available <= 0 ? null : onAdd,
                  child: const Text('Adicionar'),
                ),
              )
            else
              _QuantityStepper(
                product: product,
                amount: amount!,
                available: ceiling,
                saving: saving,
                onStep: onStep,
                onAmountEdited: onAmountEdited,
              ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.product,
    required this.amount,
    required this.available,
    required this.saving,
    required this.onStep,
    required this.onAmountEdited,
  });

  final CatalogProduct product;
  final TextEditingController amount;
  final int available;
  final bool saving;
  final ValueChanged<int> onStep;
  final VoidCallback onAmountEdited;

  @override
  Widget build(BuildContext context) {
    final current = parseBaseQuantity(product.unit, amount.text) ?? 0;
    return Row(
      children: [
        _StepButton(
          key: Key('load_minus_${product.id}'),
          icon: Icons.remove,
          onPressed: saving ? null : () => onStep(-1),
        ),
        Expanded(
          child: TextField(
            key: Key('load_quantity_${product.id}'),
            controller: amount,
            enabled: !saving,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            onChanged: (_) => onAmountEdited(),
          ),
        ),
        _StepButton(
          key: Key('load_plus_${product.id}'),
          icon: Icons.add,
          onPressed: saving || current >= available ? null : () => onStep(1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 26, height: 26),
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: _green),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.selected,
    required this.saving,
    required this.error,
    required this.onConfirm,
    required this.accent,
  });

  final List<({ProductStock row, int quantity})> selected;
  final bool saving;
  final String? error;
  final VoidCallback onConfirm;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final countsOnly =
        selected.isNotEmpty &&
        selected.every((item) => item.row.product.unit != CatalogUnit.kilogram);
    final volumes = selected.fold<int>(0, (sum, item) => sum + item.quantity);
    final products = selected.length == 1
        ? '1 produto selecionado'
        : '${selected.length} produtos selecionados';
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: _green, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      products,
                      key: const Key('load_selected_count'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (countsOnly)
                    Text(
                      volumes == 1 ? '1 volume' : '$volumes volumes',
                      key: const Key('load_volumes'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                ],
              ),
              const Text(
                'Revise a carga antes de sair.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error!,
                  key: const Key('stock_operation_error'),
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('stock_operation_confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: saving ? null : onConfirm,
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(saving ? 'Gravando' : 'Confirmar carregamento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
