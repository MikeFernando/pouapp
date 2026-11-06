import 'package:flutter/material.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/rules/stock_rules.dart';
import '../catalog_messages.dart';

const _header = Color(0xFF1B3A2F);
const _ink = Color(0xFF1C1C1E);
const _muted = Color(0xFF6B7280);
const _canvas = Color(0xFFF3F5F8);
const _fieldFill = Color(0xFFF7F8FA);

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController();
  final _minimum = TextEditingController();
  var _unit = CatalogUnit.kilogram;
  var _location = StockLocationCode.warehouse;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _price.dispose();
    _quantity.dispose();
    _minimum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kilos = _unit == CatalogUnit.kilogram;
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
        title: const Text('Novo produto'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _Intro(),
          const SizedBox(height: 22),
          const _SectionTitle(
            icon: Icons.inventory_2_outlined,
            title: 'Produto',
          ),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              children: [
                _field(
                  _name,
                  'Nome',
                  hint: 'Ex.: Alho, cebola, batata',
                  key: const Key('catalog_product_name'),
                ),
                const SizedBox(height: 14),
                _field(
                  _category,
                  'Categoria',
                  hint: 'Hortifruti, verdura, fruta',
                  key: const Key('catalog_product_category'),
                ),
                const SizedBox(height: 14),
                _ChoiceBlock(
                  label: 'Unidade de venda',
                  fieldKey: const Key('catalog_product_unit'),
                  children: [
                    for (final unit in const [
                      (CatalogUnit.kilogram, 'Quilograma'),
                      (CatalogUnit.piece, 'Unidade'),
                      (CatalogUnit.bunch, 'Maço'),
                      (CatalogUnit.dozen, 'Dúzia'),
                    ])
                      _Choice(
                        label: unit.$2,
                        selected: _unit == unit.$1,
                        onTap: _saving
                            ? null
                            : () => setState(() => _unit = unit.$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle(
            icon: Icons.payments_outlined,
            title: 'Preço e estoque',
          ),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              children: [
                _field(
                  _price,
                  'Preço de venda',
                  hint: '0,00',
                  prefix: 'R\$',
                  key: const Key('catalog_product_price'),
                  number: true,
                ),
                const SizedBox(height: 14),
                _ChoiceBlock(
                  label: 'Onde está esse saldo',
                  fieldKey: const Key('catalog_product_location'),
                  children: [
                    for (final location in stockLocations)
                      _Choice(
                        label: location.name,
                        selected: _location == location.code,
                        onTap: _saving
                            ? null
                            : () => setState(() => _location = location.code),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        _quantity,
                        kilos ? 'Saldo inicial (kg)' : 'Saldo inicial',
                        hint: kilos ? '1,5' : '0',
                        key: const Key('catalog_product_quantity'),
                        number: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _minimum,
                        kilos ? 'Mínimo (kg)' : 'Mínimo',
                        hint: 'Opcional',
                        key: const Key('catalog_product_minimum'),
                        number: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorNote(message: _error!),
          ],
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x141B3A2F),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: FilledButton(
              key: const Key('catalog_product_save'),
              style: FilledButton.styleFrom(
                backgroundColor: _header,
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
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando...' : 'Salvar produto'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required Key key,
    String? hint,
    String? prefix,
    bool number = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: key,
          controller: controller,
          enabled: !_saving,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          textCapitalization: number
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          style: const TextStyle(fontSize: 16, color: _ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixText: prefix == null ? null : '$prefix ',
            prefixStyle: const TextStyle(
              color: _header,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: _fieldFill,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: _border(BorderSide.none),
            enabledBorder: _border(BorderSide.none),
            focusedBorder: _border(const BorderSide(color: _header)),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(BorderSide side) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: side,
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe o nome do produto.');
      return;
    }
    final price = parseReaisToCents(_price.text);
    final quantity = parseBaseQuantity(_unit, _quantity.text);
    final minimumText = _minimum.text.trim();
    final minimum = minimumText.isEmpty
        ? null
        : parseBaseQuantity(_unit, minimumText);
    if (price == null) {
      setState(() => _error = 'Informe o preço em reais.');
      return;
    }
    if (quantity == null || (minimumText.isNotEmpty && minimum == null)) {
      setState(() {
        _error = _unit == CatalogUnit.kilogram
            ? 'Informe o peso em kg. Exemplo: 1,5.'
            : 'Unidade e maço usam quantidade inteira.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await sl<CatalogRepository>().createProduct(
      ProductDraft(
        name: name,
        category: _category.text,
        unit: _unit,
        salePriceCents: price,
        openingLocation: _location,
        openingQuantity: quantity,
        minimumQuantity: minimumText.isEmpty ? null : minimum,
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
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFE7F2EC),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.scale_outlined, color: _header),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O que já está no local',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'O saldo inicial não é uma compra e não entra como venda.',
                  style: TextStyle(fontSize: 13, height: 1.35, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _header),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
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

class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({
    required this.label,
    required this.fieldKey,
    required this.children,
  });

  final String label;
  final Key fieldKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(key: fieldKey, spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _header : _fieldFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB42318),
          ),
        ),
      ),
    );
  }
}
