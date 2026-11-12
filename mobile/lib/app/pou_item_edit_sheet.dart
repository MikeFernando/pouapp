import 'package:flutter/material.dart';

import '../features/catalog/presentation/produce_assets.dart';
import '../features/workspace/presentation/street_input.dart';
import 'pou_app_colors.dart';
import 'pou_confirm_dialog.dart';

class PouItemEditResult {
  const PouItemEditResult({
    required this.unitPriceCents,
    this.quantity = 1,
    this.available = true,
  }) : removed = false;

  const PouItemEditResult.removed()
      : quantity = 0,
        unitPriceCents = 0,
        available = true,
        removed = true;

  final double quantity;
  final int unitPriceCents;
  final bool available;
  final bool removed;
}

Future<PouItemEditResult?> showPouItemEditSheet(
  BuildContext context, {
  required String name,
  required int unitPriceCents,
  double quantity = 1,
  int? referencePriceCents,
  bool allowRemove = false,
  bool showAvailability = false,
  bool available = true,
  String removeTitle = 'Remover item',
  String? removeMessage,
  Key removeButtonKey = const Key('remove_item'),
  Key confirmRemoveKey = const Key('confirm_remove_item'),
}) {
  return showModalBottomSheet<PouItemEditResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => PouItemEditSheet(
      name: name,
      quantity: quantity,
      unitPriceCents: unitPriceCents,
      referencePriceCents: referencePriceCents,
      allowRemove: allowRemove,
      showAvailability: showAvailability,
      available: available,
      removeTitle: removeTitle,
      removeMessage: removeMessage,
      removeButtonKey: removeButtonKey,
      confirmRemoveKey: confirmRemoveKey,
    ),
  );
}

class PouItemEditSheet extends StatefulWidget {
  const PouItemEditSheet({
    super.key,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
    this.referencePriceCents,
    this.allowRemove = false,
    this.showAvailability = false,
    this.available = true,
    this.removeTitle = 'Remover item',
    this.removeMessage,
    this.removeButtonKey = const Key('remove_item'),
    this.confirmRemoveKey = const Key('confirm_remove_item'),
  });

  final String name;
  final double quantity;
  final int unitPriceCents;

  /// Catalog / table price kept when this sheet only adjusts a note discount.
  final int? referencePriceCents;
  final bool allowRemove;
  final bool showAvailability;
  final bool available;
  final String removeTitle;
  final String? removeMessage;
  final Key removeButtonKey;
  final Key confirmRemoveKey;

  @override
  State<PouItemEditSheet> createState() => _PouItemEditSheetState();
}

class _PouItemEditSheetState extends State<PouItemEditSheet> {
  late var _quantity = widget.quantity;
  late var _unavailable = !widget.available;
  late final _priceFocus = FocusNode();
  late final _priceController = TextEditingController(
    text: formatBrlCentsInput(widget.unitPriceCents),
  );
  var _error = false;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _priceFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _priceFocus.dispose();
    _priceController.dispose();
    super.dispose();
  }

  int get _displayedPriceCents {
    return _parsePriceCents(_priceController.text) ?? widget.unitPriceCents;
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final saveLabel = widget.allowRemove
        ? 'Salvar'
        : 'Adicionar por ${_formatBrl(_displayedPriceCents)}';
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
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
                  Row(
                    children: [
                      _Photo(name: widget.name),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.allowRemove)
                        TextButton(
                          key: widget.removeButtonKey,
                          onPressed: _remove,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFB42318),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Remover'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.showAvailability)
                    Material(
                      color: const Color(0xFFF6F5F7),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile.adaptive(
                        key: const Key('item_unavailable'),
                        value: _unavailable,
                        onChanged: (value) =>
                            setState(() => _unavailable = value),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        title: const Text(
                          'Indisponível',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: pouInk,
                          ),
                        ),
                        activeThumbColor: Colors.white,
                        activeTrackColor: pouBrand,
                      ),
                    )
                  else ...[
                    const Text(
                      'Quantidade',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F5F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _StepButton(
                            key: const Key('item_quantity_minus'),
                            icon: Icons.remove,
                            enabled: _quantity > 1,
                            onPressed: () => _changeQuantity(-1),
                          ),
                          Expanded(
                            child: Text(
                              _quantity
                                  .toStringAsFixed(1)
                                  .replaceAll('.', ','),
                              key: const Key('item_quantity'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StepButton(
                            key: const Key('item_quantity_plus'),
                            icon: Icons.add,
                            onPressed: () => _changeQuantity(1),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('item_price'),
                    controller: _priceController,
                    focusNode: _priceFocus,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [BrlCentsInputFormatter()],
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: widget.referencePriceCents != null
                          ? 'Preço nesta nota'
                          : 'Preço',
                      labelStyle: const TextStyle(fontSize: 14),
                      prefixText: 'R\$ ',
                      prefixStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0E0D0F),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF6F5F7),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
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
                        borderSide: const BorderSide(color: pouAppBlue),
                      ),
                    ),
                  ),
                  if (widget.referencePriceCents != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tabela ${_formatBrl(widget.referencePriceCents!)}'
                      ' · altera só nesta nota',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                  if (_error) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Informe um preço válido.',
                      style: TextStyle(fontSize: 14, color: Color(0xFFC62828)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  key: const Key('item_save'),
                  onPressed: _save,
                  child: Text(saveLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove() async {
    final confirmed = await showPouConfirmDialog(
      context,
      title: widget.removeTitle,
      message: widget.removeMessage ?? 'Remover ${widget.name}?',
      confirmLabel: 'Remover',
      cancelLabel: 'Cancelar',
      icon: Icons.delete_outline_rounded,
      confirmKey: widget.confirmRemoveKey,
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).pop(const PouItemEditResult.removed());
  }

  void _changeQuantity(double delta) {
    final next = _quantity + delta;
    if (next < 1) return;
    setState(() => _quantity = next);
  }

  void _save() {
    final price = _parsePriceCents(_priceController.text);
    if (price == null) {
      setState(() => _error = true);
      return;
    }
    Navigator.of(context).pop(
      PouItemEditResult(
        quantity: _quantity,
        unitPriceCents: price,
        available: !_unavailable,
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      color: pouAppBlue,
      disabledColor: const Color(0xFFB0B7C3),
      iconSize: 22,
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
        color: const Color(0xFFE9E8EB),
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

int? _parsePriceCents(String raw) => parseBrlToCents(raw);

String _formatBrl(int cents) {
  final negative = cents < 0;
  final value = cents.abs();
  final whole = value ~/ 100;
  final fraction = (value % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    if (index > 0 && remaining % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}R\$ $buffer,$fraction';
}
