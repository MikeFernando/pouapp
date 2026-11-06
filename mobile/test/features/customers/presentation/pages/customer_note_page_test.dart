import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:pouapp/features/customers/data/datasources/customer_local_data_source.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/entities/customer_note.dart';
import 'package:pouapp/features/customers/domain/repositories/customer_note_repository.dart';
import 'package:pouapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:pouapp/features/customers/presentation/pages/customer_details_page.dart';
import 'package:pouapp/features/workspace/presentation/bloc/company_operation_bloc.dart';
import 'package:pouapp/injection_container.dart' as di;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  tearDown(() async {
    await di.sl.reset();
  });

  testWidgets('saves a draft, reopens it and leaves stock and finance alone', (
    tester,
  ) async {
    final ana = await _real(tester, () => _customer('Ana'));
    final bia = await _real(tester, () => _customer('Bia'));
    final bananaBefore = await _real(tester, _bananaGrams);
    await tester.pumpWidget(
      MaterialApp(home: CustomerDetailsPage(customerId: ana.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rascunho'), findsOneWidget);
    expect(find.text('Aprovado'), findsNothing);
    expect(find.text('Total desta nota'), findsOneWidget);
    expect(find.text('Itens (0)'), findsOneWidget);
    expect(find.text('Nenhum item nesta nota.'), findsOneWidget);
    expect(_balance(tester), 'R\$ 0,00');
    final operation = di.sl<CompanyOperationBloc>().state.operation!;
    final sold = operation.summary.soldCents;
    final received = operation.summary.receivedCents;
    final orders = operation.street.orders.length;

    await _saveItem(tester, price: '10,00');
    expect(find.text('Itens (1)'), findsOneWidget);
    expect(find.text('1.0 x R\$ 10,00'), findsOneWidget);
    expect(_balance(tester), 'R\$ 10,00');

    await tester.ensureVisible(find.byKey(const Key('edit_Banana nanica')));
    await tester.tap(find.byKey(const Key('edit_Banana nanica')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('item_quantity_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('item_quantity_plus')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('item_price')), '12,00');
    await tester.tap(find.byKey(const Key('item_save')));
    await tester.pumpAndSettle();
    expect(find.text('3.0 x R\$ 12,00'), findsOneWidget);
    expect(_balance(tester), 'R\$ 36,00');

    await tester.tap(find.byKey(const Key('due_calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('due_day_15')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('due_confirm')));
    await tester.pumpAndSettle();
    expect(_due(tester), startsWith('15/'));

    final saved = await _real(tester, () => _draft(ana.id));
    expect(saved.lines.single.productId, 'product-banana');
    expect(saved.lines.single.quantity, 3000);
    expect(saved.lines.single.unitPriceCents, 1200);
    expect(saved.dueOn?.day, 15);
    expect(saved.totalCents, 3600);

    await tester.runAsync(() async {
      await di.sl<CustomerLocalDataSource>().close();
      await di.sl<CustomerLocalDataSource>().database();
    });
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(home: CustomerDetailsPage(customerId: ana.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('3.0 x R\$ 12,00'), findsOneWidget);
    expect(_balance(tester), 'R\$ 36,00');
    expect(_due(tester), startsWith('15/'));
    expect(find.text('Rascunho'), findsOneWidget);
    final reopened = await _real(tester, () => _draft(ana.id));
    expect(reopened.id, saved.id);
    expect(reopened.lines.single.id, saved.lines.single.id);
    expect(reopened.totalCents, 3600);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerDetailsPage(key: ValueKey(bia.id), customerId: bia.id),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Itens (0)'), findsOneWidget);
    expect(find.text('Banana nanica'), findsNothing);
    expect(_balance(tester), 'R\$ 0,00');
    expect((await _real(tester, () => _draft(bia.id))).id, isNot(saved.id));

    expect(await _real(tester, _bananaGrams), bananaBefore);
    expect(bananaBefore, 86000);
    final after = di.sl<CompanyOperationBloc>().state.operation!;
    expect(after.summary.soldCents, sold);
    expect(after.summary.receivedCents, received);
    expect(after.street.orders.length, orders);
    expect(find.textContaining('sincronizado'), findsNothing);
  });

  testWidgets('shows the save error and keeps the draft unchanged', (
    tester,
  ) async {
    final ana = await _real(tester, () => _customer('Ana'));
    await di.sl.unregister<CustomerNoteRepository>();
    di.sl.registerSingleton<CustomerNoteRepository>(const _FailingNotes());

    await tester.pumpWidget(
      MaterialApp(home: CustomerDetailsPage(customerId: ana.id)),
    );
    await tester.pumpAndSettle();
    await _saveItem(tester, price: '10,00');

    expect(find.text('Não foi possível gravar a nota.'), findsOneWidget);
    expect(find.text('Itens (0)'), findsOneWidget);
    expect(find.text('Banana nanica'), findsNothing);
    expect(find.textContaining('salvo'), findsNothing);
    expect(_balance(tester), 'R\$ 0,00');
  });
}

Future<T> _real<T>(WidgetTester tester, Future<T> Function() action) async {
  final value = await tester.runAsync(action);
  if (value == null) {
    throw StateError('A operação no banco não devolveu resultado.');
  }
  return value;
}

Future<Customer> _customer(String name) async {
  final result = await di.sl<CustomerRepository>().createCustomer(
    CustomerInput(type: CustomerType.individual, name: name),
  );
  return result.fold(
    (failure) => throw StateError('$failure'),
    (customer) => customer,
  );
}

Future<CustomerNote> _draft(String customerId) async {
  final result = await di.sl<CustomerNoteRepository>().activeDraft(customerId);
  return result.fold((failure) => throw StateError('$failure'), (note) => note);
}

Future<int> _bananaGrams() async {
  final result = await di.sl<CatalogRepository>().getProduct('product-banana');
  return result.fold(
    (failure) => throw StateError('$failure'),
    (stock) => stock.total,
  );
}

String _balance(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const Key('customer_open_balance')))
      .data!;
}

String _due(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('customer_due_date'))).data!;
}

Future<void> _saveItem(WidgetTester tester, {required String price}) async {
  await tester.ensureVisible(find.byKey(const Key('add_item')));
  await tester.tap(find.byKey(const Key('add_item')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('catalog_product-banana')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('item_price')), price);
  await tester.tap(find.byKey(const Key('item_save')));
  await tester.pumpAndSettle();
}

class _FailingNotes implements CustomerNoteRepository {
  const _FailingNotes();

  @override
  Future<Either<Failure, CustomerNote>> openNote(String customerId) {
    return activeDraft(customerId);
  }

  @override
  Future<Either<Failure, CustomerNote?>> currentNote(String customerId) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, CustomerNote>> note(String id) async {
    return const Left(CacheFailure());
  }

  @override
  Future<Either<Failure, CustomerNote>> activeDraft(String customerId) async {
    final now = DateTime.utc(2026, 6, 1);
    return Right(
      CustomerNote(
        id: 'draft-failed',
        customerId: customerId,
        status: NoteStatus.draft,
        createdAt: now,
        updatedAt: now,
        lines: const [],
      ),
    );
  }

  @override
  Future<Either<Failure, CustomerNote>> saveLines({
    required String noteId,
    required List<NoteLineDraft> lines,
  }) async {
    return const Left(CacheFailure());
  }

  @override
  Future<Either<Failure, CustomerNote>> setDueOn({
    required String noteId,
    required DateTime? dueOn,
  }) async {
    return const Left(CacheFailure());
  }
}
