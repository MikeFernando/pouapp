import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/devices/voice_devices.dart';
import '../../domain/entities/voice_command.dart';
import '../../domain/rules/voice_interpreter.dart';
import '../../domain/usecases/voice_use_cases.dart';
import '../../domain/voice_text.dart';

enum VoicePhase {
  waiting,
  listening,
  transcribing,
  interpreting,
  clarifying,
  done,
  error,
}

class VoiceAssistantState extends Equatable {
  const VoiceAssistantState({
    this.phase = VoicePhase.waiting,
    this.transcript = '',
    this.understood = '',
    this.message = '',
    this.choices = const [],
    this.command,
    this.account,
    this.executionId,
    this.speakEnabled = true,
    this.permissionDenied = false,
    this.needsNetwork = false,
    this.attendingId,
    this.attendingLabel,
    this.attendingAt,
    this.openNote = false,
    this.note,
    this.hold = false,
  });

  final VoicePhase phase;
  final String transcript;
  final String understood;
  final String message;
  final List<VoiceChoice> choices;
  final VoiceCommand? command;
  final VoiceAccountBrief? account;
  final String? executionId;
  final bool speakEnabled;
  final bool permissionDenied;
  final bool needsNetwork;
  final String? attendingId;
  final String? attendingLabel;
  final DateTime? attendingAt;
  final bool openNote;
  final VoiceNoteBrief? note;
  final bool hold;

  VoiceAssistantState copyWith({
    VoicePhase? phase,
    String? transcript,
    String? understood,
    String? message,
    List<VoiceChoice>? choices,
    VoiceCommand? command,
    VoiceAccountBrief? account,
    String? executionId,
    bool? speakEnabled,
    bool? permissionDenied,
    bool? needsNetwork,
    String? attendingId,
    String? attendingLabel,
    DateTime? attendingAt,
    bool openNote = false,
    VoiceNoteBrief? note,
    bool? hold,
    bool clearNote = false,
    bool clearAccount = false,
    bool clearExecution = false,
    bool clearCommand = false,
    bool clearAttending = false,
  }) {
    return VoiceAssistantState(
      phase: phase ?? this.phase,
      transcript: transcript ?? this.transcript,
      understood: understood ?? this.understood,
      message: message ?? this.message,
      choices: choices ?? this.choices,
      command: clearCommand ? null : command ?? this.command,
      account: clearAccount ? null : account ?? this.account,
      executionId: clearExecution ? null : executionId ?? this.executionId,
      speakEnabled: speakEnabled ?? this.speakEnabled,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      needsNetwork: needsNetwork ?? this.needsNetwork,
      attendingId: clearAttending ? null : attendingId ?? this.attendingId,
      attendingLabel: clearAttending
          ? null
          : attendingLabel ?? this.attendingLabel,
      attendingAt: clearAttending ? null : attendingAt ?? this.attendingAt,
      openNote: openNote,
      note: clearNote ? null : note ?? this.note,
      hold: hold ?? this.hold,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    transcript,
    understood,
    message,
    choices,
    command,
    account,
    executionId,
    speakEnabled,
    permissionDenied,
    needsNetwork,
    attendingId,
    attendingLabel,
    attendingAt,
    openNote,
    note,
    hold,
  ];
}

const _attendanceLimit = Duration(minutes: 3);

const _yes = {
  'sim',
  'isso',
  'pode',
  'continuar',
  'continua',
  'confirma',
  'confirmo',
  'ela',
  'ele',
};

sealed class VoiceAssistantEvent extends Equatable {
  const VoiceAssistantEvent();

  @override
  List<Object?> get props => [];
}

class VoiceOpened extends VoiceAssistantEvent {
  const VoiceOpened();
}

class VoicePartialReceived extends VoiceAssistantEvent {
  const VoicePartialReceived(this.text, this.generation);

  final String text;
  final int generation;

  @override
  List<Object?> get props => [text, generation];
}

class VoiceFinalReceived extends VoiceAssistantEvent {
  const VoiceFinalReceived(this.text, this.generation);

  final String text;
  final int generation;

