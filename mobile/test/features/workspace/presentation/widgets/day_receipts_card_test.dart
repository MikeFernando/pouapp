import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:pouapp/features/workspace/domain/rules/month_board.dart';
import 'package:pouapp/features/workspace/presentation/theme/workspace_colors.dart';
import 'package:pouapp/features/workspace/presentation/widgets/day_receipts_card.dart';

List<DayReceiptCustomer> _receipts(int count) {
  return [
    for (var i = 0; i < count; i++)
      DayReceiptCustomer(
        customerId: 'c$i',
        customerName: i == 0
            ? 'Fatima Garcez'
            : i == 1
            ? 'Mike Fernando'
            : 'Cliente ${i + 1} com nome bem longo para ellipsis',
        amountCents: i == 0
            ? 1770
            : i == 1
            ? 3620
            : 1000 + i,
        done: false,
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

Future<void> _capture(
  WidgetTester tester,
  Finder finder,
  String fileName,
) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir =
        Directory('test/features/workspace/presentation/widgets/goldens');
    dir.createSync(recursive: true);
    File('${dir.path}/$fileName').writeAsBytesSync(
      bytes!.buffer.asUint8List(),
    );
  });
}

void main() {
  testWidgets('empty state has no chevron or expand affordance', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DayReceiptsCard(
          progress: const VisitProgress(done: 0, total: 0),
          receipts: const [],
          valuesHidden: false,
          onOpenCustomer: (_) {},
        ),
      ),
    );

    expect(find.text('Recebimentos do dia'), findsOneWidget);
    expect(find.text('0 de 0'), findsOneWidget);
    expect(
      find.text('Nenhum recebimento com vencimento hoje.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('day_receipts_chevron')), findsNothing);
    expect(find.byKey(const Key('day_receipts_more')), findsNothing);
  });

  testWidgets('single receipt has no stack affordances', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DayReceiptsCard(
          progress: const VisitProgress(done: 0, total: 1),
          receipts: _receipts(1),
          valuesHidden: false,
          onOpenCustomer: (_) {},
        ),
      ),
    );

    expect(find.text('Fatima Garcez'), findsOneWidget);
    expect(find.text('R\$ 17,70'), findsOneWidget);
    expect(find.byKey(const Key('day_receipts_chevron')), findsNothing);
    expect(find.byKey(const Key('day_receipts_more')), findsNothing);
  });

  testWidgets('checklist marks served and reports received cents', (
    tester,
  ) async {
    var reported = DayChecklistSnapshot.empty;
    await tester.pumpWidget(
      _wrap(
        DayReceiptsCard(
          progress: const VisitProgress(done: 0, total: 1),
          receipts: _receipts(1),
          valuesHidden: false,
          onOpenCustomer: (_) {},
          onChecklistChanged: (snapshot) => reported = snapshot,
        ),
      ),
    );

    expect(find.text('0 de 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('day_receipt_check_c0')));
    await tester.pump();
    await tester.pump();

    expect(find.text('1 de 1'), findsOneWidget);
    expect(reported.receivedCents, 1770);

    await tester.tap(find.byKey(const Key('day_receipt_check_c0')));
    await tester.pump();
    await tester.pump();
    expect(find.text('0 de 1'), findsOneWidget);
    expect(reported.receivedCents, 0);
  });

  testWidgets('collapsed then expands for two receipts', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      _wrap(
        DayReceiptsCard(
          progress: const VisitProgress(done: 0, total: 2),
          receipts: _receipts(2),
          valuesHidden: false,
          onOpenCustomer: opened.add,
        ),
      ),
    );

    expect(find.text('0 de 2'), findsOneWidget);
    expect(find.text('Fatima Garcez'), findsOneWidget);
    expect(find.text('Mike Fernando'), findsNothing);
    expect(find.text('+1 recebimento'), findsOneWidget);
    expect(find.byKey(const Key('day_receipts_chevron')), findsOneWidget);

    await tester.tap(find.byKey(const Key('day_receipts_header')));
    await tester.pumpAndSettle();

    expect(find.text('Mike Fernando'), findsOneWidget);
    expect(find.text('R\$ 36,20'), findsOneWidget);
    expect(find.text('+1 recebimento'), findsNothing);

    await tester.tap(find.byKey(const Key('day_receipt_c0')));
    expect(opened, ['c0']);

    await tester.tap(find.byKey(const Key('day_receipts_header')));
    await tester.pumpAndSettle();
    expect(find.text('Mike Fernando'), findsNothing);
    expect(find.text('+1 recebimento'), findsOneWidget);
  });

  testWidgets('fifty receipts expand and collapse via header', (tester) async {
    tester.view.physicalSize = const Size(400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: DayReceiptsCard(
            progress: const VisitProgress(done: 0, total: 50),
            receipts: _receipts(50),
            valuesHidden: false,
            onOpenCustomer: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('+49 recebimentos'), findsOneWidget);
    expect(find.text('Cliente 50 com nome bem longo para ellipsis'), findsNothing);

    await tester.tap(find.byKey(const Key('day_receipts_more')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Cliente 50 com nome bem longo para ellipsis'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Cliente 50 com nome bem longo para ellipsis'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('day_receipts_header')));
    await tester.pumpAndSettle();
    expect(find.text('+49 recebimentos'), findsOneWidget);
  });

  testWidgets('captures reference states for visual check', (tester) async {
    final boundaryKey = GlobalKey();

    Future<void> pumpState({
      required List<DayReceiptCustomer> receipts,
      required VisitProgress progress,
      required bool expand,
      required String fileName,
    }) async {
      await tester.pumpWidget(
        _wrap(
          RepaintBoundary(
            key: boundaryKey,
            child: DayReceiptsCard(
              progress: progress,
              receipts: receipts,
              valuesHidden: false,
              onOpenCustomer: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      if (expand) {
        await tester.tap(find.byKey(const Key('day_receipts_header')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      await _capture(tester, find.byKey(boundaryKey), fileName);
    }

    await pumpState(
      receipts: _receipts(2),
      progress: const VisitProgress(done: 0, total: 2),
      expand: false,
      fileName: 'day_receipts_collapsed.png',
    );
    await pumpState(
      receipts: _receipts(2),
      progress: const VisitProgress(done: 0, total: 2),
      expand: true,
      fileName: 'day_receipts_expanded.png',
    );
    await pumpState(
      receipts: const [],
      progress: const VisitProgress(done: 0, total: 0),
      expand: false,
      fileName: 'day_receipts_empty.png',
    );
  });
}
