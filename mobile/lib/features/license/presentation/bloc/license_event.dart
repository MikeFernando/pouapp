import 'package:equatable/equatable.dart';

abstract class LicenseEvent extends Equatable {
  const LicenseEvent();

  @override
  List<Object?> get props => [];
}

class LicenseCheckRequested extends LicenseEvent {
  const LicenseCheckRequested({this.forceRemote = false});

  final bool forceRemote;

  @override
  List<Object?> get props => [forceRemote];
}

class LicenseCacheCleared extends LicenseEvent {
  const LicenseCacheCleared();
}
