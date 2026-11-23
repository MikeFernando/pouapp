import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/business_setup_use_cases.dart';
import 'business_setup_event.dart';
import 'business_setup_state.dart';

class BusinessSetupBloc extends Bloc<BusinessSetupEvent, BusinessSetupState> {
  BusinessSetupBloc({
    required this.getBusinessSetup,
    required this.saveBusinessSetup,
  }) : super(const BusinessSetupInitial()) {
    on<BusinessSetupLoadRequested>(_onLoad);
    on<BusinessSetupSaveRequested>(_onSave);
    on<BusinessSetupReset>(_onReset);
  }

  final GetBusinessSetup getBusinessSetup;
  final SaveBusinessSetup saveBusinessSetup;
  var _loadEpoch = 0;
  var _saveEpoch = 0;
  var _saving = false;

  Future<void> _onLoad(
    BusinessSetupLoadRequested event,
    Emitter<BusinessSetupState> emit,
  ) async {
    final loadEpoch = ++_loadEpoch;
    final saveEpoch = _saveEpoch;
    final current = state;
    final alreadyKnown =
        (current is BusinessSetupReady &&
            current.setup.userId == event.userId) ||
        (current is BusinessSetupPending && current.userId == event.userId) ||
        (current is BusinessSetupSaving && current.userId == event.userId) ||
        (current is BusinessSetupSaveFailed && current.userId == event.userId);
    if (!alreadyKnown) emit(BusinessSetupLoading(event.userId));

    final result = await getBusinessSetup(
      BusinessSetupUserParams(event.userId),
    );
    if (loadEpoch != _loadEpoch || saveEpoch != _saveEpoch) return;
    result.fold(
      (failure) => emit(
        BusinessSetupUnavailable(
          userId: event.userId,
          message: _message(failure),
        ),
      ),
      (setup) {
        if (setup.isConfigured) {
          emit(BusinessSetupReady(setup));
        } else {
          emit(BusinessSetupPending(setup.userId));
        }
      },
    );
  }

  Future<void> _onSave(
    BusinessSetupSaveRequested event,
    Emitter<BusinessSetupState> emit,
  ) async {
    if (_saving) return;
    _saving = true;
    final saveEpoch = ++_saveEpoch;
    emit(BusinessSetupSaving(userId: event.userId, kind: event.kind));
    try {
      final result = await saveBusinessSetup(
        SaveBusinessSetupParams(userId: event.userId, kind: event.kind),
      );
      if (saveEpoch != _saveEpoch) return;
      result.fold(
        (failure) => emit(
          BusinessSetupSaveFailed(
            userId: event.userId,
            kind: event.kind,
            message: _message(failure),
          ),
        ),
        (setup) {
          if (!setup.isConfigured || setup.kind != event.kind) {
            emit(
              BusinessSetupSaveFailed(
                userId: event.userId,
                kind: event.kind,
                message: 'Não foi possível salvar. Tente novamente.',
              ),
            );
            return;
          }
          emit(BusinessSetupReady(setup));
        },
      );
    } finally {
      if (saveEpoch == _saveEpoch) _saving = false;
    }
  }

  void _onReset(BusinessSetupReset event, Emitter<BusinessSetupState> emit) {
    _loadEpoch++;
    _saveEpoch++;
    _saving = false;
    emit(const BusinessSetupInitial());
  }

  String _message(Failure failure) {
    return switch (failure) {
      NetworkFailure() => 'Sem conexão. Verifique a internet e tente de novo.',
      _ => 'Não foi possível salvar. Tente novamente.',
    };
  }
}
