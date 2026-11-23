import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/business_look.dart';
import '../../../../app/business_theme_scope.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/data/datasources/profile_avatar_store.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../pages/business_settings_page.dart';

/// Same motion as Nileon's drawer: the screen slides aside, shrinks and
/// turns on Y while the menu sits behind it.
class PouDrawer3D extends StatefulWidget {
  const PouDrawer3D({super.key, required this.user, required this.child});

  final User user;
  final Widget child;

  static PouDrawer3DState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<PouDrawer3DState>();
  }

  @override
  State<PouDrawer3D> createState() => PouDrawer3DState();
}

class PouDrawer3DState extends State<PouDrawer3D>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 340);
  static const _curve = Curves.easeInOutCubic;
  static const _widthFraction = 2 / 3;
  static const _slideFraction = 0.14;
  static const _translateFactor = 1.02;
  static const _translateMin = 200.0;
  static const _translateMax = 340.0;
  static const _openScale = 0.72;
  static const _openRotateY = 0.25;
  static const _perspective = 0.001;
  static const _openRadius = 32.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );

  String? avatarPath;
  var _picking = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(covariant PouDrawer3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      avatarPath = null;
      _loadAvatar();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void open() {
    HapticFeedback.lightImpact();
    _controller.animateTo(1, duration: _duration, curve: _curve);
  }

  void close() {
    HapticFeedback.lightImpact();
    _controller.animateTo(0, duration: _duration, curve: _curve);
  }

  Future<void> _loadAvatar() async {
    if (!di.sl.isRegistered<ProfileAvatarStore>()) return;
    final path = await di.sl<ProfileAvatarStore>().pathForUser(widget.user.id);
    if (!mounted) return;
    setState(() => avatarPath = path);
  }

  Future<void> changePhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
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
        userId: widget.user.id,
        sourcePath: picked.path,
      );
      if (!mounted) return;
      setState(() => avatarPath = saved);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar a foto.')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _dragBy(double dx) {
    final width = MediaQuery.sizeOf(context).width * _widthFraction;
    _controller.value = (_controller.value + dx / (width * 0.85)).clamp(
      0.0,
      1.0,
    );
  }

  void _snap() {
    final target = _controller.value > 0.45 ? 1.0 : 0.0;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Matrix4 _matrix(double t, double screenWidth) {
    if (t <= 0) return Matrix4.identity();
    final menuWidth = screenWidth * _widthFraction;
    final target = (menuWidth * _translateFactor).clamp(
      _translateMin,
      _translateMax,
    );
    final tx = lerpDouble(0, target, t)!;
    final scale = lerpDouble(1, _openScale, t)!;
    final rotate = lerpDouble(0, _openRotateY, t)!;
    return Matrix4.identity()
      ..setEntry(3, 2, _perspective)
      ..translateByDouble(tx, 0, 0, 1)
      ..rotateY(rotate)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value.clamp(0.0, 1.0);
        final width = MediaQuery.sizeOf(context).width;
        final menuWidth = width * _widthFraction;
        final radius = lerpDouble(0, _openRadius, t)!;
        final open = t > 0.04;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: menuWidth,
              child: ClipRect(
                child: IgnorePointer(
                  ignoring: !open,
                  child: Transform.translate(
                    offset: Offset(-menuWidth * _slideFraction * (1 - t), 0),
                    child: Opacity(
                      opacity: Curves.easeOutCubic.transform(t),
                      child: t == 0
                          ? const SizedBox.shrink()
                          : _SideMenu(
                              user: widget.user,
                              avatarPath: avatarPath,
                              picking: _picking,
                              onClose: close,
                              onChangePhoto: () {
                                close();
                                changePhoto();
                              },
                              onSettings: () {
                                close();
                                showBusinessSettingsSheet(context);
                              },
                              onLogout: () {
                                close();
                                context.read<AuthBloc>().add(
                                  const AuthLogoutRequested(),
                                );
                              },
                              onTheme: (theme) {
                                close();
                                BusinessThemeScope.of(context).select(theme);
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform(
                key: const Key('pou_drawer_front'),
                alignment: Alignment.centerLeft,
                filterQuality: FilterQuality.medium,
                transform: _matrix(t, width),
                child: GestureDetector(
                  behavior: open
                      ? HitTestBehavior.opaque
                      : HitTestBehavior.deferToChild,
                  onTap: open ? close : null,
                  onHorizontalDragUpdate: open
                      ? (details) => _dragBy(details.primaryDelta ?? 0)
                      : null,
                  onHorizontalDragEnd: open ? (_) => _snap() : null,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: t > 0.02
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: IgnorePointer(ignoring: open, child: child),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.user,
    required this.avatarPath,
    required this.picking,
    required this.onClose,
    required this.onChangePhoto,
    required this.onSettings,
    required this.onLogout,
    required this.onTheme,
  });

  final User user;
  final String? avatarPath;
  final bool picking;
  final VoidCallback onClose;
  final VoidCallback onChangePhoto;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final ValueChanged<PouChrome> onTheme;

  @override
  Widget build(BuildContext context) {
    final chrome = BusinessLook.chromeOf(context);
    final image = avatarPath == null
        ? const AssetImage('assets/header_avatar.jpg')
        : FileImage(File(avatarPath!)) as ImageProvider;

    return DefaultTextStyle(
      style: const TextStyle(
        color: pouInk,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.none,
        decorationColor: pouInk,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Image(image: image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.trim().isEmpty ? 'Conta' : user.name.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: pouInk,
                            height: 1.2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF6B7280),
                            height: 1.25,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: pouSurface,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    elevation: 2,
                    shadowColor: Colors.black26,
                    child: InkWell(
                      key: const Key('profile_menu_close'),
                      onTap: onClose,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: pouInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  const _SectionLabel('Alternar negócio', compact: true),
                  for (final theme in pouSelectableThemes)
                    _MenuRow(
                      key: Key('theme_option_${theme.name}'),
                      icon: _themeIcon(theme),
                      label: pouThemeLabel(theme),
                      active: theme == chrome,
                      fill: pouThemeChip(theme).background,
                      onTap: () => onTheme(theme),
                    ),
                  const _SectionLabel('Meu perfil'),
                  _MenuRow(
                    key: const Key('profile_menu_change_photo'),
                    icon: picking
                        ? Icons.hourglass_top_rounded
                        : Icons.photo_camera_outlined,
                    label: 'Alterar foto do perfil',
                    onTap: onChangePhoto,
                  ),
                  _MenuRow(
                    key: const Key('profile_menu_settings'),
                    icon: Icons.settings_outlined,
                    label: 'Configurações',
                    onTap: onSettings,
                  ),
                  _MenuRow(
                    key: const Key('profile_menu_logout'),
                    icon: Icons.logout_rounded,
                    label: 'Sair da conta',
                    destructive: true,
                    onTap: onLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title, {this.compact = false});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 22 : 28, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Color(0xFF6B7280),
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.fill,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? fill;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFB42318) : pouInk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
      child: Material(
        color: active ? (fill ?? pouSurface) : Colors.transparent,
        borderRadius: BorderRadius.circular(active ? 14 : 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(active ? 14 : 12),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (active)
                    const Icon(Icons.check_rounded, size: 18, color: pouInk),
                ],
              ),
            ),
          ),
        ),
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
