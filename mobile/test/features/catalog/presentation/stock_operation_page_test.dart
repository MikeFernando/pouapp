import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/catalog/presentation/pages/products_page.dart';
import 'package:pouapp/injection_container.dart' as di;
import 'package:pouapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await tester.pumpWidget(const MaterialApp(home: ProductsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Carregar Montana'), findsOneWidget);
    expect(find.text('Retornar ao depósito'), findsOneWidget);
    expect(find.text('Registrar perda'), findsOneWidget);
    expect(find.text('Conferir estoque'), findsOneWidget);

    await tester.tap(find.byKey(const Key('action_load')));
    await tester.pumpAndSettle();
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
      const Color(0xFF1B3A2F),
    );
    const idle = <WidgetState>{};
    final confirm = tester
        .widget<FilledButton>(find.byKey(const Key('stock_operation_confirm')))
        .style!;
    expect(confirm.backgroundColor?.resolve(idle), const Color(0xFF1B3A2F));
    expect(confirm.foregroundColor?.resolve(idle), Colors.white);
    expect(confirm.minimumSize?.resolve(idle), const Size.fromHeight(52));

    await _pickLoad(tester, 'product-alho', '40');
    await tester.tap(find.byKey(const Key('stock_operation_confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Depósito 460 kg'), findsOneWidget);
    expect(find.textContaining('Montana 40 kg'), findsOneWidget);
  });

  testWidgets('reopening the load keeps the cargo until it is removed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ProductsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('action_load')));
    await tester.pumpAndSettle();
    await _pickLoad(tester, 'product-alho', '40');
    await tester.tap(find.byKey(const Key('stock_operation_confirm')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('action_load')));
    await tester.pumpAndSettle();
    expect(find.text('1 produto'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('load_quantity_product-alho')),
          )
          .controller!
          .text,
      '40',
    );
    await tester.tap(find.byKey(const Key('stock_operation_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('A carga da Montana continua igual.'), findsOneWidget);
    expect(find.textContaining('Depósito 460 kg'), findsOneWidget);
    expect(find.textContaining('Montana 40 kg'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('action_load')));
    await tester.pumpAndSettle();
    final quantity = find.byKey(const Key('load_quantity_product-alho'));
    await tester.scrollUntilVisible(
      quantity,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(quantity, '0');
    await tester.pump();
    await tester.tap(find.byKey(const Key('stock_operation_confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Depósito 500 kg'), findsOneWidget);
    expect(find.textContaining('Montana 40 kg'), findsNothing);
  });

  testWidgets('keeps the load draft when the warehouse cannot cover it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ProductsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('action_load')));
    await tester.pumpAndSettle();
    await _pickLoad(tester, 'product-alho', '600');
    await tester.tap(find.byKey(const Key('stock_operation_confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stock_operation_error')), findsOneWidget);
    expect(find.textContaining('Alho'), findsWidgets);
    expect(find.byKey(const Key('load_quantity_product-alho')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('Depósito 500 kg'), findsOneWidget);
    expect(find.textContaining('Depósito 500 kg · Montana'), findsNothing);
  });

  testWidgets('the street shortcut shows the current Montana load', (
    tester,
  ) async {
    await tester.pumpWidget(const PouApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login_email')),
      'ana.souza@pouapp.dev',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'senha-dev',
    );
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
