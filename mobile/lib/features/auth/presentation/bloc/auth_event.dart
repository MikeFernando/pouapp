import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthSessionRequested extends AuthEvent {
  const AuthSessionRequested();
}

class AuthLoginSubmitted extends AuthEvent {
  const AuthLoginSubmitted({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];

  @override
  bool get stringify => false;

  @override
  String toString() => 'AuthLoginSubmitted(email: $email)';
}

class AuthRegisterSubmitted extends AuthEvent {
  const AuthRegisterSubmitted({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;

  @override
  List<Object?> get props => [name, email, password];

  @override
  bool get stringify => false;

  @override
  String toString() => 'AuthRegisterSubmitted(name: $name, email: $email)';
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
