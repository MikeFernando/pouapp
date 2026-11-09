import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../workspace/presentation/operation_labels.dart';
import '../../../workspace/presentation/theme/workspace_colors.dart';
import '../../domain/devices/voice_devices.dart';
import '../../domain/entities/voice_command.dart';
import '../../domain/rules/voice_interpreter.dart';
import '../../domain/usecases/voice_use_cases.dart';
import '../bloc/voice_assistant_bloc.dart';
import '../voice_attendance.dart';

Future<void> openVoiceAssistant(
  BuildContext context, {
  String? customerId,
  String? customerLabel,
  void Function(String customerId)? onOpenNote,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return BlocProvider(
        create: (_) => VoiceAssistantBloc(
          submit: sl<SubmitVoiceCommand>(),
          undo: sl<UndoVoiceCommand>(),
          saveAlias: sl<SaveVoiceAlias>(),
          capture: sl<VoiceCapture>(),
          speaker: sl<VoiceSpeaker>(),
          initialState: customerId == null
              ? null
              : VoiceAssistantState(
                  attendingId: customerId,
                  attendingLabel: customerLabel,
                  attendingAt: DateTime.now(),
                ),
        ),
        child: VoiceAssistantSheet(
          onOpenNote: (savedCustomerId) {
            final visit = VoiceAttendance.current;
            if (visit != null && visit.customerId == savedCustomerId) {
              visit.onChanged();
              return;
            }
            onOpenNote?.call(savedCustomerId);
          },
        ),
      );
    },
  );
}

/// The voice panel that is open, so the microphone can listen again.
class VoiceSession {
  static VoiceAssistantBloc? current;

  static void attach(VoiceAssistantBloc bloc) {
    current = bloc;
  }

  static void detach(VoiceAssistantBloc bloc) {
    if (current == bloc) current = null;
  }
}

class VoiceAssistantSheet extends StatefulWidget {
  const VoiceAssistantSheet({super.key, this.onOpenNote});

