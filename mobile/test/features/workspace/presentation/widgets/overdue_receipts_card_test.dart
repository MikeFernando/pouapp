import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/rules/month_board.dart';
import 'package:pouapp/features/workspace/presentation/theme/workspace_colors.dart';
import 'package:pouapp/features/workspace/presentation/widgets/overdue_receipts_card.dart';

List<UpcomingDueCustomer> _dues(int count) {
  return [
    for (var i = 0; i < count; i++)
      UpcomingDueCustomer(
        customerId: 'c$i',
        customerName: i == 0
            ? 'Maria Oliveira'
            : i == 1
            ? 'Ana Souza'
            : 'Cliente ${i + 1}',
        dueOn: '2026-11-${(9 - i).toString().padLeft(2, '0')}',
        amountCents: i == 0
            ? 8650
            : i == 1
            ? 2500
            : 1000 + i,
      ),
  ];
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: const [WorkspaceColors.rua],
    ),
    home: Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: SizedBox(
          width: 360,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('empty state has no chevron', (tester) async {
    await tester.pumpWidget(
      _wrap(
        OverdueReceiptsCard(
          dues: const [],
          valuesHidden: false,
          onOpenCustomer: (_) {},
        ),
      ),
    );

    expect(find.text('Vencidos'), findsOneWidget);
    expect(find.text('0 clientes'), findsOneWidget);
    expect(find.text('Nenhum cliente em atraso.'), findsOneWidget);
    expect(find.byKey(const Key('overdue_chevron')), findsNothing);
  });

  testWidgets('collapsed then expands for two overdue clients', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      _wrap(
        OverdueReceiptsCard(
          dues: _dues(2),
          valuesHidden: false,
          onOpenCustomer: opened.add,
        ),
      ),
    );

    expect(find.text('2 clientes'), findsOneWidget);
    expect(find.text('Maria Oliveira'), findsOneWidget);
    expect(find.text('09'), findsOneWidget);
    expect(find.text('NOV'), findsOneWidget);
    expect(find.text('Ana Souza'), findsNothing);
    expect(find.text('+1 cliente'), findsOneWidget);

    await tester.tap(find.byKey(const Key('overdue_header')));
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('08'), findsOneWidget);
    expect(find.text('+1 cliente'), findsNothing);

    await tester.tap(find.byKey(const Key('overdue_c0')));
    expect(opened, ['c0']);
  });
}
