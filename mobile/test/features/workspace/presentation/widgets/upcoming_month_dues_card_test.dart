import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/rules/month_board.dart';
import 'package:pouapp/features/workspace/presentation/theme/workspace_colors.dart';
import 'package:pouapp/features/workspace/presentation/widgets/upcoming_month_dues_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [WorkspaceColors.rua]),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 360, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('empty and collapsed upcoming month dues', (tester) async {
    await tester.pumpWidget(
      _wrap(
        UpcomingMonthDuesCard(
          dues: const [],
          valuesHidden: false,
          onOpenCustomer: (_) {},
        ),
      ),
    );
    expect(find.text('Próximos vencimentos'), findsOneWidget);
    expect(find.text('0 clientes'), findsOneWidget);
    expect(find.text('Nenhum vencimento restante neste mês.'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        UpcomingMonthDuesCard(
          dues: const [
            UpcomingDueCustomer(
              customerId: 'a',
              customerName: 'Ana Souza',
              dueOn: '2026-11-20',
              amountCents: 2500,
            ),
            UpcomingDueCustomer(
              customerId: 'b',
              customerName: 'Bruno Lima',
              dueOn: '2026-11-25',
              amountCents: 4000,
            ),
          ],
          valuesHidden: false,
          onOpenCustomer: (_) {},
        ),
      ),
    );
    expect(find.text('2 clientes'), findsOneWidget);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Bruno Lima'), findsNothing);
    expect(find.text('+1 cliente'), findsOneWidget);
  });
}
