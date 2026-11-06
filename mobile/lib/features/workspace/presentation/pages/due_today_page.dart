import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/rules/month_board.dart';
import '../bloc/company_operation_bloc.dart';
import '../widgets/gestao_dashboard.dart';
import 'customer_debt_page.dart';

class DueTodayPage extends StatelessWidget {
  const DueTodayPage({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final now = clock?.call() ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('A receber hoje'),
      ),
      body: BlocBuilder<CompanyOperationBloc, CompanyOperationState>(
        builder: (context, state) {
          final due = duesToday(
            sales: state.operation?.postedSales ?? const [],
            today: today,
          );
          if (due.isEmpty) {
            return const SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhum recebimento previsto para hoje.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: due.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final customer = due[index];
                return DueTodayTile(
                  customer: customer,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CustomerDebtPage(
                          customerId: customer.customerId,
                          customerName: customer.customerName,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
