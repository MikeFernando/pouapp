import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/assistant/domain/devices/voice_devices.dart';
import 'package:pouapp/features/assistant/domain/entities/voice_command.dart';
import 'package:pouapp/features/assistant/domain/repositories/voice_repository.dart';
import 'package:pouapp/features/assistant/domain/usecases/voice_use_cases.dart';
import 'package:pouapp/features/assistant/presentation/bloc/voice_assistant_bloc.dart';
import 'package:pouapp/features/assistant/presentation/widgets/voice_assistant_sheet.dart';

void main() {
  testWidgets('denied permission explains without a text field', (
    tester,
  ) async {
    final capture = _Capture(problem: VoiceCaptureProblem.permissionDenied);
    final speaker = _Speaker();
    await _open(tester, capture: capture, speaker: speaker, voice: _Voice());

    expect(find.text('Erro'), findsNothing);
    expect(find.text('Pode falar'), findsNothing);
    expect(find.text('Digitar'), findsNothing);
    expect(find.textContaining('microfone não foi permitido'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(capture.listens, 0);
    expect(speaker.spoken, isEmpty);
  });

  testWidgets('cancel stops the microphone and does not keep listening', (
    tester,
  ) async {
    final capture = _Capture();
    await _open(tester, capture: capture, speaker: _Speaker(), voice: _Voice());
    expect(find.text('Pode falar'), findsOneWidget);
    expect(find.text('Ouvindo…'), findsOneWidget);
    expect(find.text('Digitar'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Cadastrar apelido'), findsNothing);
    expect(find.text('Erro'), findsNothing);

    await tester.tap(find.byKey(const Key('voice_cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voice_phase')), findsNothing);
    expect(capture.cancels, greaterThanOrEqualTo(1));
    expect(capture.listens, 1);
  });

  testWidgets('recognition failure and a missing network stay on the error', (
    tester,
  ) async {
    final network = _Capture(duringListen: VoiceCaptureProblem.network);
    await _open(tester, capture: network, speaker: _Speaker(), voice: _Voice());
    expect(find.textContaining('sem internet'), findsOneWidget);
    expect(network.listens, 1);

    await tester.tap(find.byKey(const Key('voice_retry')));
    await tester.pumpAndSettle();
    expect(network.listens, 2);
    expect(find.textContaining('sem internet'), findsOneWidget);
  });

  testWidgets('a recognition failure resumes once and then waits', (
    tester,
  ) async {
    final failed = _Capture(duringListen: VoiceCaptureProblem.failed);
    await _open(tester, capture: failed, speaker: _Speaker(), voice: _Voice());
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Não consegui ouvir'), findsOneWidget);
    expect(find.text('Retomar'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(failed.listens, 2);
  });

  testWidgets('the answer stays on screen and is not spoken', (tester) async {
    final capture = _Capture();
    final speaker = _Speaker();
    final voice = _Voice();
    await _open(tester, capture: capture, speaker: speaker, voice: voice);

    await _say(tester, 'Adicione um quilo de abacaxi para Adriele JP.');
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Pode falar'), findsNothing);
    expect(find.textContaining('Adicionei 1 quilo'), findsWidgets);
    expect(find.text('Ler a resposta'), findsNothing);
    expect(speaker.spoken, isEmpty);
    expect(capture.listens, 2);

    await tester.tap(find.byKey(const Key('voice_settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice_speak_toggle')), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Fechar').last);
    await tester.pumpAndSettle();
    await _say(tester, 'Adicione um quilo de abacaxi para Adriele JP.');

    expect(speaker.spoken, isEmpty);
    expect(voice.submits, hasLength(2));
    expect(
      voice.submits.first.executionId,
      isNot(voice.submits.last.executionId),
    );
  });

  testWidgets('stop and closing ignore a late transcript', (tester) async {
    final capture = _Capture();
    final voice = _Voice();
    await _open(tester, capture: capture, speaker: _Speaker(), voice: voice);
    final late = capture.onText!;
    await tester.tap(find.byKey(const Key('voice_stop')));
    await tester.pumpAndSettle();
    late('Adicione um quilo de abacaxi para Adriele JP.', true);
    await tester.pump();
    expect(voice.submits, isEmpty);
    expect(find.text('Parado.'), findsOneWidget);
    expect(find.text('Ouvindo…'), findsNothing);

    await tester.tap(find.byKey(const Key('voice_retry')));
    await tester.pumpAndSettle();
    final after = capture.onText!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    after('Adicione um quilo de abacaxi para Adriele JP.', true);
    await tester.pump();
    expect(voice.submits, isEmpty);
    expect(find.text('Ouvindo…'), findsNothing);
  });

  testWidgets('a spoken name chooses one of the customers', (tester) async {
    final voice = _Voice(
      outcomes: [
        VoiceOutcome(
          kind: VoiceOutcomeKind.clarify,
          message: 'Encontrei mais de uma cliente. Qual delas?',
          understood: 'Encontrei mais de uma cliente. Qual delas?',
          spoken: 'Qual delas?',
          choices: const [
            VoiceChoice(id: 'customer:souza', label: 'Maria Souza · Centro'),
            VoiceChoice(id: 'customer:lima', label: 'Maria Lima · Vila Nova'),
          ],
          command: const VoiceCommand(
            intent: VoiceIntent.consultAccount,
            transcript: 'Quanto a Maria me deve?',
            customerQuery: 'maria',
          ),
        ),
        VoiceOutcome(
          kind: VoiceOutcomeKind.completed,
          message: 'Maria Souza, do Centro, deve R\$ 150,00.',
          understood: 'Consultar a conta de Maria Souza',
          spoken: 'Maria Souza deve 150 reais.',
          account: const VoiceAccountBrief(
            customerId: 'souza',
            name: 'Maria Souza',
            neighborhood: 'Centro',
            balanceCents: 15000,
            overdueCents: 15000,
            creditCents: 0,
            notes: [
              VoiceDebtNote(
                description: 'Saldo inicial',
                amountCents: 15000,
                openCents: 15000,
                dueOn: '2026-10-01',
                overdue: true,
                legacyWithoutItems: true,
              ),
            ],
          ),
        ),
      ],
    );
    await _open(tester, capture: _Capture(), speaker: _Speaker(), voice: voice);

    await _say(tester, 'Quanto a Maria me deve?');
    expect(
      find.text('Encontrei mais de uma cliente. Qual delas?'),
      findsOneWidget,
    );
    expect(find.text('Maria Souza · Centro'), findsOneWidget);

    await _say(tester, 'Maria Souza');

    expect(voice.submits.last.choiceId, 'customer:souza');
    expect(voice.submits.first.executionId, voice.submits.last.executionId);
    expect(find.byKey(const Key('voice_account')), findsOneWidget);
    expect(find.textContaining('Registro sem itens'), findsOneWidget);
    expect(find.textContaining('R\$ 150,00'), findsWidgets);
  });

  testWidgets('two finals of one listen share the execution', (tester) async {
    final capture = _Capture();
    final voice = _Voice();
    await _open(tester, capture: capture, speaker: _Speaker(), voice: voice);
    const phrase = 'Adicione um quilo de abacaxi para Adriele JP.';
    capture.onText!(phrase, true);
    capture.onText!(phrase, true);
    await tester.pumpAndSettle();
    expect(voice.submits, hasLength(2));
    expect(voice.submits.first.executionId, voice.submits.last.executionId);
  });

  testWidgets('a transcript after cancel does not run', (tester) async {
    final capture = _Capture();
    final voice = _Voice();
    await _open(tester, capture: capture, speaker: _Speaker(), voice: voice);
    final late = capture.onText!;
    await tester.tap(find.byKey(const Key('voice_cancel')));
    await tester.pumpAndSettle();
    late('Adicione um quilo de abacaxi para Adriele JP.', true);
    await tester.pump();
    expect(voice.submits, isEmpty);
  });

  testWidgets('Maria do Jardim Paraíso keeps the product and quantity', (
    tester,
  ) async {
    final voice = _Voice(
      outcomes: [
        const VoiceOutcome(
          kind: VoiceOutcomeKind.clarify,
          message: 'Qual delas?',
          spoken: 'Qual delas?',
          choices: [
            VoiceChoice(
              id: 'customer:souza',
              label: 'Maria Souza · Jardim Paraíso',
            ),
            VoiceChoice(id: 'customer:lima', label: 'Maria Lima · Centro'),
          ],
          command: VoiceCommand(
            intent: VoiceIntent.addDraftItem,
            transcript: 'Adicione um quilo de abacaxi para Maria.',
            customerQuery: 'maria',
            productQuery: 'abacaxi',
            quantity: 1,
            unit: VoiceUnit.kilogram,
            gap: VoiceGap.customer,
          ),
        ),
        const VoiceOutcome(
          kind: VoiceOutcomeKind.completed,
          message: 'Adicionei 1 quilo de abacaxi.',
          spoken: 'Adicionei 1 quilo de abacaxi.',
          executionId: 'exec-kept',
        ),
      ],
    );
    await _open(tester, capture: _Capture(), speaker: _Speaker(), voice: voice);
    await _say(tester, 'Adicione um quilo de abacaxi para Maria.');
    await _say(tester, 'Maria do Jardim Paraíso');

    final reply = voice.submits.last;
    expect(reply.choiceId, isNull);
    expect(reply.pending?.productQuery, 'abacaxi');
    expect(reply.pending?.quantity, 1);
    expect(reply.pending?.unit, VoiceUnit.kilogram);
    expect(reply.executionId, voice.submits.first.executionId);
  });
}

Future<void> _say(WidgetTester tester, String text) async {
  tester
      .element(find.byType(VoiceAssistantSheet))
      .read<VoiceAssistantBloc>()
      .add(VoiceTextSubmitted(text));
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester, {
  required _Capture capture,
  required _Speaker speaker,
  required _Voice voice,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) {
                    return BlocProvider(
                      create: (_) => VoiceAssistantBloc(
                        submit: SubmitVoiceCommand(voice),
                        undo: UndoVoiceCommand(voice),
                        saveAlias: SaveVoiceAlias(voice),
                        capture: capture,
                        speaker: speaker,
                      ),
                      child: const VoiceAssistantSheet(),
                    );
                  },
                );
              },
              child: const Text('Abrir'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

class _Capture implements VoiceCapture {
  _Capture({this.problem, this.duringListen});

  final VoiceCaptureProblem? problem;
  final VoiceCaptureProblem? duringListen;
  int listens = 0;
  int cancels = 0;
  void Function(String text, bool isFinal)? onText;

  @override
  Future<VoiceCaptureProblem?> prepare() async => problem;

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onText,
    void Function(VoiceCaptureProblem problem)? onProblem,
  }) async {
    listens++;
    this.onText = onText;
    final failure = duringListen;
    if (failure != null) onProblem?.call(failure);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class _Speaker implements VoiceSpeaker {
  final spoken = <String>[];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

class _Voice implements VoiceRepository {
  _Voice({List<VoiceOutcome>? outcomes}) : _outcomes = outcomes ?? _done;

  static final _done = [
    const VoiceOutcome(
      kind: VoiceOutcomeKind.completed,
      message:
          'Adicionei 1 quilo de abacaxi na nota. Isso ainda não é uma venda.',
      understood: 'Adicionar abacaxi para Adriele',
      spoken: 'Adicionei 1 quilo de abacaxi.',
      executionId: 'fp-1',
    ),
  ];

  final List<VoiceOutcome> _outcomes;
  final submits = <SubmitVoiceParams>[];

  @override
  Future<Either<Failure, VoiceOutcome>> submit({
    required String transcript,
    required String executionId,
    VoiceCommand? pending,
    String? choiceId,
    DateTime? today,
    String? contextCustomerId,
    String? contextLabel,
    bool contextFresh = false,
  }) async {
    submits.add(
      SubmitVoiceParams(
        transcript: transcript,
        executionId: executionId,
        pending: pending,
        choiceId: choiceId,
        today: today,
        contextCustomerId: contextCustomerId,
        contextLabel: contextLabel,
        contextFresh: contextFresh,
      ),
    );
    final index = submits.length - 1;
    return Right(
      _outcomes[index < _outcomes.length ? index : _outcomes.length - 1],
    );
  }

  @override
  Future<Either<Failure, VoiceOutcome>> undo(String executionId) async {
    return const Right(
      VoiceOutcome(kind: VoiceOutcomeKind.undone, message: 'Desfeito.'),
    );
  }

  @override
  Future<Either<Failure, Unit>> saveAlias({
    required VoiceAliasKind kind,
    required String alias,
    required String target,
  }) async {
    return const Right(unit);
  }
}
