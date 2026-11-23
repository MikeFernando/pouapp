import 'package:equatable/equatable.dart';

import '../../domain/entities/business_setup.dart';

abstract class BusinessSetupState extends Equatable {
  const BusinessSetupState();

  @override
  List<Object?> get props => [];
}

class BusinessSetupInitial extends BusinessSetupState {
  const BusinessSetupInitial();
}

class BusinessSetupLoading extends BusinessSetupState {
  const BusinessSetupLoading(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class BusinessSetupPending extends BusinessSetupState {
  const BusinessSetupPending(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class BusinessSetupSaving extends BusinessSetupState {
  const BusinessSetupSaving({required this.userId, required this.kind});

  final String userId;
  final BusinessKind kind;

  @override
  List<Object?> get props => [userId, kind];
}

class BusinessSetupSaveFailed extends BusinessSetupState {
  const BusinessSetupSaveFailed({
    required this.userId,
    required this.kind,
    required this.message,
  });

  final String userId;
  final BusinessKind kind;
  final String message;

  @override
  List<Object?> get props => [userId, kind, message];
}

class BusinessSetupReady extends BusinessSetupState {
  const BusinessSetupReady(this.setup);

  final BusinessSetup setup;

  @override
  List<Object?> get props => [setup];
}

class BusinessSetupUnavailable extends BusinessSetupState {
  const BusinessSetupUnavailable({required this.userId, required this.message});

  final String userId;
  final String message;

  @override
  List<Object?> get props => [userId, message];
}