  @override
  List<Object?> get props => [text, generation];
}

class VoiceStopRequested extends VoiceAssistantEvent {
  const VoiceStopRequested();
}

class VoiceCancelRequested extends VoiceAssistantEvent {
  const VoiceCancelRequested();
}

class VoiceRetryRequested extends VoiceAssistantEvent {
  const VoiceRetryRequested();
}

class VoiceTextSubmitted extends VoiceAssistantEvent {
  const VoiceTextSubmitted(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

class VoiceChoiceSelected extends VoiceAssistantEvent {
  const VoiceChoiceSelected(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

class VoiceUndoRequested extends VoiceAssistantEvent {
  const VoiceUndoRequested();
}

class VoiceSpeakToggled extends VoiceAssistantEvent {
  const VoiceSpeakToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class VoiceResumeRequested extends VoiceAssistantEvent {
  const VoiceResumeRequested();
}

class VoiceBackgrounded extends VoiceAssistantEvent {
  const VoiceBackgrounded();
}

class VoiceForegrounded extends VoiceAssistantEvent {
  const VoiceForegrounded();
}

class VoiceCaptureFailed extends VoiceAssistantEvent {
  const VoiceCaptureFailed(this.problem, this.generation);

  final VoiceCaptureProblem problem;
  final int generation;

  @override
  List<Object?> get props => [problem, generation];
}

class VoiceAssistantBloc
    extends Bloc<VoiceAssistantEvent, VoiceAssistantState> {
  VoiceAssistantBloc({
    required this.submit,
    required this.undo,
    required this.saveAlias,
    required this.capture,
    required this.speaker,
    this.clock,
    VoiceAssistantState? initialState,
  }) : super(initialState ?? const VoiceAssistantState()) {
    on<VoiceOpened>(_onOpened);
    on<VoicePartialReceived>(_onPartial);
    on<VoiceFinalReceived>(_onFinal);
    on<VoiceStopRequested>(_onStop);
    on<VoiceCancelRequested>(_onCancel);
    on<VoiceRetryRequested>(_onRetry);
    on<VoiceTextSubmitted>(_onText);
    on<VoiceChoiceSelected>(_onChoice);
    on<VoiceUndoRequested>(_onUndo);
    on<VoiceSpeakToggled>(_onSpeak);
    on<VoiceResumeRequested>(_onResume);
    on<VoiceBackgrounded>(_onBackground);
    on<VoiceForegrounded>(_onForeground);
    on<VoiceCaptureFailed>(_onFailed);
  }

  final SubmitVoiceCommand submit;
  final UndoVoiceCommand undo;
  final SaveVoiceAlias saveAlias;
  final VoiceCapture capture;
  final VoiceSpeaker speaker;
  final DateTime Function()? clock;
  var _listening = false;
  var _accepting = true;
  var _hold = false;
  var _paused = false;
  var _silence = 0;
  var _misses = 0;
  var _generation = 0;
  Timer? _resumeTimer;
  var _sequence = 0;
  String _executionId = '';

  bool _current(int generation) => _accepting && generation == _generation;

  String _nextExecution() {
    _sequence += 1;
    final now = clock?.call() ?? DateTime.now();
    _executionId = 'exec-${now.microsecondsSinceEpoch}-$_sequence';
    return _executionId;
  }

  void _dropLateResults() {
    _generation += 1;
    _listening = false;
  }

  Future<bool> registerAlias({
    required VoiceAliasKind kind,
    required String alias,
    required String target,
  }) async {
    final result = await saveAlias(
      SaveVoiceAliasParams(kind: kind, alias: alias, target: target),
    );
    return result.isRight();
  }

  void _cancelResume() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
  }

  @override
  Future<void> close() async {
    _accepting = false;
    _cancelResume();
    _dropLateResults();
    await capture.cancel();
    await speaker.stop();
    return super.close();
  }

  Future<void> _onOpened(
    VoiceOpened event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    emit(state.copyWith(phase: VoicePhase.waiting, permissionDenied: false));
    await _listen(emit);
  }

  Future<void> _onPartial(
    VoicePartialReceived event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    if (!_current(event.generation)) return;
    emit(state.copyWith(phase: VoicePhase.listening, transcript: event.text));
  }

  Future<void> _onFinal(
    VoiceFinalReceived event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    if (!_current(event.generation)) return;
    _listening = false;
    await _handleText(event.text, emit, event.generation, sameRequest: true);
  }

  Future<void> _onStop(
    VoiceStopRequested event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    _hold = true;
    _cancelResume();
    _dropLateResults();
    await capture.cancel();
    await speaker.stop();
    if (!_accepting) return;
    emit(
      state.copyWith(phase: VoicePhase.waiting, message: 'Parado.', hold: true),
    );
  }

  Future<void> _onCancel(
    VoiceCancelRequested event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    _cancelResume();
    _dropLateResults();
    await capture.cancel();
    await speaker.stop();
    if (!_accepting) return;
    emit(
      state.copyWith(
        phase: VoicePhase.waiting,
        transcript: '',
        message: 'Cancelado.',
        choices: const [],
        clearAccount: true,
        clearCommand: true,
        clearExecution: true,
      ),
    );
  }

  Future<void> _onRetry(
    VoiceRetryRequested event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    _hold = false;
    _silence = 0;
    _misses = 0;
    _dropLateResults();
    await capture.cancel();
    await speaker.stop();
    if (!_accepting) return;
    final pending = state.command;
    final keep = pending != null && pending.gap != VoiceGap.none;
    emit(
      state.copyWith(
        transcript: '',
        message: '',
        choices: keep ? state.choices : const [],
        clearAccount: true,
        clearCommand: !keep,
        permissionDenied: false,
        needsNetwork: false,
        hold: false,
      ),
    );
    await _listen(emit);
  }

  Future<void> _onText(
    VoiceTextSubmitted event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    _dropLateResults();
    await capture.cancel();
    if (!_accepting) return;
    await _handleText(event.text, emit, _generation, sameRequest: false);
  }

  Future<void> _onChoice(
    VoiceChoiceSelected event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    final generation = _generation;
    await _run(
      emit,
      transcript: state.transcript,
      generation: generation,
      executionId: _executionId.isEmpty ? _nextExecution() : _executionId,
      choiceId: event.id,
      pending: state.command,
    );
  }

  Future<void> _onUndo(
    VoiceUndoRequested event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    final executionId = state.executionId;
    if (executionId == null) return;
    final result = await undo(executionId);
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            phase: VoicePhase.error,
            message: 'Não foi possível desfazer.',
          ),
        );
      },
      (outcome) async {
        emit(
          state.copyWith(
            phase: VoicePhase.done,
            message: outcome.message,
            understood: outcome.understood,
            clearExecution: true,
          ),
        );
      },
    );
  }

