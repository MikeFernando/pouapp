import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';

enum ProfileMenuAction { changePhoto, settings, logout }

Future<ProfileMenuAction?> showProfileMenuSheet(BuildContext context) {
  return showModalBottomSheet<ProfileMenuAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _ProfileMenuSheet(),
  );
}

class _ProfileMenuSheet extends StatelessWidget {
  const _ProfileMenuSheet();

  static const _muted = Color(0xFF6B7280);
  static const _divider = Color(0xFFE9E8EB);
  static const _danger = Color(0xFFB42318);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Conta',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: pouInk,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ProfileMenuTile(
              key: const Key('profile_menu_change_photo'),
              icon: Icons.photo_camera_outlined,
              label: 'Alterar foto do perfil',
              onTap: () => Navigator.of(context).pop(ProfileMenuAction.changePhoto),
            ),
            const Divider(height: 1, color: _divider),
            _ProfileMenuTile(
              key: const Key('profile_menu_settings'),
              icon: Icons.settings_outlined,
              label: 'Configurações',
              onTap: () => Navigator.of(context).pop(ProfileMenuAction.settings),
            ),
            const Divider(height: 1, color: _divider),
            _ProfileMenuTile(
              key: const Key('profile_menu_logout'),
              icon: Icons.logout_rounded,
              label: 'Sair da conta',
              foreground: _danger,
              onTap: () => Navigator.of(context).pop(ProfileMenuAction.logout),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('profile_menu_cancel'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.foreground = pouInk,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: foreground),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: foreground.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
