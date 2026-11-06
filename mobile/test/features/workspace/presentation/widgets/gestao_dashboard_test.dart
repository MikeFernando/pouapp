import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/entities/posted_sale.dart';
import 'package:pouapp/features/workspace/domain/rules/month_board.dart';
import 'package:pouapp/features/workspace/presentation/widgets/gestao_dashboard.dart';

void main() {
  final today = DateTime(2026, 11, 3);

  PostedSale sale({
    required String id,
    required String customerId,
    required String name,
    required int total,
    required int allocated,
    required String occurredOn,
    String? dueOn,
    bool isSale = true,
  }) {
    return PostedSale(
      id: id,
      customerId: customerId,
      customerName: name,
      totalCents: total,
      allocatedCents: allocated,
      occurredOn: occurredOn,
      dueOn: dueOn,
      sale: isSale,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    List<PostedSale> sales, {
    ValueChanged<DueTodayCustomer>? onOpenCustomer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GestaoDashboard(
              sales: sales,
              clock: () => today,
              onOpenSettings: () {},
              onOpenCustomer: onOpenCustomer,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the month and keeps other months apart', (tester) async {
    await pump(tester, [
      sale(
        id: 'nov',
        customerId: 'ana',
        name: 'Ana Paula',
        total: 10000,
        allocated: 4000,
        occurredOn: '2026-11-02',
        dueOn: '2026-11-03',
      ),
      sale(
        id: 'opening',
        customerId: 'ana',
        name: 'Ana Paula',
        total: 3000,
        allocated: 0,
        occurredOn: '2026-11-01',
        dueOn: '2026-11-03',
        isSale: false,
      ),
      sale(
        id: 'oct',
        customerId: 'bia',
        name: 'Bia',
        total: 8000,
        allocated: 8000,
        occurredOn: '2026-10-20',
        dueOn: '2026-10-20',
      ),
    ]);

    expect(find.text('Nov 2026'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('month_billed'))).data,
      'R\$ 100,00',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('month_received'))).data,
      'R\$ 40,00',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('month_open'))).data,
      'R\$ 60,00',
    );
    expect(find.textContaining('40% do faturamento'), findsOneWidget);
    expect(find.text('Vence hoje · 1 compra'), findsOneWidget);
    expect(find.text('R\$ 90,00'), findsOneWidget);
    expect(find.text('Nenhuma venda neste mês.'), findsNothing);

    await tester.tap(find.byKey(const Key('month_previous')));
    await tester.pumpAndSettle();

    expect(find.text('Out 2026'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('month_billed'))).data,
      'R\$ 80,00',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('month_received'))).data,
      'R\$ 80,00',
    );
    expect(find.text('Vence hoje · 1 compra'), findsOneWidget);

    await tester.tap(find.byKey(const Key('month_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('month_next')));
    await tester.pumpAndSettle();

    expect(find.text('Dez 2026'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('month_billed'))).data,
      'R\$ 0,00',
    );
    expect(find.text('Nenhuma venda neste mês.'), findsOneWidget);
  });

  testWidgets('tapping a customer opens that debt', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DueTodayCustomer? opened;
    await pump(tester, [
      sale(
        id: 'nov',
        customerId: 'ana',
        name: 'Ana Paula',
        total: 10000,
        allocated: 4000,
        occurredOn: '2026-11-02',
        dueOn: '2026-11-03',
      ),
    ], onOpenCustomer: (customer) => opened = customer);

    await tester.tap(find.byKey(const Key('due_customer_ana')));
    await tester.pump();

    expect(opened?.customerId, 'ana');
    expect(opened?.dueCents, 6000);
    expect(opened?.balanceCents, 6000);
    expect(find.textContaining('Recebimento de'), findsNothing);
  });

  testWidgets('keeps the board intact at 360, 390 and larger text', (
    tester,
  ) async {
    final filled = [
      sale(
        id: 'nov',
        customerId: 'ana',
        name: 'Ana Paula',
        total: 10000,
        allocated: 4000,
        occurredOn: '2026-11-02',
        dueOn: '2026-11-03',
      ),
    ];

    Future<void> frame({
      required Size size,
      required double scale,
      required List<PostedSale> sales,
      required bool sideBySide,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
          home: Scaffold(
            backgroundColor: const Color(0xFFF8F7F2),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: GestaoDashboard(
                  sales: sales,
                  clock: () => today,
                  onOpenSettings: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Resumo do mês'), findsOneWidget);
      expect(find.text('Vendas no mês'), findsOneWidget);
      expect(
        tester.getSize(find.text('Resumo do mês')).height,
        lessThan(42 * scale),
      );
      final received = tester.getTopLeft(
        find.byKey(const Key('month_received')),
      );
      final open = tester.getTopLeft(find.byKey(const Key('month_open')));
      final gap = (received.dy - open.dy).abs();
      if (sideBySide) {
        expect(gap, lessThan(8));
      } else {
        expect(gap, greaterThan(20));
      }
    }

    await frame(
      size: const Size(390, 844),
      scale: 1,
      sales: filled,
      sideBySide: true,
    );
    expect(find.text('Sem faturamento no período'), findsNothing);
    await frame(
      size: const Size(390, 844),
      scale: 1,
      sales: const <PostedSale>[],
      sideBySide: true,
    );
    expect(find.text('Sem faturamento no período'), findsOneWidget);
    expect(find.text('0 clientes • R\$ 0,00'), findsOneWidget);
    expect(find.text('Nenhuma venda neste mês.'), findsOneWidget);
    await frame(
      size: const Size(360, 740),
      scale: 1,
      sales: filled,
      sideBySide: true,
    );
    await frame(
      size: const Size(360, 740),
      scale: 1.4,
      sales: filled,
      sideBySide: false,
    );
    await frame(
      size: const Size(360, 740),
      scale: 1.4,
      sales: const <PostedSale>[],
      sideBySide: false,
    );

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
