import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/entities/workspace_mode.dart';
import '../bloc/company_operation_bloc.dart';
import '../loaded_operation.dart';
import '../bloc/workspace_mode_bloc.dart';
import '../street_actions.dart';
import '../theme/workspace_colors.dart';
import '../widgets/finance_board_view.dart';
import '../widgets/management_board_view.dart';
import '../../../catalog/domain/entities/stock_operation.dart';
import '../../../catalog/presentation/pages/products_page.dart';
import '../../../catalog/presentation/pages/stock_operation_page.dart';
import '../../../freight/presentation/pages/freight_page.dart';
import '../widgets/street_board_view.dart';
import 'business_settings_page.dart';
import 'cash_flow_page.dart';
import 'movements_page.dart';
import 'provisional_action_page.dart';
import 'weigh_pack_page.dart';
import 'add_delivery_page.dart';
import 'visit_customer_page.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key, this.onOpenCustomers});

  final VoidCallback? onOpenCustomers;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              sl<WorkspaceModeBloc>()..add(const WorkspaceModeRequested()),
        ),
        BlocProvider.value(value: loadedCompanyOperation()),
      ],
      child: WorkspaceView(onOpenCustomers: onOpenCustomers),
    );
  }
}

class WorkspaceView extends StatefulWidget {
  const WorkspaceView({super.key, this.onOpenCustomers});

  final VoidCallback? onOpenCustomers;

  @override
  State<WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends State<WorkspaceView> {
  final _valuesHidden = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = switch (auth) {
      Authenticated(:final user) => user,
      AuthLogoutInProgress(:final user) => user,
      _ => null,
    };
    if (user == null) return const SizedBox.shrink();

    final loggingOut = auth is AuthLogoutInProgress;
    final logoutError = auth is Authenticated ? auth.errorMessage : null;

    return BlocBuilder<WorkspaceModeBloc, WorkspaceModeState>(
      builder: (context, modeState) {
        final mode = modeState.mode;
        return _ModeTransition(
          mode: mode,
          child: Theme(
            data: workspaceTheme(Theme.of(context), mode),
            child: Builder(
              builder: (context) {
                final colors = workspaceColorsOf(context);
                return Scaffold(
                  backgroundColor: const Color(0xFFF4F6F8),
                  body: Column(
                    children: [
                      _WorkspaceHeader(
                        colors: colors,
                        mode: mode,
                        message: modeState.message ?? logoutError,
                        onSelectMode: (selected) => context
                            .read<WorkspaceModeBloc>()
                            .add(WorkspaceModeSelected(selected)),
                      ),
                      Expanded(
                        child: _ModeBody(
                          rua: StreetBoardView(
                            valuesHidden: _valuesHidden,
                            onNewSale: _addDeliveryPerson,
                            onCustomers: loggingOut
                                ? null
                                : widget.onOpenCustomers,
                            onRegisterReceipt: () {},
                            onComplete: _completeVisit,
                            onPostpone: _postponeVisit,
                            onRemove: _removeVisit,
                            onOpenCustomer: _openVisitCustomer,
                            onOpenSale: (sale) => _openProvisional(
                              'Venda ${sale.code}',
                              'A venda ${sale.code} também está na conta da cliente.',
                            ),
                            onOpenFreight: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const FreightPage(),
                                ),
                              );
                            },
                            onLoadMontana: () =>
                                _openStockOperation(StockOperationKind.load),
                            onReturnToWarehouse: () => _openStockOperation(
                              StockOperationKind.returnToWarehouse,
                            ),
                          ),
                          gestao: ManagementBoardView(
                            valuesHidden: _valuesHidden,
                            onOpenFinance: _openFinance,
                            onWeigh: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const WeighProductsPage(),
                                ),
                              );
                            },
                            onOpenStock: _openStock,
                            onSales: () => _openProvisional(
                              'Vendas',
                              'O detalhe das vendas entra numa próxima versão.',
                            ),
                            onOpenSettings: _openPixSettings,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
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

  void _openFinance() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: workspaceTheme(Theme.of(context), WorkspaceMode.gestao),
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F6F8),
            appBar: AppBar(
              backgroundColor: WorkspaceColors.gestao.header,
              foregroundColor: Colors.white,
              elevation: 0,
              titleTextStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              title: const Text('Financeiro', key: Key('finance_title')),
            ),
            body: FinanceBoardView(
              showTitle: false,
              onOpenStatement: _openStatement,
              onOpenCashFlow: _openCashFlow,
              onOpenReconciliation: () => _openProvisional(
                'Conciliações pendentes',
                'A conciliação dos recebimentos entra numa próxima versão.',
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCashFlow() {
    final bloc = context.read<CompanyOperationBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlocProvider.value(value: bloc, child: const CashFlowPage()),
      ),
    );
  }

  void _openStatement() {
    final bloc = context.read<CompanyOperationBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlocProvider.value(value: bloc, child: const MovementsPage()),
      ),
    );
  }

  void _addDeliveryPerson() {
    final bloc = context.read<CompanyOperationBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlocProvider.value(value: bloc, child: const AddDeliveryPage()),
      ),
    );
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

  Future<void> _openStockOperation(StockOperationKind kind) async {
    final bloc = context.read<CompanyOperationBloc>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StockOperationPage(kind: kind)),
    );
    if (!mounted) return;
    bloc.add(const CompanyOperationRequested());
  }

  void _openPixSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BusinessSettingsPage()),
    );
  }

  Future<void> _openStock() async {
    final bloc = context.read<CompanyOperationBloc>();
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ProductsPage()));
    if (!mounted) return;
    bloc.add(const CompanyOperationRequested());
  }

  void _openProvisional(String title, String detail) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProvisionalActionPage(title: title, detail: detail),
      ),
    );
  }
}

