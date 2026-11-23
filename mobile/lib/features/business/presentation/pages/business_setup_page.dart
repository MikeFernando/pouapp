import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/business_setup.dart';
import '../bloc/business_setup_bloc.dart';
import '../bloc/business_setup_event.dart';
import '../bloc/business_setup_state.dart';

class BusinessSetupPage extends StatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  State<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends State<BusinessSetupPage> {
  BusinessKind? _selected;

  void _continue() {
    final bloc = context.read<BusinessSetupBloc>();
    final state = bloc.state;
    final selected =
        _selected ?? (state is BusinessSetupSaveFailed ? state.kind : null);
    if (selected == null || state is BusinessSetupSaving) return;
    final userId = _signedInUserId(context);
    if (userId == null) return;
    bloc.add(BusinessSetupSaveRequested(userId: userId, kind: selected));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BusinessSetupBloc>().state;
    final saving = state is BusinessSetupSaving;
    final error = state is BusinessSetupSaveFailed ? state.message : null;
    final selected =
        _selected ?? (state is BusinessSetupSaveFailed ? state.kind : null);

    return Scaffold(
      key: const Key('business_setup_screen'),
      backgroundColor: pouCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Qual é o tipo do seu negócio?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: pouInk,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vamos sugerir categorias e personalizar o visual da sua loja.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: const Color(0xFF6B7280), height: 1.35),
              ),
              const SizedBox(height: 20),
              IgnorePointer(
                ignoring: saving,
                child: Column(
                  children: [
                    for (final kind in businessKindOptions) ...[
                      _KindCard(
                        kind: kind,
                        selected: selected == kind,
                        onTap: () => setState(() => _selected = kind),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 4),
                Text(
                  error,
                  key: const Key('business_setup_error'),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: const Color(0xFFC62828)),
                ),
              ],
              const SizedBox(height: 12),
              PouGradientButton(
                key: const Key('business_setup_continue'),
                onPressed: selected == null || saving ? null : _continue,
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                          semanticsLabel: 'Salvando tipo do negócio',
                        ),
                      )
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final BusinessKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? pouBrand : const Color(0xFFE5E7EB);
    return Material(
      color: selected ? const Color(0xFFE7F3EC) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('business_kind_${kind.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: selected ? 1.6 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(_iconFor(kind), color: pouBrand),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    businessKindLabel(kind),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: pouInk, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  key: Key(
                    selected
                        ? 'business_kind_selected_${kind.name}'
                        : 'business_kind_idle_${kind.name}',
                  ),
                  color: selected ? pouBrand : const Color(0xFFD1D5DB),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(BusinessKind kind) {
  return switch (kind) {
    BusinessKind.hortifruti => Icons.eco_outlined,
    BusinessKind.meals => Icons.lunch_dining_outlined,
    BusinessKind.pizzas => Icons.local_pizza_outlined,
    BusinessKind.snacks => Icons.fastfood_outlined,
    BusinessKind.cakes => Icons.cake_outlined,
    BusinessKind.grocery => Icons.shopping_basket_outlined,
    BusinessKind.cleaning => Icons.cleaning_services_outlined,
    BusinessKind.apparel => Icons.checkroom_outlined,
    BusinessKind.mixed => Icons.storefront_outlined,
    BusinessKind.other => Icons.apps_outlined,
  };
}

String? _signedInUserId(BuildContext context) {
  final state = context.read<AuthBloc>().state;
  return switch (state) {
    Authenticated(:final user) => user.id,
    AuthLogoutInProgress(:final user) => user.id,
    _ => null,
  };
}
