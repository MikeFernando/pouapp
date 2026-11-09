import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/app/pou_app_colors.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/catalog/domain/entities/stock_operation.dart';
import 'package:pouapp/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:pouapp/features/catalog/presentation/pages/stock_operation_page.dart';
import 'package:pouapp/injection_container.dart' as di;
import 'package:pouapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openLoad(WidgetTester tester) async {
  if (find.text('abrir carga').evaluate().isEmpty) {
    await tester.pumpWidget(const MaterialApp(home: _LoadHost()));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('abrir carga'));
  await tester.pumpAndSettle();
}

Future<void> _pickLoad(
  WidgetTester tester,
  String productId,
  String amount,
) async {
  final add = find.byKey(Key('load_add_$productId'));
  await tester.scrollUntilVisible(
    add,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(add);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(Key('load_quantity_$productId')), amount);
  await tester.pump();
}

Future<void> _expectOnion({
  required int warehouseGrams,
  required int montanaGrams,
}) async {
  final result = await di.sl<CatalogRepository>().load();
  result.fold((_) => fail('expected the catalog'), (snapshot) {
    final onion = snapshot.products.singleWhere(
      (row) => row.product.id == 'product-cebola',
    );
    expect(onion.balances[StockLocationCode.warehouse], warehouseGrams);
    expect(onion.balances[StockLocationCode.montana] ?? 0, montanaGrams);
  });
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  tearDown(() async {
    if (di.sl.isRegistered<CatalogLocalDataSource>()) {
      await di.sl<CatalogLocalDataSource>().close();
    }
    await di.sl.reset();
  });

  testWidgets('loads 40 kg from the warehouse onto the Montana', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openLoad(tester);

    expect(find.text('Carregar Montana'), findsOneWidget);
    expect(find.text('Depósito → Montana'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/produce/banana.jpg',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      pouInk,
    );
    const idle = <WidgetState>{};
    final confirm = tester
        .widget<FilledButton>(find.byKey(const Key('stock_operation_confirm')))
        .style!;
    expect(confirm.backgroundColor?.resolve(idle), pouInk);
    expect(confirm.foregroundColor?.resolve(idle), Colors.white);
    expect(confirm.minimumSize?.resolve(idle), const Size.fromHeight(52));

    await _pickLoad(tester, 'product-cebola', '40');
    await tester.tap(find.byKey(const Key('stock_operation_confirm')));
    await tester.pumpAndSettle();

    await _expectOnion(warehouseGrams: 560000, montanaGrams: 40000);
  });

  testWidgets('reopening the load keeps the cargo until it is removed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openLoad(tester);
    await _pickLoad(tester, 'product-cebola', '40');
    await tester.tap(find.byKey(const Key('stock_operation_confirm')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await _openLoad(tester);
    expect(find.text('1 produto'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('load_quantity_product-cebola')),
          )
          .controller!
          .text,
      '40',
    );
    await tester.tap(find.byKey(const Key('stock_operation_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('A carga da Montana continua igual.'), findsOneWidget);
    await _expectOnion(warehouseGrams: 560000, montanaGrams: 40000);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await _openLoad(tester);
    final quantity = find.byKey(const Key('load_quantity_product-cebola'));
    await tester.scrollUntilVisible(
      quantity,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(quantity, '0');
    await tester.pump();
    await tester.tap(find.byKey(const Key('stock_operation_confirm')));
    await tester.pumpAndSettle();

    await _expectOnion(warehouseGrams: 600000, montanaGrams: 0);
  });

  testWidgets('keeps the load draft when the warehouse cannot cover it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openLoad(tester);
    await _pickLoad(tester, 'product-cebola', '700');
    await tester.tap(find.byKey(const Key('stock_operation_confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stock_operation_error')), findsOneWidget);
    expect(find.textContaining('Cebola'), findsWidgets);
    expect(
      find.byKey(const Key('load_quantity_product-cebola')),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _expectOnion(warehouseGrams: 600000, montanaGrams: 0);
  });

  testWidgets('the street shortcut shows the current Montana load', (
    tester,
  ) async {
    await tester.pumpWidget(const PouApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login_email')),
      'mike@gmail.com',
    );
    await tester.enterText(find.byKey(const Key('login_password')), 'mike@123');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('montana_load_caption')), findsOneWidget);
    expect(find.text('A Montana está sem carga.'), findsOneWidget);
    expect(find.byKey(const Key('load_montana')), findsOneWidget);
    expect(find.byKey(const Key('return_warehouse')), findsOneWidget);
  });
}

class _LoadHost extends StatelessWidget {
  const _LoadHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const StockOperationPage(kind: StockOperationKind.load),
              ),
            );
          },
          child: const Text('abrir carga'),
        ),
      ),
    );
  }
}
