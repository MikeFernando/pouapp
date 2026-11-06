import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workspace_mode.dart';
import '../bloc/company_operation_bloc.dart';
import '../bloc/workspace_mode_bloc.dart';
import '../theme/workspace_colors.dart';
import 'gestao_dashboard.dart';
import 'workspace_header_curve.dart';

class ManagementBoardView extends StatelessWidget {
  const ManagementBoardView({
    super.key,
    required this.valuesHidden,
    required this.onOpenFinance,
    required this.onWeigh,
    required this.onOpenStock,
    required this.onSales,
    required this.onOpenSettings,
  });

  final bool valuesHidden;
  final VoidCallback onOpenFinance;
  final VoidCallback onWeigh;
  final VoidCallback onOpenStock;
  final VoidCallback onSales;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompanyOperationBloc, CompanyOperationState>(
      builder: (context, state) {
        final operation = state.operation;
        if (state.status == BoardStatus.initial ||
            state.status == BoardStatus.loading ||
            operation == null && state.status != BoardStatus.failure) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Carregando a gestão',
            ),
          );
        }
        if (state.status == BoardStatus.failure || operation == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.message ?? 'Não foi possível carregar a gestão.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.read<CompanyOperationBloc>().add(
                      const CompanyOperationRequested(),
                    ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }
        final colors = workspaceColorsOf(context);
        return _GestaoEntrance(
          color: colors.header,
          onOpenFinance: onOpenFinance,
          onWeigh: onWeigh,
          onOpenStock: onOpenStock,
          onSales: onSales,
          body: GestaoDashboard(
            sales: operation.postedSales,
            hidden: valuesHidden,
            onOpenSettings: onOpenSettings,
          ),
        );
      },
    );
  }
}

class _GestaoEntrance extends StatefulWidget {
  const _GestaoEntrance({
    required this.color,
    required this.onOpenFinance,
    required this.onWeigh,
    required this.onOpenStock,
    required this.onSales,
    required this.body,
  });

  final Color color;
  final VoidCallback onOpenFinance;
  final VoidCallback onWeigh;
  final VoidCallback onOpenStock;
  final VoidCallback onSales;
  final Widget body;

  @override
  State<_GestaoEntrance> createState() => _GestaoEntranceState();
}

class _GestaoEntranceState extends State<_GestaoEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final CurvedAnimation _content;
  WorkspaceMode? _mode;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
    );
    _content = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.72, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mode = context.watch<WorkspaceModeBloc>().state.mode;
    if (_mode == mode) return;
    final opening =
        mode == WorkspaceMode.gestao && _mode != WorkspaceMode.gestao;
    _mode = mode;
    if (opening) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _content.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8F7F2),
      child: Column(
        children: [
          SizedBox(
            height: 176,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final curve = _curve.value;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: curve == 0 ? 0.001 : curve,
                        child: SizedBox(
                          height: 176,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: HeaderCurvePainter(widget.color),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: child,
                    ),
                  ],
                );
              },
              child: _CategoryRow(
                reveal: _controller,
                onOpenFinance: widget.onOpenFinance,
                onWeigh: widget.onWeigh,
                onOpenStock: widget.onOpenStock,
                onSales: widget.onSales,
              ),
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _content,
              builder: (context, child) {
                return IgnorePointer(
                  ignoring: _content.value < 1,
                  child: Opacity(
                    opacity: _content.value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - _content.value)),
                      child: child,
                    ),
                  ),
                );
              },
              child: SingleChildScrollView(
                key: const Key('gestao_board_scroll'),
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                child: widget.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.reveal,
    required this.onOpenFinance,
    required this.onWeigh,
    required this.onOpenStock,
    required this.onSales,
  });

  final Animation<double> reveal;
  final VoidCallback onOpenFinance;
  final VoidCallback onWeigh;
  final VoidCallback onOpenStock;
  final VoidCallback onSales;

  double _slot(int index, int count) {
    final fromRight = count - 1 - index;
    final begin = 0.08 + fromRight * 0.12;
    final end = begin + 0.46;
    final value = reveal.value;
    if (value <= begin) return 0;
    if (value >= end) return 1;
    return Curves.easeOutCubic.transform((value - begin) / (end - begin));
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Financeiro', 'Pesagem', 'Estoque', 'Vendas'];
    final count = labels.length;
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final slot = width / count;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < count; index++)
                  _alongCurve(
                    index: index,
                    count: count,
                    width: width,
                    slot: slot,
                    progress: _slot(index, count),
                    icon: const [
                      Icons.account_balance_wallet_outlined,
                      Icons.scale_outlined,
                      Icons.inventory_2_outlined,
                      Icons.point_of_sale_outlined,
                    ][index],
                    label: labels[index],
                    tint: const [
                      Color(0xFFD7F2DF),
                      Color(0xFFFFF3C9),
                      Color(0xFFFFE3D4),
                      Color(0xFFF6E7CF),
                    ][index],
                    selected: index == 0,
                    onTap: [
                      onOpenFinance,
                      onWeigh,
                      onOpenStock,
                      onSales,
                    ][index],
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _alongCurve({
    required int index,
    required int count,
    required double width,
    required double slot,
    required double progress,
    required IconData icon,
    required String label,
    required Color tint,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final parked = (index + 0.5) / count;
    const outside = 1.28;
    final along = outside + (parked - outside) * progress;
    final center = along * width;
    return Positioned(
      left: center - slot / 2,
      width: slot,
      top: headerCurveSide + headerCurveDrop(along) - 32,
      child: IgnorePointer(
        ignoring: progress < 1,
        child: Opacity(
          opacity: Curves.easeOut.transform(progress.clamp(0, 1)),
          child: _Category(
            key: switch (index) {
              0 => const Key('action_finance'),
              1 => const Key('action_weigh'),
              2 => const Key('action_stock'),
              3 => const Key('action_sales'),
              _ => null,
            },
            icon: icon,
            label: label,
            tint: tint,
            selected: selected,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _Category extends StatelessWidget {
  const _Category({
    super.key,
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tint,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: const Color(0xFF1B3A2F), size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontSize: workspaceFontSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 28,
            height: 5,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE9896A) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
