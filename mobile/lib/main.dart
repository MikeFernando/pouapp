import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/authenticated_shell.dart';
import 'app/pou_app_colors.dart';
import 'core/config/api_config.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/customers/domain/repositories/customer_repository.dart';
import 'features/license/presentation/bloc/license_bloc.dart';
import 'features/license/presentation/bloc/license_event.dart';
import 'features/license/presentation/widgets/license_gate.dart';
import 'features/workspace/data/sync_worker.dart';
import 'injection_container.dart' as di;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    debugPrint(
      'PouApp API → ${ApiConfig.useRemoteApi ? ApiConfig.baseUrl : 'simulated'}',
    );
  }
  await di.init();
  di.sl<SyncWorker>().start();
  runApp(const PouApp());
}

class PouApp extends StatelessWidget {
  const PouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PouApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: pouBrand,
        ).copyWith(
          primary: pouBrand,
          onPrimary: pouCanvas,
          secondary: pouAccent,
          onSecondary: pouInk,
          surface: pouCanvas,
          onSurface: pouInk,
        ),
        scaffoldBackgroundColor: pouCanvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: pouBrand,
          foregroundColor: pouCanvas,
          surfaceTintColor: Colors.transparent,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: pouBrand,
            foregroundColor: Colors.white,
            disabledBackgroundColor: pouBrand.withValues(alpha: 0.38),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.38),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: pouBrand,
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: pouBrand,
          indicatorColor: Colors.white24,
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(color: Colors.white),
          ),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: Colors.white),
          ),
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: pouSurface,
          border: OutlineInputBorder(),
        ),
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                di.sl<AuthBloc>()..add(const AuthSessionRequested()),
          ),
          BlocProvider(create: (_) => di.sl<LicenseBloc>()),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is Unauthenticated && previous is! Unauthenticated,
          listener: (context, state) {
            context.read<LicenseBloc>().add(const LicenseCacheCleared());
            // Drop another account's customers from the on-device cache.
            di.sl<CustomerRepository>().clearLocalCache();
          },
          child: const AuthGate(
            authenticatedPage: LicenseGate(child: AuthenticatedShell()),
          ),
        ),
      ),
    );
  }
}
