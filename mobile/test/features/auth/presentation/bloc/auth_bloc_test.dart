import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/core/usecases/usecase.dart';
import 'package:pouapp/features/auth/domain/entities/user.dart';
import 'package:pouapp/features/auth/domain/failures/auth_failures.dart';
import 'package:pouapp/features/auth/domain/usecases/get_current_user.dart';
import 'package:pouapp/features/auth/domain/usecases/login.dart';
import 'package:pouapp/features/auth/domain/usecases/logout.dart';
import 'package:pouapp/features/auth/domain/usecases/register_account.dart';
import 'package:pouapp/features/auth/domain/usecases/update_user_name.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_event.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_state.dart';

class MockLogin extends Mock implements Login {}

class MockRegisterAccount extends Mock implements RegisterAccount {}

class MockGetCurrentUser extends Mock implements GetCurrentUser {}

class MockLogout extends Mock implements Logout {}

class MockUpdateUserName extends Mock implements UpdateUserName {}

void main() {
  late MockLogin mockLogin;
  late MockRegisterAccount mockRegister;
  late MockGetCurrentUser mockGetCurrentUser;
  late MockLogout mockLogout;
  late MockUpdateUserName mockUpdateUserName;

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
    registerFallbackValue(
      const RegisterParams(
        name: 'Ana Souza',
        email: 'ana.souza@pouapp.dev',
        password: 'senha-dev',
      ),
    );
    registerFallbackValue(const UpdateUserNameParams(name: 'Ana Souza'));
  });

  setUp(() {
    mockLogin = MockLogin();
    mockRegister = MockRegisterAccount();
    mockGetCurrentUser = MockGetCurrentUser();
    mockLogout = MockLogout();
    mockUpdateUserName = MockUpdateUserName();
  });

  AuthBloc buildBloc() {
    return AuthBloc(
      login: mockLogin,
      registerAccount: mockRegister,
      getCurrentUser: mockGetCurrentUser,
      logout: mockLogout,
      updateUserName: mockUpdateUserName,
    );
  }

  test('should start as AuthInitial', () {
    final bloc = buildBloc();

    expect(bloc.state, const AuthInitial());
    bloc.close();
  });

  test('should not expose the password in the login event text', () {
    const event = AuthLoginSubmitted(
      email: 'ana.souza@pouapp.dev',
      password: 'senha-dev',
    );

    expect(event.toString(), isNot(contains('senha-dev')));
  });

  test('should not expose the password in the register event text', () {
    const event = AuthRegisterSubmitted(
      name: 'Ana Souza',
      email: 'ana.souza@pouapp.dev',
      password: 'senha-dev',
    );

    expect(event.toString(), isNot(contains('senha-dev')));
  });

  group('AuthSessionRequested', () {
    blocTest<AuthBloc, AuthState>(
      'should emit [AuthChecking, Authenticated] when a session exists',
      build: buildBloc,
      setUp: () {
        when(() => mockGetCurrentUser(any()))
            .thenAnswer((_) async => const Right(tUser));
      },
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => const <AuthState>[
        AuthChecking(),
        Authenticated(user: tUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'should emit [AuthChecking, Unauthenticated] when there is no session',
      build: buildBloc,
      setUp: () {
        when(() => mockGetCurrentUser(any()))
            .thenAnswer((_) async => const Right(null));
      },
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => const <AuthState>[AuthChecking(), Unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'should emit [AuthChecking, Unauthenticated] when the session cannot be read',
      build: buildBloc,
      setUp: () {
        when(() => mockGetCurrentUser(any()))
            .thenAnswer((_) async => const Left(CacheFailure()));
      },
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => const <AuthState>[AuthChecking(), Unauthenticated()],
    );
  });

  group('AuthLoginSubmitted', () {
    blocTest<AuthBloc, AuthState>(
      'should emit [AuthLoginInProgress, Authenticated] when login succeeds',
      build: buildBloc,
      setUp: () {
        when(() => mockLogin(any()))
            .thenAnswer((_) async => const Right(tUser));
      },
      act: (bloc) => bloc.add(
        const AuthLoginSubmitted(
          email: '  ana.souza@pouapp.dev  ',
          password: 'senha-dev',
        ),
      ),
      expect: () => const <AuthState>[
        AuthLoginInProgress(),
        Authenticated(user: tUser),
      ],
      verify: (_) {
        verify(
          () => mockLogin(
            const Params(email: 'ana.souza@pouapp.dev', password: 'senha-dev'),
          ),
        ).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'should emit [AuthLoginInProgress, AuthFailure] when credentials are invalid',
      build: buildBloc,
      setUp: () {
        when(() => mockLogin(any()))
            .thenAnswer((_) async => const Left(InvalidCredentialsFailure()));
      },
      act: (bloc) => bloc.add(
        const AuthLoginSubmitted(
          email: 'ana.souza@pouapp.dev',
          password: 'errada',
        ),
      ),
      expect: () => const <AuthState>[
        AuthLoginInProgress(),
        AuthFailure(message: 'E-mail ou senha inválidos.'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'should emit a session message when the session cannot be saved',
      build: buildBloc,
      setUp: () {
        when(() => mockLogin(any()))
            .thenAnswer((_) async => const Left(CacheFailure()));
      },
      act: (bloc) => bloc.add(
        const AuthLoginSubmitted(
          email: 'ana.souza@pouapp.dev',
          password: 'senha-dev',
        ),
      ),
      expect: () => const <AuthState>[
        AuthLoginInProgress(),
        AuthFailure(
          message: 'Não foi possível salvar a sessão. Tente novamente.',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'should emit a generic message when login fails unexpectedly',
      build: buildBloc,
      setUp: () {
        when(() => mockLogin(any()))
            .thenAnswer((_) async => const Left(ServerFailure()));
      },
      act: (bloc) => bloc.add(
        const AuthLoginSubmitted(
          email: 'ana.souza@pouapp.dev',
          password: 'senha-dev',
        ),
      ),
      expect: () => const <AuthState>[
        AuthLoginInProgress(),
        AuthFailure(message: 'Não foi possível entrar. Tente novamente.'),
      ],
    );
  });

  group('AuthRegisterSubmitted', () {
    blocTest<AuthBloc, AuthState>(
      'should emit [AuthRegisterInProgress, Authenticated] when registration succeeds',
      build: buildBloc,
      setUp: () {
        when(() => mockRegister(any()))
            .thenAnswer((_) async => const Right(tUser));
      },
      act: (bloc) => bloc.add(
        const AuthRegisterSubmitted(
          name: '  Ana Souza  ',
          email: '  ana.souza@pouapp.dev  ',
          password: 'senha-dev',
        ),
      ),
      expect: () => const <AuthState>[
        AuthRegisterInProgress(),
        Authenticated(user: tUser),
      ],
      verify: (_) {
        verify(
          () => mockRegister(
            const RegisterParams(
              name: 'Ana Souza',
              email: 'ana.souza@pouapp.dev',
              password: 'senha-dev',
            ),
          ),
        ).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'should emit a message when the email is already in use',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRegister(any()),
        ).thenAnswer((_) async => const Left(EmailAlreadyRegisteredFailure()));
      },
      act: (bloc) => bloc.add(
        const AuthRegisterSubmitted(
          name: 'Ana Souza',
          email: 'ana.souza@pouapp.dev',
          password: 'senha-dev',
        ),
      ),
      expect: () => const <AuthState>[
        AuthRegisterInProgress(),
        AuthRegisterFailure(message: 'Este e-mail já está em uso.'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'should emit a generic message when registration fails unexpectedly',
      build: buildBloc,
      setUp: () {
        when(() => mockRegister(any()))
            .thenAnswer((_) async => const Left(ServerFailure()));
      },
      act: (bloc) => bloc.add(
        const AuthRegisterSubmitted(
          name: 'Ana Souza',
          email: 'ana.souza@pouapp.dev',
          password: 'senha-dev',
        ),
      ),
      expect: () => const <AuthState>[
        AuthRegisterInProgress(),
        AuthRegisterFailure(
          message: 'Não foi possível criar a conta. Tente novamente.',
        ),
      ],
    );
  });

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'should emit [AuthLogoutInProgress, Unauthenticated] when logout succeeds',
      build: buildBloc,
      seed: () => const Authenticated(user: tUser),
      setUp: () {
        when(() => mockLogout(any()))
            .thenAnswer((_) async => const Right(unit));
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => <AuthState>[
        const AuthLogoutInProgress(user: tUser),
        const Unauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'should keep the user authenticated when logout fails',
      build: buildBloc,
      seed: () => const Authenticated(user: tUser),
      setUp: () {
        when(() => mockLogout(any()))
            .thenAnswer((_) async => const Left(CacheFailure()));
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => const <AuthState>[
        AuthLogoutInProgress(user: tUser),
        Authenticated(
          user: tUser,
          errorMessage: 'Não foi possível sair. Tente novamente.',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'should ignore logout when there is no authenticated user',
      build: buildBloc,
      seed: () => const Unauthenticated(),
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => const <AuthState>[],
      verify: (_) {
        verifyNever(() => mockLogout(any()));
      },
    );
  });
}