  Future<void> _onSpeak(
    VoiceSpeakToggled event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    if (!event.enabled) await speaker.stop();
    emit(state.copyWith(speakEnabled: event.enabled));
  }

  Future<void> _onFailed(
    VoiceCaptureFailed event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    if (!_current(event.generation)) return;
    _listening = false;
    _misses += 1;
    final denied = event.problem == VoiceCaptureProblem.permissionDenied;
    final network = event.problem == VoiceCaptureProblem.network;
    final message = switch (event.problem) {
      VoiceCaptureProblem.permissionDenied =>
        'O microfone não foi permitido. Libere o microfone e tente novamente.',
      VoiceCaptureProblem.network =>
        'Não consegui ouvir sem internet. Tente novamente.',
      VoiceCaptureProblem.unavailable =>
        'A voz não está disponível neste aparelho. Tente novamente.',
      VoiceCaptureProblem.failed => 'Não consegui ouvir. Tente novamente.',
    };
    final hard =
        denied ||
        network ||
        event.problem == VoiceCaptureProblem.unavailable ||
        _misses >= 2;
    if (hard) _hold = true;
    emit(
      state.copyWith(
        phase: VoicePhase.error,
        message: message,
        permissionDenied: denied,
        needsNetwork: network,
        hold: hard,
      ),
    );
    if (!hard) _resumeLater();
  }

  Future<void> _onResume(
    VoiceResumeRequested event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    if (!_accepting || _hold || _paused || _listening) return;
    await _listen(emit);
  }

  Future<void> _onBackground(
    VoiceBackgrounded event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    _paused = true;
    _cancelResume();
    _dropLateResults();
    await capture.cancel();
    await speaker.stop();
    if (!_accepting) return;
    emit(
      state.copyWith(
        phase: VoicePhase.waiting,
        message: state.message.isEmpty ? 'Escuta pausada.' : state.message,
      ),
    );
  }

  Future<void> _onForeground(
    VoiceForegrounded event,
    Emitter<VoiceAssistantState> emit,
  ) async {
    _paused = false;
    if (!_accepting || _hold) return;
    await _listen(emit);
  }

  void _resumeLater() {
    _cancelResume();
    _resumeTimer = Timer(const Duration(milliseconds: 900), () {
      _resumeTimer = null;
      if (!_accepting || _hold || _paused || isClosed) return;
      add(const VoiceResumeRequested());
    });
  }

  Future<void> _listen(Emitter<VoiceAssistantState> emit) async {
    if (_listening || !_accepting || _hold || _paused) return;
    _generation += 1;
    final generation = _generation;
    final problem = await capture.prepare();
    if (!_current(generation)) return;
    if (problem != null) {
      add(VoiceCaptureFailed(problem, generation));
      return;
    }
    _nextExecution();
    _listening = true;
    emit(
      state.copyWith(
        phase: VoicePhase.listening,
        permissionDenied: false,
        needsNetwork: false,
      ),
    );
    await capture.listen(
      onText: (text, isFinal) {
        if (!_current(generation)) return;
        add(
          isFinal
              ? VoiceFinalReceived(text, generation)
              : VoicePartialReceived(text, generation),
        );
      },
      onProblem: (problem) {
        if (!_current(generation)) return;
        add(VoiceCaptureFailed(problem, generation));
      },
    );
  }

