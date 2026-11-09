import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/nav_glyphs.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../app/rounded_navigation_scaffold.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../catalog/presentation/pages/products_page.dart';
import '../../../customers/presentation/pages/customers_page.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/month_board.dart';
import '../bloc/company_operation_bloc.dart';
import '../loaded_operation.dart';
import '../street_actions.dart';
import '../theme/workspace_colors.dart';
import '../widgets/street_board_view.dart';
import 'add_delivery_page.dart';
import 'business_settings_page.dart';
import 'finance_page.dart';
import 'provisional_action_page.dart';
import 'visit_customer_page.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: loadedCompanyOperation(),
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
  final _valuesHidden = false;
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
                                message: logoutError,
                                billed: _monthBilled(context),
                                snapshot: _monthSnapshot(context),
                              ),
                              Expanded(
                                child: StreetBoardView(
                                  valuesHidden: _valuesHidden,
                                  onNewSale: _addDeliveryPerson,
                                  onComplete: _completeVisit,
                                  onPostpone: _postponeVisit,
                                  onRemove: _removeVisit,
                                  onOpenCustomer: _openVisitCustomer,
                                  onOpenSale: (sale) => _openProvisional(
                                    'Venda ${sale.code}',
                                    'A venda ${sale.code} também está na conta da cliente.',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_adding)
                            Positioned.fill(
                              child: _AddCover(
                                onClose: () => setState(() => _adding = false),
                                child: const AddDeliveryPage(),
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

  void _openVisitCustomer(RouteVisit visit) {
    final bloc = context.read<CompanyOperationBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: VisitCustomerPage(
            customerId: visit.customerId,
            customerName: visit.customerName,
          ),
        ),
      ),
    );
  }

  void _addDeliveryPerson() {
    setState(() => _adding = true);
  }

  void _completeVisit(RouteVisit visit) {
    applyStreetChange(context, CompleteVisit(visit.id));
  }

  Future<void> _postponeVisit(RouteVisit visit) async {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 365)),
      helpText: 'Adiar entrega',
      cancelText: 'Cancelar',
      confirmText: 'Adiar',
    );
    if (picked == null || !mounted) return;
    await applyStreetChange(
      context,
      MissVisit(visitId: visit.id, rescheduleOn: isoDate(picked)),
    );
  }

  void _removeVisit(RouteVisit visit) {
    applyStreetChange(context, RemoveRouteVisit(visit.id));
  }

  void _openProvisional(String title, String detail) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProvisionalActionPage(title: title, detail: detail),
      ),
    );
  }

  MonthBilledDelta _monthBilled(BuildContext context) {
    final operation = context.watch<CompanyOperationBloc>().state.operation;
    return monthBilledDelta(
      sales: operation?.postedSales ?? const [],
      today: DateTime.now(),
    );
  }

  MonthSnapshot _monthSnapshot(BuildContext context) {
    final operation = context.watch<CompanyOperationBloc>().state.operation;
    final now = DateTime.now();
    return monthSnapshot(
      sales: operation?.postedSales ?? const [],
      month: DateTime(now.year, now.month),
      today: now,
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.message,
    required this.billed,
    required this.snapshot,
  });

  final String? message;
  final MonthBilledDelta billed;
  final MonthSnapshot snapshot;

  static const _ink = pouInk;
  static const _muted = Color(0xFF9A9AA2);

  @override
  Widget build(BuildContext context) {
    final fraction = (snapshot.receivedPercent / 100).clamp(0.0, 1.0);
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
                    const Expanded(
                      child: Text(
                        'Sandy',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    _HeaderRoundIcon(
                      icon: Icons.settings_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BusinessSettingsPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    const _HeaderRoundIcon(icon: Icons.notifications_none),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Recebido',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '\$${_usdNumber(snapshot.receivedCents)}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Faturado',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '\$${_usdNumber(billed.billedCents)}',
                      key: const Key('header_month_billed'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (fraction > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: _ink,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                        child: SizedBox(height: 3, width: double.infinity),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Em aberto \$${_usdNumber(snapshot.openCents)}',
                  key: const Key('header_month_delta'),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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

  static String _usdNumber(int cents) {
    final value = cents.abs();
    final whole = value ~/ 100;
    final fraction = (value % 100).toString().padLeft(2, '0');
    final digits = whole.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      if (index > 0 && remaining % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return '$buffer.$fraction';
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
        image: AssetImage('assets/header_avatar.png'),
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
