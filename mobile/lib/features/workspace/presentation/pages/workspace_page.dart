import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../catalog/domain/entities/stock_operation.dart';
import '../../../catalog/presentation/pages/stock_operation_page.dart';
import '../../../freight/presentation/pages/freight_page.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/rules/month_board.dart';
import '../bloc/company_operation_bloc.dart';
import '../loaded_operation.dart';
import '../street_actions.dart';
import '../theme/workspace_colors.dart';
import '../widgets/street_board_view.dart';
import 'add_delivery_page.dart';
import 'provisional_action_page.dart';
import 'visit_customer_page.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key, this.onOpenCustomers});

  final VoidCallback? onOpenCustomers;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: loadedCompanyOperation(),
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

    return Theme(
      data: workspaceTheme(Theme.of(context)),
      child: Builder(
        builder: (context) {
          return Scaffold(
            key: const Key('workspace_home'),
            backgroundColor: pouCanvas,
            body: Column(
              children: [
                _WorkspaceHeader(
                  message: logoutError,
                  billed: _monthBilled(context),
                ),
                Expanded(
                  child: StreetBoardView(
                    valuesHidden: _valuesHidden,
                    onNewSale: _addDeliveryPerson,
                    onCustomers: loggingOut ? null : widget.onOpenCustomers,
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
                ),
              ],
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
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.message, required this.billed});

  final String? message;
  final MonthBilledDelta billed;

  static const _ink = pouInk;
  static const _gain = Color(0xFF34C759);
  static const _loss = Color(0xFFE53935);
  static const _gainSoft = Color(0xFFE4F6E5);
  static const _lossSoft = Color(0xFFFDECEA);

  @override
  Widget build(BuildContext context) {
    final up = billed.deltaCents >= 0;
    final deltaColor = up ? _gain : _loss;
    final deltaStyle = TextStyle(
      color: deltaColor,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: ColoredBox(
        key: const Key('workspace_header'),
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 14, 16),
            child: Column(
              children: [
                const Row(
                  children: [
                    _HeaderAvatar(),
                    SizedBox(width: 10),
                    Text(
                      'Sandy',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.notifications_none, color: _ink, size: 26),
                  ],
                ),
                const SizedBox(height: 22),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1, right: 1),
                        child: Text(
                          r'$',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),
                      Text(
                        _usdNumber(billed.billedCents),
                        key: const Key('header_month_billed'),
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.3,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _signedUsd(billed.deltaCents),
                      key: const Key('header_month_delta'),
                      style: deltaStyle,
                    ),
                    if (billed.hasPercent) ...[
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: up ? _gainSoft : _lossSoft,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(20),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            _signedPercent(billed.deltaPercent),
                            key: const Key('header_month_percent'),
                            style: deltaStyle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _ink),
                  ),
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

  static String _signedUsd(int cents) {
    final sign = cents > 0
        ? '+ '
        : cents < 0
        ? '- '
        : '';
    return '$sign\$${_usdNumber(cents.abs())}';
  }

  static String _signedPercent(double percent) {
    final sign = percent > 0
        ? '+ '
        : percent < 0
        ? '- '
        : '';
    return '$sign${percent.abs().toStringAsFixed(2)}%';
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar();

  @override
  Widget build(BuildContext context) {
    return const ClipOval(
      child: Image(
        image: AssetImage('assets/header_avatar.png'),
        width: 36,
        height: 36,
        fit: BoxFit.cover,
      ),
    );
  }
}
