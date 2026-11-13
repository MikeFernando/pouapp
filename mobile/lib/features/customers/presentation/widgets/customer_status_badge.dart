import 'package:flutter/material.dart';

import '../../domain/entities/customer.dart';
import '../customer_messages.dart';

class CustomerStatusBadge extends StatelessWidget {
  const CustomerStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
    this.overdue = false,
  });

  final CustomerStatus status;
  final bool compact;

  /// Active customer with a past note due — shown as red "Em atraso".
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final showOverdue = overdue && status == CustomerStatus.active;
    final Color background;
    final Color foreground;
    final String label;
    if (showOverdue) {
      background = const Color(0xFFF8E8E8);
      foreground = const Color(0xFF9B1C1C);
      label = 'Em atraso';
    } else if (status == CustomerStatus.active) {
      background = const Color(0xFFD8F5E4);
      foreground = const Color(0xFF146C43);
      label = 'Regular';
    } else {
      background = const Color(0xFFF0F0F2);
      foreground = const Color(0xFF6B7280);
      label = customerStatusLabel(status);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 4 : 8,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
