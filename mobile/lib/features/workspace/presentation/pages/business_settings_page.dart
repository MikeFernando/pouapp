import 'package:flutter/material.dart';

import '../../../../injection_container.dart';
import '../../data/receivable_store.dart';
import '../../domain/entities/receivable.dart';
import '../../domain/rules/receivable_rules.dart';

class BusinessSettingsPage extends StatefulWidget {
  const BusinessSettingsPage({super.key});

  @override
  State<BusinessSettingsPage> createState() => _BusinessSettingsPageState();
}

class _BusinessSettingsPageState extends State<BusinessSettingsPage> {
  final _key = TextEditingController();
  final _name = TextEditingController();
  PixKeyType _type = PixKeyType.phone;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await sl<ReceivableStore>().readProfile();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _type = profile.pixKeyType ?? PixKeyType.phone;
      _key.text = profile.pixKey ?? '';
      _name.text = profile.receiverName ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4F72),
        foregroundColor: Colors.white,
        title: const Text('Chave Pix'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'A cobrança envia esta chave. Ela não gera QR Code nem código Pix Copia e Cola.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PixKeyType>(
                  key: const Key('pix_key_type'),
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de chave',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    for (final type in PixKeyType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(pixKeyTypeLabel(type)),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _type = value);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('pix_key_value'),
                  controller: _key,
                  decoration: const InputDecoration(
                    labelText: 'Chave Pix',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('pix_receiver_name'),
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nome do recebedor',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      key: const Key('pix_settings_error'),
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('pix_settings_save'),
                  onPressed: _saving ? null : _save,
                  child: const Text('Salvar chave'),
                ),
              ],
            ),
    );
  }

  Future<void> _save() async {
    final profile = BusinessProfile(
      pixKeyType: _type,
      pixKey: _key.text,
      receiverName: _name.text,
    );
    final problem = pixProfileProblem(profile);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await sl<ReceivableStore>().saveProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReceivableException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }
}
