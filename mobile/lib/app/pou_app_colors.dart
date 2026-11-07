import 'package:flutter/material.dart';

/// Blue used by the operational interface and primary actions.
const pouAppBlue = Color(0xFF1E88E5);

ButtonStyle pouAppPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: pouAppBlue,
    foregroundColor: Colors.white,
    disabledBackgroundColor: pouAppBlue.withValues(alpha: 0.38),
    disabledForegroundColor: Colors.white,
  );
}
