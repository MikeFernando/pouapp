import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onOpenCustomers});

  final VoidCallback? onOpenCustomers;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final user = switch (state) {
      Authenticated(:final user) => user,
      AuthLogoutInProgress(:final user) => user,
      _ => null,
    };
    if (user == null) return const SizedBox.shrink();

    final isLoggingOut = state is AuthLogoutInProgress;
    final errorMessage = state is Authenticated ? state.errorMessage : null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(backgroundColor: pouAppBlue, foregroundColor: pouCanvas, title: const Text('PouApp')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bem-vindo', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Text(user.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(user.email, style: theme.textTheme.bodyLarge),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          errorMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    FilledButton.tonal(
                      key: const Key('open_customers_button'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: isLoggingOut ? null : onOpenCustomers,
                      child: const Text('Clientes'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('logout_button'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: isLoggingOut
                          ? null
                          : () => context.read<AuthBloc>().add(
                              const AuthLogoutRequested(),
                            ),
                      child: isLoggingOut
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: 'Saindo',
                              ),
                            )
                          : const Text('Sair'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
