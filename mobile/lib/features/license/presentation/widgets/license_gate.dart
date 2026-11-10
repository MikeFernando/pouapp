import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/widgets/session_loading_view.dart';
import '../../domain/entities/license_status.dart';
import '../bloc/license_bloc.dart';
import '../bloc/license_event.dart';
import '../bloc/license_state.dart';
import '../pages/license_blocked_page.dart';
import '../pages/license_no_subscription_page.dart';

/// Runs after auth. Blocks the authenticated shell when the tenant is unpaid.
class LicenseGate extends StatefulWidget {
  const LicenseGate({super.key, required this.child});

  final Widget child;

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    context.read<LicenseBloc>().add(const LicenseCheckRequested());
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!mounted) return;
        context.read<LicenseBloc>().add(
          const LicenseCheckRequested(forceRemote: true),
        );
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LicenseBloc, LicenseState>(
      builder: (context, state) {
        return switch (state) {
          LicenseInitial() || LicenseChecking() => const SessionLoadingView(),
          LicenseActive() => widget.child,
          LicenseBlocked(:final status) =>
              status.reason == LicenseBlockReason.wrongEmail
              ? LicenseNoSubscriptionPage(paidEmail: status.paidEmail)
              : LicenseBlockedPage(
                  message: status.message,
                  reason: status.reason,
                  paidEmail: status.paidEmail,
                ),
          LicenseCheckFailed(:final message) => LicenseBlockedPage(
            message: message,
            showRetryAsPrimary: true,
            reason: LicenseBlockReason.paymentRequired,
          ),
          _ => const SessionLoadingView(),
        };
      },
    );
  }
}
