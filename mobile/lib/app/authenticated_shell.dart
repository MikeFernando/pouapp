import 'package:flutter/material.dart';

import '../features/assistant/presentation/widgets/voice_mic.dart';
import '../features/customers/presentation/customer_routes.dart';
import '../features/customers/presentation/pages/customer_details_page.dart';
import '../features/customers/presentation/pages/customer_form_page.dart';
import '../features/customers/presentation/pages/customers_page.dart';
import '../features/workspace/presentation/pages/workspace_page.dart';

/// Nested navigator of the authenticated area.
///
/// Logging out removes this navigator together with the auth gate, so the
/// system back button cannot reopen a customer screen.
class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({super.key});

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _pageName = ValueNotifier<String?>(null);
  late final _ShellObserver _observer = _ShellObserver(_syncPop);
  late final VoiceMicObserver _mic = VoiceMicObserver(_pageName);
  var _nestedCanPop = false;

  void _syncPop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final canPop = _navigatorKey.currentState?.canPop() ?? false;
      if (canPop != _nestedCanPop) {
        setState(() => _nestedCanPop = canPop);
      }
    });
  }

  @override
  void dispose() {
    _mic.dispose();
    _pageName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_nestedCanPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigatorKey.currentState?.pop();
      },
      child: Navigator(
        key: _navigatorKey,
        observers: [_observer, _mic],
        initialRoute: CustomerRoutes.home,
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? CustomerRoutes.home;
    if (name == CustomerRoutes.customers) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const CustomersPage(),
      );
    }
    if (name == CustomerRoutes.create) {
      return MaterialPageRoute<bool>(
        settings: settings,
        builder: (_) => const CustomerFormPage(),
      );
    }
    final edit = RegExp(r'^/customers/([^/]+)/edit$').firstMatch(name);
    if (edit != null) {
      return MaterialPageRoute<bool>(
        settings: settings,
        builder: (_) =>
            CustomerFormPage(customerId: Uri.decodeComponent(edit.group(1)!)),
      );
    }
    final details = RegExp(r'^/customers/([^/]+)$').firstMatch(name);
    if (details != null) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => CustomerDetailsPage(
          customerId: Uri.decodeComponent(details.group(1)!),
        ),
      );
    }
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => WorkspacePage(
        onOpenCustomers: () {
          Navigator.of(context).pushNamed(CustomerRoutes.customers);
        },
      ),
    );
  }
}

class _ShellObserver extends NavigatorObserver {
  _ShellObserver(this.onChanged);

  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    onChanged();
  }
}
