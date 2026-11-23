import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/nav_glyphs.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../app/pou_shell_navigation.dart';
import '../../../../core/config/api_config.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../catalog/presentation/pages/products_page.dart';
import '../../../customers/presentation/customer_routes.dart';
import '../../../customers/presentation/pages/customers_page.dart';
import '../../data/day_checklist_store.dart';
import '../../domain/rules/month_board.dart';
import '../bloc/company_operation_bloc.dart';
import '../bloc/home_board_bloc.dart';
import '../loaded_operation.dart';
import '../operation_labels.dart';
import '../theme/workspace_colors.dart';
import '../widgets/pou_drawer_3d.dart';
import '../widgets/street_board_view.dart';
import '../widgets/theme_selector.dart';
import 'add_delivery_page.dart';
import 'finance_page.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final company = loadedCompanyOperation();
    final home = loadedHomeBoard();
    if (home == null) {
      return BlocProvider.value(value: company, child: const WorkspaceView());
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
  var _checklistReceivedCents = 0;
  Map<String, int> _checklistProductCents = const {};
  var _committedReceivedCents = 0;
  Map<String, int> _committedProductCents = const {};

  @override
  void initState() {
    super.initState();
    _reloadCommitted();
  }

  void _reloadCommitted() {
    if (!di.sl.isRegistered<DayChecklistStore>()) return;
    final total = di.sl<DayChecklistStore>().committedTotal();
    _committedReceivedCents = total.receivedCents;
    _committedProductCents = Map<String, int>.of(total.productCents);
  }

  Map<String, int> get _financeProductCents {
    final merged = Map<String, int>.of(_checklistProductCents);
    for (final entry in _committedProductCents.entries) {
      merged[entry.key] = (merged[entry.key] ?? 0) + entry.value;
    }
    return merged;
  }

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
      data: workspaceTheme(Theme.of(context), brand: pouThemeBrand(context)),
      child: Builder(
        builder: (context) {
          return PouDrawer3D(
            user: user,
            child: RoundedNavigationScaffold(
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
                                  receivedTodayCents:
                                      _receivedTodayCents(context) +
                                      _checklistReceivedCents +
                                      _committedReceivedCents,
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
                                    checklistProductCents: _financeProductCents,
                                    onNewSale: _addDeliveryPerson,
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
                                      setState(_reloadCommitted);
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
                                  onClose: () =>
                                      setState(() => _adding = false),
                                  child: AddDeliveryPage(
                                    onOpenCustomer: (customerId) async {
                                      setState(() => _adding = false);
                                      await Navigator.of(context).pushNamed(
                                        CustomerRoutes.details(customerId),
                                      );
                                      if (!context.mounted) return;
                                      setState(_reloadCommitted);
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
                            ? FinancePage(
                                checklistProductCents: _financeProductCents,
                                checklistReceivedCents:
                                    _checklistReceivedCents +
                                    _committedReceivedCents,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
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
      return context.watch<HomeBoardBloc>().state.board?.receivedTodayCents ??
          0;
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
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
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
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * 0.56,
                            ),
                            child: ThemeSelector(userId: user.id),
                          ),
                        ],
                      );
                    },
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
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          ),
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
