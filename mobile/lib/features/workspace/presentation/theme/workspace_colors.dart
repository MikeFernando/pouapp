import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';

import '../../domain/entities/workspace_mode.dart';

/// Colors of one operational mode. Widgets read this extension instead of
/// picking their own accent.
class WorkspaceColors extends ThemeExtension<WorkspaceColors> {
  const WorkspaceColors({
    required this.header,
    required this.onHeader,
    required this.accent,
    required this.accentSoft,
    required this.highlight,
    required this.navBackground,
    required this.onNav,
  });

  final Color header;
  final Color onHeader;
  final Color accent;
  final Color accentSoft;
  final Color highlight;
  final Color navBackground;
  final Color onNav;

  static const rua = WorkspaceColors(
    header: pouAppBlue,
    onHeader: Colors.white,
    accent: pouAppBlue,
    accentSoft: Color(0xFFE3F2FD),
    highlight: pouAppBlue,
    navBackground: Colors.white,
    onNav: pouAppBlue,
  );

  static const gestao = WorkspaceColors(
    header: Color(0xFF1B3A2F),
    onHeader: Colors.white,
    accent: Color(0xFF2E7D32),
    accentSoft: Color(0xFFE8F5E9),
    highlight: Color(0xFF43A047),
    navBackground: Color(0xFF1B3A2F),
    onNav: Colors.white,
  );

  @override
  WorkspaceColors copyWith({
    Color? header,
    Color? onHeader,
    Color? accent,
    Color? accentSoft,
    Color? highlight,
    Color? navBackground,
    Color? onNav,
  }) {
    return WorkspaceColors(
      header: header ?? this.header,
      onHeader: onHeader ?? this.onHeader,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      highlight: highlight ?? this.highlight,
      navBackground: navBackground ?? this.navBackground,
      onNav: onNav ?? this.onNav,
    );
  }

  @override
  WorkspaceColors lerp(ThemeExtension<WorkspaceColors>? other, double t) {
    if (other is! WorkspaceColors) return this;
    return WorkspaceColors(
      header: Color.lerp(header, other.header, t) ?? header,
      onHeader: Color.lerp(onHeader, other.onHeader, t) ?? onHeader,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
      navBackground:
          Color.lerp(navBackground, other.navBackground, t) ?? navBackground,
      onNav: Color.lerp(onNav, other.onNav, t) ?? onNav,
    );
  }
}

WorkspaceColors workspaceColorsOf(BuildContext context) {
  return Theme.of(context).extension<WorkspaceColors>() ?? WorkspaceColors.rua;
}

const workspaceFontPrimary = 16.0;
const workspaceFontSecondary = 14.0;

TextStyle _sized(TextStyle? style, double fontSize) {
  return (style ?? const TextStyle()).copyWith(
    fontSize: fontSize,
    height: 1.25,
  );
}

ThemeData workspaceTheme(ThemeData base, WorkspaceMode mode) {
  final colors = mode == WorkspaceMode.gestao
      ? WorkspaceColors.gestao
      : WorkspaceColors.rua;
  final text = base.textTheme;
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(primary: colors.accent),
    extensions: [colors],
    textTheme: text.copyWith(
      bodyLarge: _sized(text.bodyLarge, workspaceFontPrimary),
      titleMedium: _sized(text.titleMedium, workspaceFontPrimary),
      titleLarge: _sized(text.titleLarge, workspaceFontPrimary),
      bodyMedium: _sized(text.bodyMedium, workspaceFontSecondary),
      bodySmall: _sized(text.bodySmall, workspaceFontSecondary),
      titleSmall: _sized(text.titleSmall, workspaceFontSecondary),
      labelLarge: _sized(text.labelLarge, workspaceFontSecondary),
      labelMedium: _sized(text.labelMedium, workspaceFontSecondary),
      labelSmall: _sized(text.labelSmall, workspaceFontSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(
          fontSize: workspaceFontPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontSize: workspaceFontSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
