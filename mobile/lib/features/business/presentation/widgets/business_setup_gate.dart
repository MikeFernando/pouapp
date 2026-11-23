import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/business_look.dart';
import '../../../../app/business_theme_scope.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../injection_container.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/widgets/session_loading_view.dart';
import '../../domain/entities/business_setup.dart';
import '../bloc/business_setup_bloc.dart';
import '../bloc/business_setup_event.dart';
import '../bloc/business_setup_state.dart';
import '../pages/business_setup_page.dart';

/// Chooses setup or the signed-in app after the session is known.
///
/// The home shell is not mounted until the business profile is configured,
/// including when the app is reopened or an internal route would be first.
class BusinessSetupGate extends StatefulWidget {
  const BusinessSetupGate({super.key, required this.child});

  final Widget child;

  @override
  State<BusinessSetupGate> createState() => _BusinessSetupGateState();
}

class _BusinessSetupGateState extends State<BusinessSetupGate> {
  @override
  void initState() {
    super.initState();
    final userId = _userIdOf(context.read<AuthBloc>().state);
    if (userId != null) {
      context.read<BusinessSetupBloc>().add(BusinessSetupLoadRequested(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          _userIdOf(previous) != _userIdOf(current),
      listener: (context, state) {
        final userId = _userIdOf(state);
        final bloc = context.read<BusinessSetupBloc>();
        if (userId == null) {
          bloc.add(const BusinessSetupReset());
        } else {
          bloc.add(BusinessSetupLoadRequested(userId));
        }
      },
      child: BlocBuilder<BusinessSetupBloc, BusinessSetupState>(
        builder: (context, state) {
          final currentUserId = _userIdOf(context.watch<AuthBloc>().state);
          if (currentUserId == null) return const SessionLoadingView();

          return switch (state) {
            BusinessSetupReady(:final setup)
                when setup.userId == currentUserId =>
              _BusinessCatalogGate(
                kind: setup.kind ?? BusinessKind.hortifruti,
                child: BusinessThemeScope(
                  userId: setup.userId,
                  fallback: _chromeFor(setup.kind),
                  suggestions: [
                    for (final category in setup.categories)
                      PouCategorySuggestion(
                        id: category.id,
                        label: category.label,
                      ),
                  ],
                  child: widget.child,
                ),
              ),
            BusinessSetupPending(:final userId) when userId == currentUserId =>
              const BusinessSetupPage(),
            BusinessSetupSaving(:final userId) when userId == currentUserId =>
              const BusinessSetupPage(),
            BusinessSetupSaveFailed(:final userId)
                when userId == currentUserId =>
              const BusinessSetupPage(),
            BusinessSetupUnavailable(:final userId, :final message)
                when userId == currentUserId =>
              _SetupUnavailable(message: message, userId: userId),
            _ => const SessionLoadingView(),
          };
        },
      ),
    );
  }
}

PouChrome _chromeFor(BusinessKind? kind) {
  return switch (kind) {
    BusinessKind.cleaning => PouChrome.cleaning,
    BusinessKind.meals => PouChrome.meals,
    BusinessKind.pizzas => PouChrome.pizzas,
    BusinessKind.snacks => PouChrome.snacks,
    BusinessKind.cakes => PouChrome.cakes,
    BusinessKind.hortifruti || null => PouChrome.botanical,
    _ => PouChrome.plain,
  };
}

class _BusinessCatalogGate extends StatefulWidget {
  const _BusinessCatalogGate({required this.kind, required this.child});

  final BusinessKind kind;
  final Widget child;

  @override
  State<_BusinessCatalogGate> createState() => _BusinessCatalogGateState();
}

class _BusinessCatalogGateState extends State<_BusinessCatalogGate> {
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(covariant _BusinessCatalogGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      setState(() => _ready = false);
      _apply();
    }
  }

  Future<void> _apply() async {
    if (sl.isRegistered<CatalogRepository>()) {
      final catalog = sl<CatalogRepository>();
      if (widget.kind == BusinessKind.cleaning) {
        await catalog.useCleaningCatalog();
      } else if (widget.kind == BusinessKind.meals) {
        await catalog.useMealsCatalog();
      } else if (widget.kind == BusinessKind.pizzas) {
        await catalog.usePizzasCatalog();
      } else if (widget.kind == BusinessKind.snacks) {
        await catalog.useSnacksCatalog();
      } else if (widget.kind == BusinessKind.cakes) {
        await catalog.useCakesCatalog();
      }
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SessionLoadingView();
    return widget.child;
  }
}

class _SetupUnavailable extends StatelessWidget {
  const _SetupUnavailable({required this.message, required this.userId});

  final String message;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pouCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              PouGradientButton(
                key: const Key('business_setup_retry'),
                onPressed: () {
                  context.read<BusinessSetupBloc>().add(
                    BusinessSetupLoadRequested(userId),
                  );
                },
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _userIdOf(AuthState state) {
  return switch (state) {
    Authenticated(:final user) => user.id,
    AuthLogoutInProgress(:final user) => user.id,
    _ => null,
  };
}
