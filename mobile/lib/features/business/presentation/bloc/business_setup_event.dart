import 'package:equatable/equatable.dart';

import '../../domain/entities/business_setup.dart';

abstract class BusinessSetupEvent extends Equatable {
  const BusinessSetupEvent();

  @override
  List<Object?> get props => [];
}

class BusinessSetupLoadRequested extends BusinessSetupEvent {
  const BusinessSetupLoadRequested(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class BusinessSetupSaveRequested extends BusinessSetupEvent {
  const BusinessSetupSaveRequested({required this.userId, required this.kind});

  final String userId;
  final BusinessKind kind;

  @override
  List<Object?> get props => [userId, kind];
}

class BusinessSetupReset extends BusinessSetupEvent {
  const BusinessSetupReset();
}
