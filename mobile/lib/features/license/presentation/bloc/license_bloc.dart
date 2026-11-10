import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/check_license.dart';
import '../../domain/repositories/license_repository.dart';
import 'license_event.dart';
import 'license_state.dart';

class LicenseBloc extends Bloc<LicenseEvent, LicenseState> {
  LicenseBloc({
    required this.checkLicense,
    required this.repository,
  }) : super(const LicenseInitial()) {
    on<LicenseCheckRequested>(_onCheckRequested);
    on<LicenseCacheCleared>(_onCacheCleared);
  }

  final CheckLicense checkLicense;
  final LicenseRepository repository;

  Future<void> _onCheckRequested(
    LicenseCheckRequested event,
    Emitter<LicenseState> emit,
  ) async {
    emit(const LicenseChecking());
    final result = await checkLicense(
      CheckLicenseParams(forceRemote: event.forceRemote),
    );
    result.fold(
      (failure) => emit(
        LicenseCheckFailed(message: _failureMessage(failure)),
      ),
      (status) {
        if (status.active) {
          emit(LicenseActive(status: status));
        } else {
          emit(LicenseBlocked(status: status));
        }
      },
    );
  }

  Future<void> _onCacheCleared(
    LicenseCacheCleared event,
    Emitter<LicenseState> emit,
  ) async {
    await repository.clearCache();
    emit(const LicenseInitial());
  }

  String _failureMessage(Failure failure) {
    return switch (failure) {
      NetworkFailure() =>
        'Sem conexão. Não foi possível validar o acesso ao serviço.',
      _ => 'Não foi possível validar o acesso. Tente novamente.',
    };
  }
}
