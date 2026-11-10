import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/nav_glyphs.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../app/rounded_navigation_scaffold.dart';
import '../../../../core/config/api_config.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
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
                                  onOpenCustomer: (customerId) {
                                    Navigator.of(context).pushNamed(
                                      CustomerRoutes.details(customerId),
                                    );
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
                                  onRemoteAdded: () {
                                    if (ApiConfig.useRemoteApi) {
                                      context.read<HomeBoardBloc>().add(
                                        const HomeBoardRequested(),
                                      );
                                    }
                                    setState(() => _adding = false);
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
        systemNavigationBarColor: pouInk,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: ColoredBox(
        key: const Key('workspace_header'),
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _HeaderAvatar(),
                    const SizedBox(width: 12),
                    Expanded(
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
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
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

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar();

  @override
  Widget build(BuildContext context) {
    return const ClipOval(
      child: Image(
        image: AssetImage('assets/header_avatar.jpg'),
        width: 44,
        height: 44,
        fit: BoxFit.cover,
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
                child: IconButton(
                  key: const Key('close_add_delivery'),
                  tooltip: 'Fechar',
                  onPressed: _close,
                  icon: const Icon(Icons.close, color: pouInk),
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
