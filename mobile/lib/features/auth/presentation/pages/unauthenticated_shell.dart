import 'package:flutter/material.dart';

import '../widgets/login_sheet.dart';
import 'welcome_page.dart';

/// Unauthenticated entry: welcome first; login opens in a modal sheet.
class UnauthenticatedShell extends StatelessWidget {
  const UnauthenticatedShell({super.key});

  @override
  Widget build(BuildContext context) {
    return WelcomePage(
      onOrderNow: () => showLoginSheet(context),
    );
  }
}
