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
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../catalog/presentation/pages/products_page.dart';
import '../../../customers/presentation/customer_routes.dart';
import '../../../customers/presentation/pages/customers_page.dart';
import '../../domain/rules/month_board.dart';
import '../bloc/company_operation_bloc.dart';
import '../bloc/home_board_bloc.dart';
import '../loaded_operation.dart';
import '../operation_labels.dart';
import '../theme/workspace_colors.dart';
import '../widgets/profile_menu_sheet.dart';
import '../widgets/street_board_view.dart';
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
  var _checklistReceivedCents = 0;
  Map<String, int> _checklistProductCents = const {};

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
                      Column(
                        children: [
                          _WorkspaceHeader(
                            user: user,
                            message: logoutError,
                            receivedTodayCents:
                                _receivedTodayCents(context) +
                                _checklistReceivedCents,
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
                              onChecklistChanged: (snapshot) {
                                if (_checklistReceivedCents ==
                                        snapshot.receivedCents &&
                                    _sameProductCents(
                                      _checklistProductCents,
                                      snapshot.productCents,
                                    )) {
                                  return;
                                }
                                setState(() {
                                  _checklistReceivedCents =
                                      snapshot.receivedCents;
                                  _checklistProductCents = Map.of(
                                    snapshot.productCents,
                                  );
                                });
                              },
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
                          ? FinancePage(
                              checklistProductCents: _checklistProductCents,
                              checklistReceivedCents: _checklistReceivedCents,
                            )
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

  bool _sameProductCents(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
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
  static const _muted = Color(0xFF7A858A);
  static const _radius = 28.0;
  static const _glass = Color(0xFFEEF5F6);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

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
          bottomLeft: Radius.circular(_radius),
          bottomRight: Radius.circular(_radius),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: Colors.white),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _glass.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.92),
                      _glass.withValues(alpha: 0.78),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(_radius),
                      bottomRight: Radius.circular(_radius),
                    ),
                    border: Border.all(
                      color: const Color(0xFFE6EBEF),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 8, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recebido hoje',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
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
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1.0,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  key: const Key('workspace_hide_values'),
                                  tooltip: valuesHidden
                                      ? 'Mostrar valores'
                                      : 'Esconder valores',
                                  onPressed: onToggleValues,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    valuesHidden
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _ink,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _HeaderAvatar(userId: user.id),
                    ],
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(message!, style: const TextStyle(color: _ink)),
                  ],
                ],
              ),
            ),
          ],
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

  Future<void> _openMenu() async {
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
        onTap: _loading ? null : _openMenu,
        customBorder: const CircleBorder(),
        child: Ink.image(
          image: image,
          width: 46,
          height: 46,
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
              : null,
        ),
      ),
    );
  }
}
