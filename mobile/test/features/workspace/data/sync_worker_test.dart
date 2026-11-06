import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/workspace/data/sync_worker.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  late CatalogLocalDataSourceImpl data;

  setUp(() {
    data = CatalogLocalDataSourceImpl(
      databasePath: inMemoryDatabasePath,
      seedDemo: false,
      newId: () => 'weigh-1',
    );
  });

  tearDown(() async {
    await data.close();
  });

  test('a weighing stays on the phone until a server accepts it', () async {
    await data.recordWeighing(
      productId: 'batata',
      packGrams: 2500,
      packageCount: 4,
      warehouseGrams: 800000,
    );
    final db = await data.database();
    expect((await db.query('movements')), isEmpty);
    expect((await db.query('weighing_records')).single['package_count'], 4);

    Future<String> status() async {
      final rows = await db.query('pending_sync');
      return rows.single['status']! as String;
    }

    await SyncWorker(
      openDatabase: data.database,
      online: () async => false,
      transport: const _AcceptingTransport(),
    ).flush();
    expect(await status(), 'local');

    await SyncWorker(
      openDatabase: data.database,
      online: () async => true,
      transport: const NoServerSyncTransport(),
    ).flush();
    expect(await status(), 'local');

    await SyncWorker(
      openDatabase: data.database,
      online: () async => true,
      transport: const _AcceptingTransport(),
    ).flush();
    expect(await status(), 'accepted');
  });
}

class _AcceptingTransport implements SyncTransport {
  const _AcceptingTransport();

  @override
  Future<bool> deliver(PendingSync item) async => item.kind == 'weighing';
}