  final ValueChanged<String>? onOpenNote;

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  late final VoiceAssistantBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<VoiceAssistantBloc>();
    VoiceSession.attach(_bloc);
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final testing = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (testing) {
      _pulse.value = 1;
    } else {
      _pulse.repeat(reverse: true);
    }
    _bloc.add(const VoiceOpened());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VoiceSession.detach(_bloc);
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _bloc.add(const VoiceBackgrounded());
    } else if (state == AppLifecycleState.resumed) {
      _bloc.add(const VoiceForegrounded());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final colors = workspaceColorsOf(context);
    return BlocConsumer<VoiceAssistantBloc, VoiceAssistantState>(
      listenWhen: (previous, current) => current.openNote && !previous.openNote,
      listener: (context, state) {
        final customerId = state.attendingId;
        final open = widget.onOpenNote;
        if (customerId == null || open == null) return;
        open(customerId);
      },
      builder: (context, state) {
        final listening = state.phase == VoicePhase.listening;
        final working =
            state.phase == VoicePhase.transcribing ||
            state.phase == VoicePhase.interpreting;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 96 + bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(state: state, color: colors.header),
                  const SizedBox(height: 8),
                  if (listening &&
                      state.transcript.isEmpty &&
                      state.message.isEmpty) ...[
                    Text(
                      'Pode falar',
                      key: const Key('voice_prompt'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: colors.header,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Adicione um produto na nota ou pergunte quanto uma cliente deve.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        color: Color(0xFF5C6560),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (state.transcript.isNotEmpty) ...[
                    Text(
                      state.transcript,
                      key: const Key('voice_transcript'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: Color(0xFF1C1C1C),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (listening)
                    _Listening(pulse: _pulse, color: colors.header),
                  if (working)
                    Text(
                      _seeking(state.transcript),
                      key: const Key('voice_status'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.header,
                      ),
                    ),
                  if (state.phase == VoicePhase.clarifying) ...[
                    Text(
                      state.message,
                      key: const Key('voice_result'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final choice in state.choices) ...[
                      OutlinedButton(
                        key: Key('voice_option_${choice.id}'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          alignment: Alignment.centerLeft,
                          foregroundColor: colors.header,
                          side: BorderSide(color: colors.header, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => context.read<VoiceAssistantBloc>().add(
                          VoiceChoiceSelected(choice.id),
                        ),
                        child: Text(choice.label),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  if (state.phase != VoicePhase.clarifying &&
                      state.message.isNotEmpty) ...[
                    _Answer(message: state.message, color: colors.header),
                    if (state.note != null) ...[
                      const SizedBox(height: 12),
                      _NoteBrief(note: state.note!),
                    ],
                    if (state.account != null) ...[
                      const SizedBox(height: 12),
                      _AccountCard(account: state.account!),
                    ],
                  ],
                  if (_needsAlias(state) && !listening && !working) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const Key('voice_alias_button'),
                        onPressed: () => _alias(context),
                        child: const Text('Cadastrar apelido'),
                      ),
                    ),
                  ],
                  if (state.phase == VoicePhase.done &&
                      state.executionId != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const Key('voice_undo'),
                        onPressed: () => context.read<VoiceAssistantBloc>().add(
                          const VoiceUndoRequested(),
                        ),
                        child: const Text('Desfazer este comando'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (listening)
                    _QuietActions(
                      stop: true,
                      again: false,
                      onStop: () => context.read<VoiceAssistantBloc>().add(
                        const VoiceStopRequested(),
                      ),
                    ),
                  if (!listening && state.hold)
                    _QuietActions(
                      stop: false,
                      again: true,
                      onAgain: () => context.read<VoiceAssistantBloc>().add(
                        const VoiceRetryRequested(),
                      ),
                      againLabel: 'Retomar',
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _settings(BuildContext context) async {
    final bloc = context.read<VoiceAssistantBloc>();
    final sheetContext = context;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: bloc,
          child: AlertDialog(
            title: const Text('Configurações do assistente'),
            content: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('voice_settings_alias'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _alias(sheetContext);
                },
                child: const Text('Cadastrar apelido'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _alias(BuildContext context) async {
    final alias = TextEditingController();
    final target = TextEditingController();
    var kind = VoiceAliasKind.neighborhood;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cadastrar apelido'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<VoiceAliasKind>(
                    key: const Key('voice_alias_kind'),
                    value: kind,
                    items: const [
                      DropdownMenuItem(
                        value: VoiceAliasKind.neighborhood,
                        child: Text('Bairro'),
                      ),
                      DropdownMenuItem(
                        value: VoiceAliasKind.customer,
                        child: Text('Cliente'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setLocal(() => kind = value);
                    },
                  ),
                  TextField(
                    key: const Key('voice_alias_name'),
                    controller: alias,
                    decoration: const InputDecoration(labelText: 'Apelido'),
                  ),
                  TextField(
                    key: const Key('voice_alias_target'),
                    controller: target,
                    decoration: InputDecoration(
                      labelText: kind == VoiceAliasKind.customer
                          ? 'Nome da cliente'
                          : 'Nome do bairro',
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              key: const Key('voice_alias_save'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    if (saved != true || !context.mounted) {
      alias.dispose();
      target.dispose();
      return;
    }
    final savedAlias = await context.read<VoiceAssistantBloc>().registerAlias(
      kind: kind,
      alias: alias.text,
      target: target.text,
    );
    alias.dispose();
    target.dispose();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedAlias
              ? 'Apelido cadastrado.'
              : 'Não encontrei uma única cliente com esse nome.',
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.color});

  final VoiceAssistantState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final attending = state.attendingLabel;
    return Row(
      children: [
        Expanded(
          child: Text(
            attending == null ? 'Assistente de voz' : 'Atendendo $attending',
            key: const Key('voice_context'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        IconButton(
          key: const Key('voice_settings'),
          tooltip: 'Configurações do assistente',
          onPressed: () => context
              .findAncestorStateOfType<_VoiceAssistantSheetState>()
              ?._settings(context),
          icon: const Icon(Icons.tune),
        ),
        IconButton(
          key: const Key('voice_cancel'),
          tooltip: 'Cancelar',
          onPressed: () {
            context.read<VoiceAssistantBloc>().add(
              const VoiceCancelRequested(),
            );
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _Listening extends StatelessWidget {
  const _Listening({required this.pulse, required this.color});

  final Animation<double> pulse;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(pulse),
          child: Icon(Icons.mic, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          'Ouvindo…',
          key: const Key('voice_status'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F5F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E5DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          key: const Key('voice_result'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _QuietActions extends StatelessWidget {
  const _QuietActions({
    required this.stop,
    required this.again,
    this.onStop,
    this.onAgain,
    this.againLabel = 'Tentar novamente',
  });

  final bool stop;
  final bool again;
  final VoidCallback? onStop;
  final VoidCallback? onAgain;
  final String againLabel;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (stop)
        TextButton(
          key: const Key('voice_stop'),
          onPressed: onStop,
          child: const Text('Parar'),
        ),
      if (again)
        TextButton(
          key: const Key('voice_retry'),
          onPressed: onAgain,
          child: Text(againLabel),
        ),
    ];
    return Wrap(spacing: 4, children: actions);
  }
}

class _NoteBrief extends StatelessWidget {
  const _NoteBrief({required this.note});

  final VoiceNoteBrief note;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('voice_note'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E5DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in note.lines)
              Text(line, style: const TextStyle(fontSize: 16, height: 1.4)),
            const SizedBox(height: 6),
            Text(
              'Total ${formatBrl(note.totalCents)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final VoiceAccountBrief account;

  @override
  Widget build(BuildContext context) {
    final place = (account.neighborhood ?? '').trim();
    return DecoratedBox(
      key: const Key('voice_account'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E5DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.isEmpty ? account.name : '${account.name} · $place',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text('Saldo devedor ${formatBrl(account.balanceCents)}'),
            Text('Vencido ${formatBrl(account.overdueCents)}'),
            if (account.creditCents > 0)
              Text('Crédito ${formatBrl(account.creditCents)}'),
            for (final note in account.notes) ...[
              const SizedBox(height: 8),
              Text(
                '${note.description} · ${formatBrl(note.openCents)}'
                '${note.dueOn == null ? '' : ' · vence ${note.dueOn}'}'
                '${note.overdue ? ' · vencido' : ''}',
              ),
              if (note.legacyWithoutItems)
                const Text('Registro sem itens detalhados.'),
              for (final line in note.lines) Text(line),
            ],
            for (final payment in account.payments)
              Text(
                'Pagamento ${payment.label} ${formatBrl(payment.amountCents)}'
                '${payment.creditCents > 0 ? ' · crédito ${formatBrl(payment.creditCents)}' : ''}',
              ),
          ],
        ),
      ),
    );
  }
}

bool _needsAlias(VoiceAssistantState state) {
  final text = state.message.toLowerCase();
  return text.contains('abreviação') ||
      text.contains('não encontrei essa cliente');
}

String _seeking(String transcript) {
  final command = interpretVoice(transcript);
  final who = command.customerQuery;
  final what = command.productQuery;
  if (who != null && what != null) {
    return 'Buscando ${_title(who)} e ${_title(what)}…';
  }
  if (who != null) return 'Buscando ${_title(who)}…';
  if (what != null) return 'Buscando ${_title(what)}…';
  return 'Entendendo…';
}

String _title(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
