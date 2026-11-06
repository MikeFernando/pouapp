import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import '../widgets/session_loading_view.dart';
import 'home_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.authenticatedPage});

  /// Replaces the temporary home when the signed-in area has its own navigator.
  final Widget? authenticatedPage;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthInitial() || AuthChecking() => const SessionLoadingView(),
          Authenticated() ||
          AuthLogoutInProgress() => authenticatedPage ?? const HomePage(),
          _ => const LoginPage(),
        };
      },
    );
  }
}
