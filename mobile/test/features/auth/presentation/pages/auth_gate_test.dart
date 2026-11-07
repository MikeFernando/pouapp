import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/core/usecases/usecase.dart';
import 'package:pouapp/features/auth/domain/entities/user.dart';
import 'package:pouapp/features/auth/domain/usecases/get_current_user.dart';
import 'package:pouapp/features/auth/domain/usecases/login.dart';
import 'package:pouapp/features/auth/domain/usecases/logout.dart';
import 'package:pouapp/features/auth/domain/usecases/register_account.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_event.dart';
import 'package:pouapp/features/auth/presentation/pages/auth_gate.dart';

class MockLogin extends Mock implements Login {}

class MockRegisterAccount extends Mock implements RegisterAccount {}

class MockGetCurrentUser extends Mock implements GetCurrentUser {}

class MockLogout extends Mock implements Logout {}

void main() {
  late MockLogin mockLogin;
  late MockRegisterAccount mockRegister;
  late MockGetCurrentUser mockGetCurrentUser;
  late MockLogout mockLogout;

  const tUser = User(
    id: 'dev-user-ana',
    name: 'Ana Souza',
    email: 'ana.souza@pouapp.dev',
  );

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const Params(email: 'ana.souza@pouapp.dev', password: 'senha-dev'),
    );
  });

  setUp(() {
    mockLogin = MockLogin();
    mockRegister = MockRegisterAccount();
    mockGetCurrentUser = MockGetCurrentUser();
    mockLogout = MockLogout();
    when(() => mockGetCurrentUser(any()))
        .thenAnswer((_) async => const Right(null));
  });

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthBloc(
            login: mockLogin,
            registerAccount: mockRegister,
            getCurrentUser: mockGetCurrentUser,
            logout: mockLogout,
          )..add(const AuthSessionRequested()),
          child: const AuthGate(),
        ),
      ),
    );
  }

  testWidgets('should show a loading indicator while checking the session', (
    tester,
  ) async {
    when(() => mockGetCurrentUser(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const Right(null);
    });

    await pumpGate(tester);

    expect(find.bySemanticsLabel('Verificando sessão'), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_submit')), findsOneWidget);
  });

  testWidgets('should open the home screen when a session already exists', (
    tester,
  ) async {
    when(() => mockGetCurrentUser(any()))
        .thenAnswer((_) async => const Right(tUser));

    await pumpGate(tester);
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo'), findsOneWidget);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('ana.souza@pouapp.dev'), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsNothing);
  });

  testWidgets('should move from login to home and back without a route stack', (
    tester,
  ) async {
    when(() => mockLogin(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return const Right(tUser);
    });
    when(() => mockLogout(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return const Right(unit);
    });

    await pumpGate(tester);
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
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Bem-vindo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pump();
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.text('Ana Souza'), findsNothing);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(await navigator.maybePop(), isFalse);
    expect(find.text('Ana Souza'), findsNothing);
  });

  testWidgets('should keep the home screen when logout fails', (tester) async {
    when(() => mockGetCurrentUser(any()))
        .thenAnswer((_) async => const Right(tUser));
    when(() => mockLogout(any()))
        .thenAnswer((_) async => const Left(CacheFailure()));

    await pumpGate(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível sair. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsNothing);
  });
}
