import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/catalog/domain/rules/weigh_rules.dart';
import 'package:pouapp/features/workspace/presentation/pages/weigh_pack_page.dart';
import 'package:pouapp/injection_container.dart' as di;
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

  test('splits bulk kilograms into 25 kg and 50 kg sacks', () {
    expect(warehouseSacks(250000).map(sackLabel), ['5 sacos de 50 kg']);
    expect(warehouseSacks(175000).map(sackLabel), [
      '1 saco de 25 kg',
      '3 sacos de 50 kg',
    ]);
    expect(warehouseSacks(800000).map(sackLabel), ['16 sacos de 50 kg']);
    expect(looseBulkGrams(250000), 0);
    expect(looseBulkGrams(12000), 12000);
  });

  testWidgets('opens the potato packing screen from pesagem', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: WeighProductsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Pesar e embalar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('weigh_product_product-batata')));
    await tester.pumpAndSettle();

    expect(find.text('Batata'), findsWidgets);
    expect(find.text('Do depósito para a Montana'), findsOneWidget);
    expect(find.byKey(const Key('weigh_pallet_image')), findsOneWidget);
    expect(find.byKey(const Key('weigh_packed_image')), findsOneWidget);
    expect(find.text('800 kg'), findsOneWidget);
    expect(find.text('16 sacos de 50 kg'), findsOneWidget);
    expect(find.text('10 embalagens de 2,5 kg'), findsOneWidget);
    expect(find.text('25 kg'), findsWidgets);
    expect(
      tester.widget<Text>(find.byKey(const Key('weigh_bulk_after'))).data,
      '775 kg',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('weigh_separated'))).data,
      '25 kg',
    );

    await tester.tap(find.byKey(const Key('weigh_plus')));
    await tester.pump();
    expect(find.text('11 embalagens de 2,5 kg'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('weigh_bulk_after'))).data,
      '772,5 kg',
    );

    await tester.tap(find.byKey(const Key('weigh_confirm')));
    await tester.pumpAndSettle();
    final database = await di.sl<CatalogLocalDataSource>().database();
    final records = await database.query('weighing_records');
    expect(records.single['package_count'], 11);
    final queue = await database.query(
      'pending_sync',
      where: 'kind = ?',
      whereArgs: ['weighing'],
    );
    expect(queue.single['status'], 'local');
    expect(
      find.text(
        'Pesagem conferida. A carga da Montana é confirmada na próxima etapa.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('weigh_change_product')));
    await tester.pumpAndSettle();
    expect(find.text('Depósito 800 kg'), findsOneWidget);
  });
}
