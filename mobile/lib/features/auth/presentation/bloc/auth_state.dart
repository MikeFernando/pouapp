import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthChecking extends AuthState {
  const AuthChecking();
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthLoginInProgress extends AuthState {
  const AuthLoginInProgress();
}

class Authenticated extends AuthState {
  const Authenticated({required this.user, this.errorMessage});

  final User user;
  final String? errorMessage;

  @override
  List<Object?> get props => [user, errorMessage];
}

class AuthFailure extends AuthState {
  const AuthFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

class AuthLogoutInProgress extends AuthState {
  const AuthLogoutInProgress({required this.user});

  final User user;

  @override
  List<Object?> get props => [user];
}
