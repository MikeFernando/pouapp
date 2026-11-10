import 'package:flutter/material.dart';

import '../../domain/entities/customer.dart';
import '../customer_messages.dart';

class CustomerStatusBadge extends StatelessWidget {
  const CustomerStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final CustomerStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = status == CustomerStatus.active;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD8F5E4) : const Color(0xFFF0F0F2),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 4 : 8,
        ),
        child: Text(
          customerStatusLabel(status),
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF146C43) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
