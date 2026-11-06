import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  // No background isolate: widget tests deadlock if a query waits on one
  // while the tester is pumping frames.
  databaseFactory = databaseFactoryFfiNoIsolate;
  catalogDatabasePathOverride = inMemoryDatabasePath;
  await testMain();
}
