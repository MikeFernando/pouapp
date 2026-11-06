import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/usecases/usecase.dart';
import 'package:pouapp/features/auth/domain/failures/auth_failures.dart';
import 'package:pouapp/features/auth/domain/usecases/get_current_user.dart';
import 'package:pouapp/features/auth/domain/usecases/login.dart';
import 'package:pouapp/features/auth/domain/usecases/logout.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pouapp/features/auth/presentation/pages/login_page.dart';

class MockLogin extends Mock implements Login {}

class MockGetCurrentUser extends Mock implements GetCurrentUser {}

class MockLogout extends Mock implements Logout {}

void main() {
  late MockLogin mockLogin;
  late MockGetCurrentUser mockGetCurrentUser;
  late MockLogout mockLogout;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const Params(email: 'ana.souza@pouapp.dev', password: 'senha-dev'),
    );
  });

  setUp(() {
    mockLogin = MockLogin();
    mockGetCurrentUser = MockGetCurrentUser();
    mockLogout = MockLogout();
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthBloc(
            login: mockLogin,
            getCurrentUser: mockGetCurrentUser,
            logout: mockLogout,
          ),
          child: const LoginPage(),
        ),
      ),
    );
  }

  TextField field(WidgetTester tester, Key key) {
    return tester.widget<TextField>(
      find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
    );
  }

  testWidgets('should show validation messages and skip login', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.text('Informe o e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
    verifyNever(() => mockLogin(any()));
  });

  testWidgets('should reject an invalid email before login', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login_email')), 'ana');
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'senha-dev',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    verifyNever(() => mockLogin(any()));
  });

  testWidgets('should toggle password visibility', (tester) async {
    await pumpLogin(tester);

    expect(field(tester, const Key('login_password')).obscureText, isTrue);
    expect(find.byTooltip('Mostrar senha'), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle_password')));
    await tester.pump();

    expect(field(tester, const Key('login_password')).obscureText, isFalse);
    expect(find.byTooltip('Ocultar senha'), findsOneWidget);
  });

  testWidgets('should focus the email field and configure the keyboard', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('login_email')));
    await tester.pump();

    final email = field(tester, const Key('login_email'));
    expect(email.focusNode?.hasFocus, isTrue);
    expect(email.keyboardType, TextInputType.emailAddress);
    expect(email.textInputAction, TextInputAction.next);
  });

  testWidgets('should show the authentication error', (tester) async {
    when(() => mockLogin(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return const Left(InvalidCredentialsFailure());
    });
    await pumpLogin(tester);

    await tester.enterText(
      find.byKey(const Key('login_email')),
      'ana.souza@pouapp.dev',
    );
    await tester.enterText(find.byKey(const Key('login_password')), 'errada');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets(
    'should keep the form usable on a small screen with the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      await pumpLogin(tester);
      await tester.enterText(
        find.byKey(const Key('login_email')),
        'ana.souza@pouapp.dev',
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('PouApp'), findsOneWidget);
      expect(find.text('Sistema de Gestão Empresarial'), findsOneWidget);
      expect(find.byKey(const Key('login_submit')), findsOneWidget);
    },
  );
}
