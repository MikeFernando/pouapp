import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/core/network/api_client.dart';
import 'package:pouapp/features/business/data/datasources/business_setup_local_data_source.dart';
import 'package:pouapp/features/business/data/datasources/business_setup_remote_data_source.dart';
import 'package:pouapp/features/business/data/models/business_setup_model.dart';
import 'package:pouapp/features/business/data/repositories/business_setup_repository_impl.dart';
import 'package:pouapp/features/business/domain/entities/business_setup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BusinessSetupLocalDataSource local;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    local = BusinessSetupLocalDataSource(
      sharedPreferences: await SharedPreferences.getInstance(),
    );
  });

  test('a missing profile is a legacy hortifruti business', () async {
    final repository = BusinessSetupRepositoryImpl(localDataSource: local);

    final first = await repository.read('legacy-user');
    final second = await repository.read('legacy-user');

    final setup = first.fold((failure) => throw failure, (value) => value);
    final again = second.fold((failure) => throw failure, (value) => value);
    expect(setup.isConfigured, isTrue);
    expect(setup.kind, BusinessKind.hortifruti);
    expect(setup.botanical, isTrue);
    expect(again.kind, setup.kind);
    expect(again.status, setup.status);
    expect(again.categories, setup.categories);
  });

  test(
    'an explicit pending profile stays pending with an empty type',
    () async {
      await local.markPending('new-user');
      final repository = BusinessSetupRepositoryImpl(localDataSource: local);

      final setup = (await repository.read('new-user'))
          .fold((failure) => throw failure, (value) => value);

      expect(setup.isConfigured, isFalse);
      expect(setup.kind, isNull);
      expect(setup.status, BusinessSetupStatus.pending);
    },
  );

  test('a missing setup status is not the same as a new pending account', () {
    final legacy = BusinessSetupModel.fromJson('old', {
      'receiverName': 'Hortifruti da Ana',
    });
    final pending = BusinessSetupModel.fromJson('new', {
      'setupStatus': 'pending',
    });

    expect(legacy.isConfigured, isTrue);
    expect(legacy.kind, BusinessKind.hortifruti);
    expect(pending.isConfigured, isFalse);
    expect(pending.kind, isNull);
  });

  test('saving twice keeps one set of category suggestions', () async {
    await local.markPending('new-user');
    final repository = BusinessSetupRepositoryImpl(localDataSource: local);

    final first = await repository.save(
      userId: 'new-user',
      kind: BusinessKind.grocery,
    );
    final second = await repository.save(
      userId: 'new-user',
      kind: BusinessKind.grocery,
    );

    final saved = second.fold((failure) => throw failure, (value) => value);
    final ids = saved.categories.map((category) => category.id).toList();
    expect(
      first.fold((failure) => throw failure, (value) => value.categories),
      saved.categories,
    );
    expect(ids, categorySuggestionsFor(BusinessKind.grocery).map((c) => c.id));
    expect(ids.toSet(), hasLength(ids.length));
    expect(saved.kind, BusinessKind.grocery);
    expect(saved.botanical, isFalse);
  });

  test('a failed save keeps the pending profile', () async {
    await local.markPending('new-user');
    final remote = _FailingRemote();
    final repository = BusinessSetupRepositoryImpl(
      localDataSource: local,
      remoteDataSource: remote,
    );

    final failed = await repository.save(
      userId: 'new-user',
      kind: BusinessKind.cleaning,
    );
    final stored = await local.read('new-user');

    expect(
      failed.fold((failure) => failure, (_) => null),
      isA<NetworkFailure>(),
    );
    expect(stored?.status, BusinessSetupStatus.pending);

    remote.fail = false;
    final saved = await repository.save(
      userId: 'new-user',
      kind: BusinessKind.cleaning,
    );
    expect(
      saved.fold((failure) => throw failure, (value) => value.kind),
      BusinessKind.cleaning,
    );
    expect(remote.saves, 2);
  });
}

class _FailingRemote implements BusinessSetupRemoteDataSource {
  var fail = true;
  var saves = 0;

  @override
  Future<BusinessSetup> fetch(String userId) {
    throw UnimplementedError();
  }

  @override
  Future<BusinessSetup> save({
    required String userId,
    required BusinessKind kind,
  }) async {
    saves += 1;
    if (fail) throw const NetworkException();
    return BusinessSetup.configured(userId: userId, kind: kind);
  }
}
