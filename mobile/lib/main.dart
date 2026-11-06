import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/authenticated_shell.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4F72)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
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