  Future<void> _handleText(
    String transcript,
    Emitter<VoiceAssistantState> emit,
    int generation, {
    required bool sameRequest,
  }) async {
    if (!_current(generation)) return;
    final text = transcript.trim();
    if (text.isEmpty) {
      _silence += 1;
      final again = _silence < 3;
      if (!again) _hold = true;
      emit(
        state.copyWith(
          phase: VoicePhase.waiting,
          message: again ? 'Não entendi. Pode repetir.' : 'Não consegui ouvir.',
          hold: !again,
        ),
      );
      if (again) _resumeLater();
      return;
    }
    _silence = 0;
    _misses = 0;
    final choice = _spokenChoice(text);
    final pending = state.command;
    final fresh = interpretVoice(text);
    final waiting =
        pending != null &&
        (pending.gap != VoiceGap.none ||
            pending.reviewToken != null ||
            pending.items.any((item) => item.gap != VoiceGap.none));
    final continues =
        choice == null &&
        waiting &&
        fresh.intent != VoiceIntent.addDraftItem &&
        fresh.intent != VoiceIntent.consultAccount &&
        fresh.intent != VoiceIntent.unsupported;
    final executionId = continues || sameRequest || choice != null
        ? (_executionId.isEmpty ? _nextExecution() : _executionId)
        : _nextExecution();
    await _run(
      emit,
      transcript: text,
      generation: generation,
      executionId: executionId,
      choiceId: choice,
      pending: choice != null || continues ? pending : null,
    );
  }

  String? _spokenChoice(String transcript) {
    if (state.choices.isEmpty) return null;
    final text = foldVoice(transcript);
    if (state.choices.length == 1 && _yes.contains(text)) {
      return state.choices.single.id;
    }
    final hits = [
      for (final choice in state.choices)
        if (_labelMatches(choice.label, text)) choice,
    ];
    if (hits.length != 1) return null;
    return hits.single.id;
  }

  bool _labelMatches(String label, String text) {
    final name = foldVoice(label.split('·').first);
    if (name.isEmpty || text.isEmpty) return false;
    return name == text || text == foldVoice(label);
  }

  Future<void> _run(
    Emitter<VoiceAssistantState> emit, {
    required String transcript,
    required int generation,
    required String executionId,
    String? choiceId,
    VoiceCommand? pending,
  }) async {
    if (!_current(generation)) return;
    emit(
      state.copyWith(
        phase: VoicePhase.interpreting,
        transcript: transcript,
        clearAccount: true,
      ),
    );
    if (!_current(generation)) return;
    final now = clock?.call() ?? DateTime.now();
    final attendedAt = state.attendingAt;
    final result = await submit(
      SubmitVoiceParams(
        transcript: transcript,
        executionId: executionId,
        pending: pending,
        choiceId: choiceId,
        today: now,
        contextCustomerId: state.attendingId,
        contextLabel: state.attendingLabel,
        contextFresh:
            attendedAt != null && now.difference(attendedAt) < _attendanceLimit,
      ),
    );
    if (!_current(generation)) return;
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            phase: VoicePhase.error,
            message: 'Não foi possível concluir o comando.',
            hold: true,
          ),
        );
        _hold = true;
      },
      (outcome) async {
        final phase = switch (outcome.kind) {
          VoiceOutcomeKind.clarify => VoicePhase.clarifying,
          VoiceOutcomeKind.unsupported ||
          VoiceOutcomeKind.blocked => VoicePhase.error,
          _ => VoicePhase.done,
        };
        final place = (outcome.subjectPlace ?? '').trim();
        final label = outcome.subjectName == null
            ? null
            : place.isEmpty
            ? outcome.subjectName
            : '${outcome.subjectName} · $place';
        emit(
          state.copyWith(
            phase: phase,
            understood: outcome.understood,
            message: outcome.message,
            choices: outcome.choices,
            command: outcome.command,
            account: outcome.account,
            executionId: outcome.executionId,
            attendingId: outcome.subjectId,
            attendingLabel: label,
            attendingAt: outcome.subjectId == null ? null : now,
            clearAccount: outcome.account == null,
            clearExecution: outcome.executionId == null,
            clearCommand: outcome.command == null,
            openNote: outcome.openNote,
            note: outcome.note,
            clearNote: outcome.note == null,
            hold: false,
          ),
        );
        _resumeLater();
      },
    );
  }
}
