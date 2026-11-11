import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/entities/user.dart';
import '../../domain/usecases/update_user_name.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../validation/login_validators.dart';

Future<bool?> showEditUserNameSheet(
  BuildContext context, {
  required User user,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => BlocProvider.value(
      value: context.read<AuthBloc>(),
      child: EditUserNameSheet(user: user),
    ),
  );
}

class EditUserNameSheet extends StatefulWidget {
  const EditUserNameSheet({super.key, required this.user});

  final User user;

  @override
  State<EditUserNameSheet> createState() => _EditUserNameSheetState();
}

class _EditUserNameSheetState extends State<EditUserNameSheet> {
  late final TextEditingController _name;
  var _saving = false;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final error = validateName(_name.text);
    if (error != null) {
      setState(() => _fieldError = error);
      return;
    }
    final next = _name.text.trim();
    if (next == widget.user.name.trim()) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _fieldError = null;
      _saving = true;
    });

    final result = await di.sl<UpdateUserName>()(
      UpdateUserNameParams(name: next),
    );
    if (!mounted) return;

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      setState(() => _saving = false);
      final message = switch (failure) {
        NetworkFailure() =>
          'Sem conexão. Verifique a internet e tente de novo.',
        _ => 'Não foi possível salvar o nome. Tente novamente.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    // Refresh the in-memory session from the updated local/remote cache.
    context.read<AuthBloc>().add(const AuthSessionRequested());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E7EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Editar nome',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: pouInk,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('edit_user_name'),
                controller: _name,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                enabled: !_saving,
                autofocus: true,
                onSubmitted: (_) => _saving ? null : _submit(),
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  filled: true,
                  fillColor: Color(0xFFF6F5F7),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_fieldError != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _fieldError!,
                    key: const Key('edit_user_name_error'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: FilledButton(
                  key: const Key('edit_user_name_save'),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                            semanticsLabel: 'Salvando nome',
                          ),
                        )
                      : const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
