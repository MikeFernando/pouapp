import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_event.dart';
import 'package:pouapp/features/customers/data/datasources/customer_local_data_source.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/injection_container.dart' as di;
import 'package:pouapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockCustomerLocalDataSource extends Mock
    implements CustomerLocalDataSource {}

void main() {
  late MockCustomerLocalDataSource localDataSource;

  setUpAll(() {
    registerFallbackValue(const CustomerQuery());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await di.init();
    localDataSource = MockCustomerLocalDataSource();
    when(() => localDataSource.getCustomers(any())).thenAnswer(
      (_) async =>
          const CustomerPage(items: [], total: 0, page: 0, pageSize: 20),
    );
    when(() => localDataSource.close()).thenAnswer((_) async {});
    await di.sl.unregister<CustomerLocalDataSource>();
    di.sl.registerSingleton<CustomerLocalDataSource>(localDataSource);
  });

  tearDown(() async {
    await di.sl.reset();
  });

  testWidgets(
    'should open customers only after login and forget them on logout',
    (tester) async {
      await tester.pumpWidget(const PouApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customer_search')), findsNothing);
      expect(find.byKey(const Key('open_customers_button')), findsNothing);

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

      expect(find.byKey(const Key('workspace_mode_rua')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('open_customers_button')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('street_board_scroll')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open_customers_button')));
      await tester.pumpAndSettle();

      expect(find.text('Cliente'), findsOneWidget);
      expect(find.byKey(const Key('customer_empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('customer_search_button')));
      await tester.pumpAndSettle();
      expect(find.text('Nome ou Documento'), findsOneWidget);
      expect(find.text('Cliente'), findsNothing);
      await tester.tap(find.byKey(const Key('customer_search_close')));
      await tester.pumpAndSettle();
      expect(find.text('Cliente'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workspace_mode_rua')), findsOneWidget);
      expect(find.byKey(const Key('customer_search')), findsNothing);

      tester
          .element(find.byKey(const Key('workspace_mode_rua')))
          .read<AuthBloc>()
          .add(const AuthLogoutRequested());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_submit')), findsOneWidget);
      expect(find.text('Ana Souza'), findsNothing);
      expect(find.byKey(const Key('customer_search')), findsNothing);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(await navigator.maybePop(), isFalse);
    },
  );
}
