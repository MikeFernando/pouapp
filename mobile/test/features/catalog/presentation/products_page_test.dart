import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/catalog/presentation/pages/products_page.dart';
import 'package:pouapp/injection_container.dart' as di;
import 'package:pouapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('saves a product and shows the same balance after reopening', (
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
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('workspace_mode_gestao')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('action_stock')));
    await tester.pumpAndSettle();
    expect(find.text('Alho'), findsOneWidget);
    expect(find.text('Cebola'), findsOneWidget);
    expect(find.text('Batata'), findsOneWidget);
    expect(_produce('assets/produce/alho.jpg'), findsOneWidget);
    expect(_produce('assets/produce/cebola.jpg'), findsOneWidget);
    expect(_produce('assets/produce/batata.jpg'), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const Key('stock_product-laranja')),
      find.byKey(const Key('catalog_list')),
      const Offset(0, -200),
    );
    await tester.tap(find.byKey(const Key('stock_product-laranja')));
    await tester.pumpAndSettle();
    expect(find.text('Depósito'), findsOneWidget);
    expect(find.text('22 kg'), findsWidgets);
    expect(find.text('Em transporte'), findsOneWidget);
    expect(find.text('Montana'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('register_catalog_product')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog_product_name')),
      'Alho',
    );
    final form = find.byType(ListView).last;
    await tester.drag(form, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog_product_price')),
      '30,00',
    );
    await tester.drag(form, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog_product_quantity')),
      '1',
    );
    await tester.tap(find.byKey(const Key('catalog_product_save')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('1 kg'),
      find.byKey(const Key('catalog_list')),
      const Offset(0, -200),
    );
    expect(find.text('1 kg'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('action_stock')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('1 kg'),
      find.byKey(const Key('catalog_list')),
      const Offset(0, -200),
    );
    expect(find.text('1 kg'), findsOneWidget);
  });

  testWidgets('scrolling the stock list leaves only the search field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ProductsPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog_search')), findsOneWidget);
    expect(find.byKey(const Key('action_load')).hitTestable(), findsOneWidget);
    expect(
      find.byKey(const Key('action_returnToWarehouse')).hitTestable(),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('catalog_list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog_search')), findsOneWidget);
    expect(find.byKey(const Key('action_load')).hitTestable(), findsNothing);
    expect(
      find.byKey(const Key('action_returnToWarehouse')).hitTestable(),
      findsNothing,
    );
    expect(find.byKey(const Key('action_loss')).hitTestable(), findsNothing);
    expect(find.byKey(const Key('action_count')).hitTestable(), findsNothing);

    await tester.drag(
      find.byKey(const Key('catalog_list')),
      const Offset(0, 800),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('action_load')).hitTestable(), findsOneWidget);
  });
}

Finder _produce(String asset) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == asset,
  );
}
