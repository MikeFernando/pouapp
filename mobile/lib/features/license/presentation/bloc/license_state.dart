import 'package:equatable/equatable.dart';

import '../../domain/entities/license_status.dart';

abstract class LicenseState extends Equatable {
  const LicenseState();

  @override
  List<Object?> get props => [];
}

class LicenseInitial extends LicenseState {
  const LicenseInitial();
}

class LicenseChecking extends LicenseState {
  const LicenseChecking();
}

class LicenseActive extends LicenseState {
  const LicenseActive({required this.status});

  final LicenseStatus status;

  @override
  List<Object?> get props => [status];
}

class LicenseBlocked extends LicenseState {
  const LicenseBlocked({required this.status});

  final LicenseStatus status;

  @override
  List<Object?> get props => [status];
}

class LicenseCheckFailed extends LicenseState {
  const LicenseCheckFailed({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
