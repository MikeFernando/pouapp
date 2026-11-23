import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/business_look.dart';
import '../../../../app/business_theme_scope.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/data/datasources/profile_avatar_store.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../pages/business_settings_page.dart';
import 'pou_drawer_3d.dart';
import 'profile_menu_sheet.dart';

/// Compact theme capsule: letter, chevron, and the profile photo.
class ThemeSelector extends StatefulWidget {
  const ThemeSelector({super.key, required this.userId});

  final String userId;

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<ThemeSelector> {
  String? _path;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant ThemeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _path = null;
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    if (!di.sl.isRegistered<ProfileAvatarStore>()) return;
    final path = await di.sl<ProfileAvatarStore>().pathForUser(widget.userId);
    if (!mounted) return;
    setState(() => _path = path);
  }

  Future<void> _openMenu() async {
    final drawer = PouDrawer3D.maybeOf(context);
    if (drawer != null) {
      drawer.open();
      return;
    }
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        origin.dx,
        origin.dy + box.size.height + 6,
        box.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
    final chrome = BusinessLook.chromeOf(context);
    final selected = await showMenu<Object>(
      context: context,
      position: position,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: const Color(0x33000000),
      elevation: 12,
      constraints: const BoxConstraints(minWidth: 248, maxWidth: 280),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      items: [
        const PopupMenuItem<Object>(
          enabled: false,
          height: 36,
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            'Alternar negócio',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        for (final theme in pouSelectableThemes)
          PopupMenuItem<Object>(
            key: Key('theme_option_${theme.name}'),
            value: theme,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _ThemeOption(theme: theme, selected: theme == chrome),
          ),
        const PopupMenuDivider(height: 12),
        const PopupMenuItem<Object>(
          key: Key('theme_menu_profile'),
          value: #profile,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 22, color: pouInk),
              SizedBox(width: 12),
              Text(
                'Meu perfil',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: pouInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (!mounted || selected == null) return;
    if (selected == #profile) {
      await _openProfile();
      return;
    }
    if (selected is PouChrome) {
      await BusinessThemeScope.of(context).select(selected);
    }
  }

  Future<void> _openProfile() async {
    if (_loading) return;
    final action = await showProfileMenuSheet(context);
    if (!mounted || action == null) return;
    switch (action) {
      case ProfileMenuAction.changePhoto:
        await _pick();
      case ProfileMenuAction.settings:
        await showBusinessSettingsSheet(context);
      case ProfileMenuAction.logout:
        context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }

  Future<void> _pick() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (picked == null) return;
      if (!di.sl.isRegistered<ProfileAvatarStore>()) return;
      final saved = await di.sl<ProfileAvatarStore>().saveFromGallery(
        userId: widget.userId,
        sourcePath: picked.path,
      );
      if (!mounted) return;
      setState(() => _path = saved);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar a foto.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chrome = BusinessLook.chromeOf(context);
    final label = pouThemeLabel(chrome);
    final chip = pouThemeChip(chrome);
    final drawer = PouDrawer3D.maybeOf(context);
    final path = drawer != null ? drawer.avatarPath : _path;
    final image = path == null
        ? const AssetImage('assets/header_avatar.jpg')
        : FileImage(File(path)) as ImageProvider;

    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: chip.background,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('theme_selector'),
            onTap: _loading ? null : _openMenu,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 3, 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pouThemeLetter(chrome),
                    style: TextStyle(
                      color: chip.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: chip.foreground,
                  ),
                  const SizedBox(width: 6),
                  _Avatar(image: image, loading: _loading),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.image, required this.loading});

  final ImageProvider image;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        key: const Key('profile_avatar'),
        width: 32,
        height: 32,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(image: image, fit: BoxFit.cover),
            if (loading)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.theme, required this.selected});

  final PouChrome theme;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final chip = pouThemeChip(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? chip.background : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                chip.foreground.withValues(alpha: 0.16),
                Colors.white,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_themeIcon(theme), size: 18, color: chip.foreground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pouThemeLabel(theme),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: pouInk,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_rounded, size: 18, color: pouInk),
        ],
      ),
    );
  }
}

IconData _themeIcon(PouChrome theme) {
  return switch (theme) {
    PouChrome.botanical => Icons.eco_rounded,
    PouChrome.cleaning => Icons.water_drop_outlined,
    PouChrome.meals => Icons.soup_kitchen_outlined,
    PouChrome.pizzas => Icons.local_pizza_outlined,
    PouChrome.snacks => Icons.fastfood_outlined,
    PouChrome.cakes => Icons.cake_outlined,
    PouChrome.plain => Icons.storefront_outlined,
  };
}
