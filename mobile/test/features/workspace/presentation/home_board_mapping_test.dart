import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/entities/home_board.dart';
import 'package:pouapp/features/workspace/domain/rules/month_board.dart';
import 'package:pouapp/features/workspace/presentation/home_board_mapping.dart';

void main() {
  test('local due today wins over stale remote tomorrow', () {
    const board = HomeBoard(
      date: '2026-11-10',
      receivedTodayCents: 0,
      receiptsDueToday: [],
      duesTomorrow: [
        HomeDueItem(
          customerId: 'mike',
          customerName: 'Mike Fernando',
          openCents: 2870,
          dueOn: '2026-11-11',
          settled: false,
          openNotes: 1,
        ),
      ],
      upcomingDues: [],
    );

    final sections = homeSectionsForLocalDay(
      board: board,
      localNotes: const [
        UpcomingDueCustomer(
          customerId: 'mike',
          customerName: 'Mike Fernando',
          dueOn: '2026-11-10',
          amountCents: 2870,
        ),
      ],
      now: DateTime(2026, 11, 10, 23, 50),
    );

    expect(sections.receipts, hasLength(1));
    expect(sections.receipts.single.customerId, 'mike');
    expect(sections.receipts.single.amountCents, 2870);
    expect(sections.tomorrow, isEmpty);
  });

  test('hides seed and orphan placeholder dues', () {
    const board = HomeBoard(
      date: '2026-11-11',
      receivedTodayCents: 0,
      receiptsDueToday: [],
      duesTomorrow: [],
      upcomingDues: [
        HomeDueItem(
          customerId: 'orphan',
          customerName: 'Cliente',
          openCents: 2370,
          dueOn: '2026-11-24',
          settled: false,
          openNotes: 1,
        ),
        HomeDueItem(
          customerId: 'demo-customer-padaria',
          customerName: 'Padaria Bom Sabor',
          openCents: 5000,
          dueOn: '2026-11-24',
          settled: false,
        ),
      ],
    );

    final sections = homeSectionsForLocalDay(
      board: board,
      localNotes: const [],
      now: DateTime(2026, 11, 11, 0, 1),
    );

    expect(sections.later, isEmpty);
  });

  test('cleared local draft hides stale remote upcoming due', () {
    const board = HomeBoard(
      date: '2026-11-11',
      receivedTodayCents: 0,
      receiptsDueToday: [],
      duesTomorrow: [],
      upcomingDues: [
        HomeDueItem(
          customerId: 'mike',
          customerName: 'Mike Fernando',
          openCents: 2870,
          dueOn: '2026-11-30',
          settled: false,
          openNotes: 1,
        ),
      ],
    );

    final sections = homeSectionsForLocalDay(
      board: board,
      localNotes: const [],
      now: DateTime(2026, 11, 11, 12),
      clearedCustomerIds: const {'mike'},
    );

    expect(sections.later, isEmpty);
  });
}
