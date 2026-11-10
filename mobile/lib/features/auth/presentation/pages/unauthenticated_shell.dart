import 'package:flutter/material.dart';

import 'login_page.dart';
import 'welcome_page.dart';

/// Unauthenticated entry: welcome first, then the existing login flow.
class UnauthenticatedShell extends StatefulWidget {
  const UnauthenticatedShell({super.key});

  @override
  State<UnauthenticatedShell> createState() => _UnauthenticatedShellState();
}

class _UnauthenticatedShellState extends State<UnauthenticatedShell> {
  var _showLogin = false;

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return const LoginPage();
    }
    return WelcomePage(
      onOrderNow: () => setState(() => _showLogin = true),
    );
  }
}
