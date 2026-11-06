import 'package:flutter/material.dart';

import '../theme/workspace_colors.dart';

class FinanceBoardView extends StatelessWidget {
  const FinanceBoardView({
    super.key,
    this.showTitle = true,
    required this.onOpenStatement,
    required this.onOpenCashFlow,
    required this.onOpenReconciliation,
  });

  final bool showTitle;
  final VoidCallback onOpenStatement;
  final VoidCallback onOpenCashFlow;
  final VoidCallback onOpenReconciliation;

  @override
  Widget build(BuildContext context) {
    final colors = workspaceColorsOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            const Text(
              'Financeiro',
              key: Key('finance_title'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FinanceShortcut(
                    width: width,
                    icon: Icons.receipt_long_outlined,
                    label: 'Extrato de movimentações',
                    color: colors.accent,
                    onTap: onOpenStatement,
                  ),
                  _FinanceShortcut(
                    width: width,
                    icon: Icons.bar_chart_outlined,
                    label: 'Fluxo de caixa diário',
                    color: colors.accent,
                    onTap: onOpenCashFlow,
                  ),
                  _FinanceShortcut(
                    width: width,
                    icon: Icons.list_alt_outlined,
                    label: 'Conciliações pendentes',
                    color: colors.accent,
                    onTap: onOpenReconciliation,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FinanceShortcut extends StatelessWidget {
  const _FinanceShortcut({
    required this.width,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 148,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE6E8EC)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 18),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    color: Color(0xFF1C1C1E),
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
