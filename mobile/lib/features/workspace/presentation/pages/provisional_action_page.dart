import 'package:flutter/material.dart';

class ProvisionalActionPage extends StatelessWidget {
  const ProvisionalActionPage({
    super.key,
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.construction_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(detail, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            Material(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nada foi salvo.', key: Key('provisional_notice')),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta tela só indica o destino da ação. A gravação entra numa próxima versão.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
