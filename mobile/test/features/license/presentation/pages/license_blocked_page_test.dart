import 'dart:io';
import 'dart:ui' as ui;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/usecases/usecase.dart';
import 'package:pouapp/features/auth/domain/entities/user.dart';
import 'package:pouapp/features/auth/domain/usecases/get_current_user.dart';
import 'package:pouapp/features/auth/domain/usecases/login.dart';
import 'package:pouapp/features/auth/domain/usecases/logout.dart';
import 'package:pouapp/features/auth/domain/usecases/register_account.dart';
import 'package:pouapp/features/auth/domain/usecases/update_user_name.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pouapp/features/license/domain/entities/license_status.dart';
import 'package:pouapp/features/license/domain/repositories/license_repository.dart';
import 'package:pouapp/features/license/domain/usecases/check_license.dart';
import 'package:pouapp/features/license/presentation/bloc/license_bloc.dart';
import 'package:pouapp/features/license/presentation/bloc/license_state.dart';
import 'package:pouapp/features/license/presentation/pages/license_blocked_page.dart';

class MockLogin extends Mock implements Login {}

class MockRegisterAccount extends Mock implements RegisterAccount {}

class MockGetCurrentUser extends Mock implements GetCurrentUser {}

class MockLogout extends Mock implements Logout {}

class MockUpdateUserName extends Mock implements UpdateUserName {}

class MockCheckLicense extends Mock implements CheckLicense {}

class MockLicenseRepository extends Mock implements LicenseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLogin mockLogin;
  late MockRegisterAccount mockRegister;
  late MockGetCurrentUser mockGetCurrentUser;
  late MockLogout mockLogout;
  late MockUpdateUserName mockUpdateUserName;
  late MockCheckLicense mockCheckLicense;
  late MockLicenseRepository mockLicenseRepository;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const CheckLicenseParams());
  });

  setUp(() {
    mockLogin = MockLogin();
    mockRegister = MockRegisterAccount();
    mockGetCurrentUser = MockGetCurrentUser();
    mockLogout = MockLogout();
    mockUpdateUserName = MockUpdateUserName();
    mockCheckLicense = MockCheckLicense();
    mockLicenseRepository = MockLicenseRepository();
    when(() => mockGetCurrentUser(any())).thenAnswer(
      (_) async => const Right(
        User(
          id: '1',
          name: 'Teste',
          email: 'teste@pouapp.dev',
        ),
      ),
    );
    when(() => mockCheckLicense(any())).thenAnswer(
      (_) async => Right(
        LicenseStatus(
          active: false,
          status: 'unpaid',
          paidUntil: null,
          message: 'blocked',
          checkedAt: DateTime.utc(2026, 1, 1),
        ),
      ),
    );
  });

  testWidgets('renders reference copy and actions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => AuthBloc(
                login: mockLogin,
                registerAccount: mockRegister,
                getCurrentUser: mockGetCurrentUser,
                logout: mockLogout,
                updateUserName: mockUpdateUserName,
              ),
            ),
            BlocProvider(
              create: (_) => LicenseBloc(
                checkLicense: mockCheckLicense,
                repository: mockLicenseRepository,
              ),
            ),
          ],
          child: const RepaintBoundary(
            key: Key('license_blocked_capture'),
            child: LicenseBlockedPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PouApp'), findsOneWidget);
    expect(find.text('ACESSO PAUSADO'), findsOneWidget);
    expect(find.text('Serviço\nindisponível'), findsOneWidget);
    expect(
      find.text('Seu acesso está suspenso até a\nconfirmação do pagamento.'),
      findsOneWidget,
    );
    expect(find.text('Já realizou o pagamento?'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);
    expect(find.byKey(const Key('license_retry')), findsOneWidget);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('license_blocked_capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final out = File(
        'test/features/license/presentation/pages/license_blocked_capture.png',
      );
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
    });
  });

  testWidgets('retry dispatches license check while checking', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => mockCheckLicense(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Right(
        LicenseStatus(
          active: false,
          status: 'unpaid',
          paidUntil: null,
          message: 'blocked',
          checkedAt: DateTime.utc(2026, 1, 1),
        ),
      );
    });

    final licenseBloc = LicenseBloc(
      checkLicense: mockCheckLicense,
      repository: mockLicenseRepository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => AuthBloc(
                login: mockLogin,
                registerAccount: mockRegister,
                getCurrentUser: mockGetCurrentUser,
                logout: mockLogout,
                updateUserName: mockUpdateUserName,
              ),
            ),
            BlocProvider.value(value: licenseBloc),
          ],
          child: const LicenseBlockedPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.byKey(const Key('license_retry')));
    await tester.tap(find.byKey(const Key('license_retry')));
    await tester.pump();
    expect(licenseBloc.state, isA<LicenseChecking>());
    await tester.pump(const Duration(milliseconds: 120));
  });
}
