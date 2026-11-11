import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/failures/auth_failures.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/register_account.dart';
import '../../domain/usecases/update_user_name.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this.login,
    required this.registerAccount,
    required this.getCurrentUser,
    required this.logout,
    required this.updateUserName,
  }) : super(const AuthInitial()) {
    on<AuthSessionRequested>(_onSessionRequested);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthRegisterSubmitted>(_onRegisterSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthNameSubmitted>(_onNameSubmitted);
  }

  final Login login;
  final RegisterAccount registerAccount;
  final GetCurrentUser getCurrentUser;
  final Logout logout;
  final UpdateUserName updateUserName;

  Future<void> _onSessionRequested(
    AuthSessionRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Keep the shell mounted when refreshing an already-authenticated session
    // (e.g. after editing the display name).
    final refreshing = state is Authenticated || state is AuthLogoutInProgress;
    if (!refreshing) emit(const AuthChecking());
    final result = await getCurrentUser(const NoParams());
    result.fold((_) => emit(const Unauthenticated()), (user) {
      if (user == null) {
        emit(const Unauthenticated());
      } else {
        emit(Authenticated(user: user));
      }
    });
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoginInProgress());
    final result = await login(
      Params(email: event.email.trim(), password: event.password),
    );
    result.fold(
      (failure) => emit(AuthFailure(message: _loginFailureMessage(failure))),
      (user) => emit(Authenticated(user: user)),
    );
  }

  Future<void> _onRegisterSubmitted(
    AuthRegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthRegisterInProgress());
    final result = await registerAccount(
      RegisterParams(
        name: event.name.trim(),
        email: event.email.trim(),
        password: event.password,
      ),
    );
    result.fold(
      (failure) =>
          emit(AuthRegisterFailure(message: _registerFailureMessage(failure))),
      (user) => emit(Authenticated(user: user)),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! Authenticated) return;

    final user = current.user;
    emit(AuthLogoutInProgress(user: user));
    final result = await logout(const NoParams());
    result.fold(
      (_) => emit(
        Authenticated(
          user: user,
          errorMessage: 'Não foi possível sair. Tente novamente.',
        ),
      ),
      (_) => emit(const Unauthenticated()),
    );
  }

  Future<void> _onNameSubmitted(
    AuthNameSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! Authenticated) return;

    final result = await updateUserName(
      UpdateUserNameParams(name: event.name.trim()),
    );
    result.fold(
      (failure) => emit(
        Authenticated(
          user: current.user,
          errorMessage: switch (failure) {
            NetworkFailure() =>
              'Sem conexão. Verifique a internet e tente de novo.',
            _ => 'Não foi possível salvar o nome. Tente novamente.',
          },
        ),
      ),
      (user) => emit(Authenticated(user: user)),
    );
  }

  String _loginFailureMessage(Failure failure) {
    return switch (failure) {
      InvalidCredentialsFailure() => 'E-mail ou senha inválidos.',
      NetworkFailure() => 'Sem conexão. Verifique a internet e tente de novo.',
      CacheFailure() => 'Não foi possível salvar a sessão. Tente novamente.',
      _ => 'Não foi possível entrar. Tente novamente.',
    };
  }

  String _registerFailureMessage(Failure failure) {
    return switch (failure) {
      EmailAlreadyRegisteredFailure() => 'Este e-mail já está em uso.',
      NetworkFailure() => 'Sem conexão. Verifique a internet e tente de novo.',
      CacheFailure() => 'Não foi possível salvar a sessão. Tente novamente.',
      _ => 'Não foi possível criar a conta. Tente novamente.',
    };
  }
}