const _modeMotion = Duration(milliseconds: 380);

class _ModeTransition extends StatefulWidget {
  const _ModeTransition({required this.mode, required this.child});

  final WorkspaceMode mode;
  final Widget child;

  @override
  State<_ModeTransition> createState() => _ModeTransitionState();
}

class _ModeTransitionState extends State<_ModeTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _modeMotion,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(_ModeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ModeMotion(
      animation: _controller,
      mode: widget.mode,
      child: widget.child,
    );
  }
}

class _ModeMotion extends InheritedWidget {
  const _ModeMotion({
    required this.animation,
    required this.mode,
    required super.child,
  });

  final Animation<double> animation;
  final WorkspaceMode mode;

  double get t => Curves.easeOutCubic.transform(animation.value);

  bool get settled => animation.status == AnimationStatus.completed;

  double slideOf(WorkspaceMode pane, double width) {
    final active = mode == pane;
    final direction = mode == WorkspaceMode.gestao ? -1.0 : 1.0;
    return active ? direction * width * (t - 1) : direction * width * t;
  }

  static _ModeMotion of(BuildContext context) {
    final motion = context.dependOnInheritedWidgetOfExactType<_ModeMotion>();
    assert(motion != null, 'Workspace mode motion is missing');
    return motion!;
  }

  @override
  bool updateShouldNotify(_ModeMotion oldWidget) {
    return animation != oldWidget.animation || mode != oldWidget.mode;
  }
}

class _ModeBody extends StatelessWidget {
  const _ModeBody({required this.rua, required this.gestao});

  final Widget rua;
  final Widget gestao;

  @override
  Widget build(BuildContext context) {
    final motion = _ModeMotion.of(context);
    return AnimatedBuilder(
      animation: motion.animation,
      builder: (context, _) {
        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(child: _pane(context, WorkspaceMode.rua, rua)),
              Positioned.fill(
                child: _pane(context, WorkspaceMode.gestao, gestao),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pane(BuildContext context, WorkspaceMode pane, Widget child) {
    final motion = _ModeMotion.of(context);
    final active = motion.mode == pane;
    final width = MediaQuery.sizeOf(context).width;
    return Offstage(
      offstage: motion.settled && !active,
      child: IgnorePointer(
        ignoring: !active,
        child: Transform.translate(
          offset: Offset(motion.slideOf(pane, width), 0),
          child: Theme(
            data: workspaceTheme(Theme.of(context), pane),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.colors,
    required this.mode,
    required this.message,
    required this.onSelectMode,
  });

  final WorkspaceColors colors;
  final WorkspaceMode mode;
  final String? message;
  final ValueChanged<WorkspaceMode> onSelectMode;

  @override
  Widget build(BuildContext context) {
    final motion = _ModeMotion.of(context);
    final onHeader = colors.onHeader;
    return AnimatedBuilder(
      animation: motion.animation,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        return ClipRect(
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              _wash(
                context,
                WorkspaceMode.rua,
                WorkspaceColors.rua.header,
                width,
              ),
              _wash(
                context,
                WorkspaceMode.gestao,
                WorkspaceColors.gestao.header,
                width,
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModeSelector(
                        mode: mode,
                        selectedColor: colors.header,
                        onSelectMode: onSelectMode,
                      ),
                      const SizedBox(height: 24),
                      _OfficeLocation(
                        accent: mode == WorkspaceMode.gestao
                            ? const Color(0xFFC5DEB3)
                            : const Color(0xFFFFFFFF),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 8),
                        Text(message!, style: TextStyle(color: onHeader)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wash(
    BuildContext context,
    WorkspaceMode pane,
    Color color,
    double width,
  ) {
    final motion = _ModeMotion.of(context);
    final active = motion.mode == pane;
    if (motion.settled && !active) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(motion.slideOf(pane, width), 0),
          child: ColoredBox(
            key: active ? const Key('workspace_header') : null,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _OfficeLocation extends StatelessWidget {
  const _OfficeLocation({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          const Text(
            'Localização atual',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xB8FFFFFF),
              fontSize: workspaceFontSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Apiaí, SP',
                style: TextStyle(
                  color: accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.near_me, color: accent, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.selectedColor,
    required this.onSelectMode,
  });

  final WorkspaceMode mode;
  final Color selectedColor;
  final ValueChanged<WorkspaceMode> onSelectMode;

  @override
  Widget build(BuildContext context) {
    final index = mode == WorkspaceMode.rua ? 0 : 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segment = constraints.maxWidth / 2;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: _modeMotion,
                  curve: Curves.easeOutCubic,
                  left: segment * index,
                  width: segment,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        key: const Key('workspace_mode_rua'),
                        selected: mode == WorkspaceMode.rua,
                        icon: Icons.local_shipping_outlined,
                        label: 'Entregas',
                        onTap: () => onSelectMode(WorkspaceMode.rua),
                      ),
                    ),
                    Expanded(
                      child: _ModeButton(
                        key: const Key('workspace_mode_gestao'),
                        selected: mode == WorkspaceMode.gestao,
                        icon: Icons.business_center_outlined,
                        label: 'Gestão',
                        onTap: () => onSelectMode(WorkspaceMode.gestao),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFF1B3A2F);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: foreground),
                duration: _modeMotion,
                builder: (context, color, _) =>
                    Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: foreground),
                  duration: _modeMotion,
                  builder: (context, color, _) => Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: workspaceFontSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
