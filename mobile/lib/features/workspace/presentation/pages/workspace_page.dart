import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/nav_glyphs.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../app/pou_shell_navigation.dart';
import '../../../../core/config/api_config.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/data/datasources/profile_avatar_store.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/widgets/edit_user_name_sheet.dart';
import '../../../catalog/presentation/pages/products_page.dart';
import '../../../customers/presentation/customer_routes.dart';
import '../../../customers/presentation/pages/customers_page.dart';
import '../../domain/rules/month_board.dart';
import '../bloc/company_operation_bloc.dart';
import '../bloc/home_board_bloc.dart';
import '../loaded_operation.dart';
import '../operation_labels.dart';
import '../theme/workspace_colors.dart';
import '../widgets/street_board_view.dart';
import 'add_delivery_page.dart';
import 'business_settings_page.dart';
import 'finance_page.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final company = loadedCompanyOperation();
    final home = loadedHomeBoard();
    if (home == null) {
      return BlocProvider.value(
        value: company,
        child: const WorkspaceView(),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: company),
        BlocProvider.value(value: home),
      ],
      child: const WorkspaceView(),
    );
  }
}

class WorkspaceView extends StatefulWidget {
  const WorkspaceView({super.key});

  @override
  State<WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends State<WorkspaceView> {
  var _valuesHidden = false;
  final _built = <int>{0};
  var _tab = 0;
  var _adding = false;

  void _openTab(int index) {
    setState(() {
      _tab = index;
      _built.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = switch (auth) {
      Authenticated(:final user) => user,
      AuthLogoutInProgress(:final user) => user,
      _ => null,
    };
    if (user == null) return const SizedBox.shrink();

    final logoutError = auth is Authenticated ? auth.errorMessage : null;

    return Theme(
      data: workspaceTheme(Theme.of(context)),
      child: Builder(
        builder: (context) {
          return RoundedNavigationScaffold(
            key: const Key('workspace_home'),
            selectedIndex: _tab,
            onSelected: _openTab,
            destinations: const [
              RoundedNavigationDestination(
                glyph: NavGlyphKind.home,
                label: 'Home',
              ),
              RoundedNavigationDestination(
                glyph: NavGlyphKind.products,
                label: 'Produtos',
              ),
              RoundedNavigationDestination(
                glyph: NavGlyphKind.customers,
                label: 'Clientes',
              ),
              RoundedNavigationDestination(
                glyph: NavGlyphKind.finance,
                label: 'Financeiro',
              ),
            ],
            content: LayoutBuilder(
              builder: (context, constraints) {
                Widget fill(Widget child) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: child,
                  );
                }

                return IndexedStack(
                  index: _tab,
                  children: [
                    fill(
                      Stack(
                        children: [
                          Column(
                            children: [
                              _WorkspaceHeader(
                                user: user,
                                message: logoutError,
                                receivedTodayCents: _receivedTodayCents(
                                  context,
                                ),
                                valuesHidden: _valuesHidden,
                                onToggleValues: () {
                                  setState(
                                    () => _valuesHidden = !_valuesHidden,
                                  );
                                },
                              ),
                              Expanded(
                                child: StreetBoardView(
                                  valuesHidden: _valuesHidden,
                                  onNewSale: _addDeliveryPerson,
                                  onOpenCustomer: (customerId) async {
                                    await Navigator.of(context).pushNamed(
                                      CustomerRoutes.details(customerId),
                                    );
                                    if (!context.mounted) return;
                                    // Reload hoje/amanhã after editing vencimento.
                                    if (ApiConfig.useRemoteApi) {
                                      context.read<HomeBoardBloc>().add(
                                        const HomeBoardRequested(),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_adding)
                            Positioned.fill(
                              child: _AddCover(
                                onClose: () => setState(() => _adding = false),
                                child: AddDeliveryPage(
                                  onOpenCustomer: (customerId) async {
                                    setState(() => _adding = false);
                                    await Navigator.of(context).pushNamed(
                                      CustomerRoutes.details(customerId),
                                    );
                                    if (!context.mounted) return;
                                    if (ApiConfig.useRemoteApi) {
                                      context.read<HomeBoardBloc>().add(
                                        const HomeBoardRequested(),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    fill(
                      _built.contains(1)
                          ? const ProductsPage()
                          : const SizedBox.shrink(),
                    ),
                    fill(
                      _built.contains(2)
                          ? const CustomersPage()
                          : const SizedBox.shrink(),
                    ),
                    fill(
                      _built.contains(3)
                          ? const FinancePage()
                          : const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _addDeliveryPerson() {
    setState(() => _adding = true);
  }

  int _receivedTodayCents(BuildContext context) {
    if (ApiConfig.useRemoteApi) {
      return context.watch<HomeBoardBloc>().state.board?.receivedTodayCents ?? 0;
    }
    final operation = context.watch<CompanyOperationBloc>().state.operation;
    final now = DateTime.now();
    return monthSnapshot(
      sales: operation?.postedSales ?? const [],
      month: DateTime(now.year, now.month),
      today: now,
    ).receivedCents;
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.user,
    required this.message,
    required this.receivedTodayCents,
    required this.valuesHidden,
    required this.onToggleValues,
  });

  final User user;
  final String? message;
  final int receivedTodayCents;
  final bool valuesHidden;
  final VoidCallback onToggleValues;

  static const _ink = pouInk;
  static const _muted = Color(0xFF9A9AA2);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: pouBrand,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: ClipRRect(
        key: const Key('workspace_header'),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: ColoredBox(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    _HeaderAvatar(userId: user.id),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        key: const Key('workspace_edit_user_name'),
                        onTap: () => showEditUserNameSheet(
                          context,
                          user: user,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _HeaderRoundIcon(
                      icon: Icons.settings_outlined,
                      onTap: () => showBusinessSettingsSheet(context),
                    ),
                    const SizedBox(width: 10),
                    const _HeaderRoundIcon(icon: Icons.notifications_none),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Recebido hoje',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatBrl(
                            receivedTodayCents,
                            hidden: valuesHidden,
                          ),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const Key('workspace_hide_values'),
                      tooltip: valuesHidden ? 'Mostrar valores' : 'Esconder valores',
                      onPressed: onToggleValues,
                      icon: Icon(
                        valuesHidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _ink,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(message!, style: const TextStyle(color: _ink)),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _HeaderRoundIcon extends StatelessWidget {
  const _HeaderRoundIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: pouInk.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: pouInk, size: 22),
          ),
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatefulWidget {
  const _HeaderAvatar({required this.userId});

  final String userId;

  @override
  State<_HeaderAvatar> createState() => _HeaderAvatarState();
}

class _HeaderAvatarState extends State<_HeaderAvatar> {
  String? _path;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _HeaderAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _path = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = await di.sl<ProfileAvatarStore>().pathForUser(widget.userId);
    if (!mounted) return;
    setState(() => _path = path);
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
    final image = _path == null
        ? const AssetImage('assets/header_avatar.jpg')
        : FileImage(File(_path!)) as ImageProvider;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('profile_avatar'),
        onTap: _loading ? null : _pick,
        customBorder: const CircleBorder(),
        child: Ink.image(
          image: image,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          child: _loading
              ? const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.bottomCenter,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const SizedBox(
                      width: 44,
                      height: 14,
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Covers the home content, sliding down from the top and stopping above the bar.
class _AddCover extends StatefulWidget {
  const _AddCover({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  State<_AddCover> createState() => _AddCoverState();
}

class _AddCoverState extends State<_AddCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.reverse();
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
      child: ColoredBox(
        color: const Color(0xFFF6F5F7),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: Tooltip(
                    message: 'Fechar',
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('close_add_delivery'),
                        customBorder: const CircleBorder(),
                        onTap: _close,
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: pouInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}
