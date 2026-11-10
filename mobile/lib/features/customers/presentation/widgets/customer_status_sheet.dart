import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';
import '../../domain/entities/customer.dart';
import '../customer_messages.dart';

Future<CustomerStatus?> showCustomerStatusSheet(
  BuildContext context, {
  required CustomerStatus current,
}) {
  return showModalBottomSheet<CustomerStatus>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _CustomerStatusSheet(current: current),
  );
}

class _CustomerStatusSheet extends StatefulWidget {
  const _CustomerStatusSheet({required this.current});

  final CustomerStatus current;

  @override
  State<_CustomerStatusSheet> createState() => _CustomerStatusSheetState();
}

class _CustomerStatusSheetState extends State<_CustomerStatusSheet> {
  late var _status = widget.current;

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
                'Situação',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: pouInk,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha se esta cliente fica ativa ou desativada.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              _StatusOption(
                key: const Key('customer_status_option_active'),
                status: CustomerStatus.active,
                selected: _status == CustomerStatus.active,
                onTap: () => setState(() => _status = CustomerStatus.active),
              ),
              const SizedBox(height: 10),
              _StatusOption(
                key: const Key('customer_status_option_inactive'),
                status: CustomerStatus.inactive,
                selected: _status == CustomerStatus.inactive,
                onTap: () => setState(() => _status = CustomerStatus.inactive),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: FilledButton(
                  key: const Key('customer_status_save'),
                  onPressed: () => Navigator.of(context).pop(_status),
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    super.key,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final CustomerStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF6F5F7) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? pouInk : const Color(0xFFE9E8EB),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  customerStatusLabel(status),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E0D0F),
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? pouInk : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
