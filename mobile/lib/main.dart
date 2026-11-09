import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/authenticated_shell.dart';
import 'app/pou_app_colors.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/workspace/data/sync_worker.dart';
import 'injection_container.dart' as di;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          seedColor: pouAccent,
        ).copyWith(
          primary: pouInk,
          onPrimary: pouCanvas,
          secondary: pouAccent,
          onSecondary: pouInk,
          surface: pouCanvas,
          onSurface: pouInk,
        ),
        scaffoldBackgroundColor: pouCanvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: pouInk,
          foregroundColor: pouCanvas,
          surfaceTintColor: Colors.transparent,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: pouInk,
            foregroundColor: Colors.white,
            disabledBackgroundColor: pouInk.withValues(alpha: 0.38),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.38),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: pouInk,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: pouSurface,
          border: OutlineInputBorder(),
        ),
      ),
      home: BlocProvider(
        create: (_) => di.sl<AuthBloc>()..add(const AuthSessionRequested()),
        child: const AuthGate(authenticatedPage: AuthenticatedShell()),
      ),
    );
  }
}
