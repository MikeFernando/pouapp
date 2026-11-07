import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../workspace/presentation/theme/workspace_colors.dart';
import '../../domain/entities/freight_ledger.dart';
import '../bloc/freight_bloc.dart';
import '../freight_labels.dart';
import '../freight_style.dart';
import 'freight_form_page.dart';
import 'freight_trip_page.dart';

class FreightPage extends StatelessWidget {
  const FreightPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FreightBloc>()..add(const FreightRequested()),
      child: const FreightBoard(),
    );
  }
}

Future<bool> submitFreight(BuildContext context, FreightChange change) async {
  final bloc = context.read<FreightBloc>();
  final seen = bloc.state;
  final pending = bloc.stream.firstWhere((state) => state != seen);
  bloc.add(FreightChangeSubmitted(change));
  final next = await pending;
  return next.message == null;
}

class FreightBoard extends StatelessWidget {
  const FreightBoard({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FreightBloc, FreightState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) {
        final message = state.message;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        final ledger = state.ledger;
        if (ledger == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final today = (clock ?? DateTime.now)();
        final summary = freightPeriodSummary(
          ledger,
          year: today.year,
          month: today.month,
        );
        return Scaffold(
          backgroundColor: freightCanvas,
          appBar: freightBar('Frete'),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      freightMonthLabel(today),
                      style: const TextStyle(
                        fontSize: workspaceFontPrimary,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: freightBlue),
                    onPressed: () => context.read<FreightBloc>().add(
                      const FreightPendingToggled(),
                    ),
                    child: Text(state.showPending ? 'Ver o mês' : 'Pendências'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _FreightCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _Metric(
                            label: 'Fretes combinados',
                            value: freightMoney(summary.combinedCents),
                            valueKey: const Key('freight_combined'),
                          ),
                          _Metric(
                            label: 'Recebido no período',
                            value: freightMoney(summary.receivedCents),
                            valueKey: const Key('freight_received'),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _Metric(
                            label: 'A receber',
                            value: freightMoney(summary.receivableCents),
                            valueKey: const Key('freight_receivable'),
                          ),
                          _Metric(
                            label: 'Serviços pendentes',
                            value: '${summary.pendingCount}',
                            valueKey: const Key('freight_pending'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _NextTrip(ledger: ledger),
              const SizedBox(height: 18),
              const _SectionLabel('Viagens'),
              _TripList(ledger: ledger),
              const SizedBox(height: 18),
              const _SectionLabel('Fretes locais'),
              _JobList(
                jobs: _localJobs(ledger, today, state.showPending),
                ledger: ledger,
                empty: 'Nenhum frete local neste período.',
              ),
              const SizedBox(height: 18),
              const _SectionLabel('A receber'),
              _ReceivableList(
                ledger: ledger,
                today: today,
                showPending: state.showPending,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('freight_new_trip'),
                      style: freightOutlinedWide,
                      onPressed: () => _openTripForm(context),
                      child: const Text('Nova viagem'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('freight_new_job'),
                      style: freightFilledWide,
                      onPressed: () => _openJobForm(context),
                      child: const Text('Novo frete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTripForm(BuildContext context) {
    final bloc = context.read<FreightBloc>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlocProvider.value(value: bloc, child: const FreightTripFormPage()),
      ),
    );
  }

  Future<void> _openJobForm(BuildContext context) {
    final bloc = context.read<FreightBloc>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlocProvider.value(value: bloc, child: const FreightJobFormPage()),
      ),
    );
  }
}

class _NextTrip extends StatelessWidget {
  const _NextTrip({required this.ledger});

  final FreightLedger ledger;

  @override
  Widget build(BuildContext context) {
    final trip = nextFreightTrip(ledger);
    if (trip == null) {
      return const _FreightCard(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Nenhuma viagem planejada.',
            style: TextStyle(
              fontSize: workspaceFontSecondary,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }
    final outbound = _directionCount(
      ledger,
      trip.id,
      FreightDirection.outbound,
    );
    final inbound = _directionCount(ledger, trip.id, FreightDirection.inbound);
    return _FreightCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Próxima viagem',
              style: TextStyle(
                fontSize: workspaceFontSecondary,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trip.name,
              style: const TextStyle(
                fontSize: workspaceFontPrimary,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${freightDayLabel(trip.departOn)} · ${freightDayLabel(trip.returnOn)}',
              style: const TextStyle(
                fontSize: workspaceFontSecondary,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ida $outbound · Volta $inbound',
              style: const TextStyle(
                fontSize: workspaceFontSecondary,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('freight_open_trip'),
                style: freightFilledWide,
                onPressed: () => openFreightTrip(context, trip.id),
                child: const Text('Abrir viagem'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.ledger});

  final FreightLedger ledger;

  @override
  Widget build(BuildContext context) {
    final trips = ledger.trips.toList()
      ..sort((a, b) => b.departOn.compareTo(a.departOn));
    if (trips.isEmpty) {
      return const _EmptyLine('Nenhuma viagem cadastrada.');
    }
    return _FreightCard(
      child: Column(
        children: [
          for (var index = 0; index < trips.length; index++) ...[
            if (index > 0) const _Hairline(),
            InkWell(
              onTap: () => openFreightTrip(context, trips[index].id),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trips[index].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: workspaceFontPrimary,
                              fontWeight: FontWeight.w700,
                              color: freightInk,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FreightPill(
                            label: freightTripStatusLabel(trips[index].status),
                            late: false,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            freightDayLabel(trips[index].departOn),
                            style: const TextStyle(
                              fontSize: workspaceFontSecondary,
                              color: freightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      freightMoney(
                        freightTripSummary(
                          ledger,
                          trips[index].id,
                        ).receivableCents,
                      ),
                      style: const TextStyle(
                        fontSize: workspaceFontPrimary,
                        fontWeight: FontWeight.w700,
                        color: freightInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  const _JobList({
    required this.jobs,
    required this.ledger,
    required this.empty,
  });

  final List<FreightJob> jobs;
  final FreightLedger ledger;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return _EmptyLine(empty);
    return _FreightCard(
      child: Column(
        children: [
          for (var index = 0; index < jobs.length; index++) ...[
            if (index > 0) const _Hairline(),
            _JobTile(job: jobs[index], ledger: ledger),
          ],
        ],
      ),
    );
  }
}

class _ReceivableList extends StatelessWidget {
  const _ReceivableList({
    required this.ledger,
    required this.today,
    required this.showPending,
  });

  final FreightLedger ledger;
  final DateTime today;
  final bool showPending;

  @override
  Widget build(BuildContext context) {
    final todayIso = freightIsoDate(today);
    final jobs = ledger.jobs.where((job) {
      if (!freightConfirmed(job)) return false;
      if (freightBalanceCents(ledger, job) <= 0) return false;
      if (showPending) return true;
      return freightInMonth(job.plannedOn, today.year, today.month);
    }).toList()..sort((a, b) => a.plannedOn.compareTo(b.plannedOn));
    if (jobs.isEmpty) return const _EmptyLine('Nenhum saldo em aberto.');
    return _FreightCard(
      child: Column(
        children: [
          for (var index = 0; index < jobs.length; index++) ...[
            if (index > 0) const _Hairline(),
            _JobTile(job: jobs[index], ledger: ledger, todayIso: todayIso),
          ],
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.ledger, this.todayIso});

  final FreightJob job;
  final FreightLedger ledger;
  final String? todayIso;

  @override
  Widget build(BuildContext context) {
    final standing = freightPaymentLabel(freightPaymentStanding(ledger, job));
    final late = todayIso != null && freightOverdue(ledger, job, todayIso!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: workspaceFontPrimary,
                    fontWeight: FontWeight.w700,
                    color: freightInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: workspaceFontSecondary,
                    color: freightMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FreightPill(label: standing, late: false),
                    if (late) const FreightPill(label: 'Atrasado', late: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            freightMoney(freightBalanceCents(ledger, job)),
            style: const TextStyle(
              fontSize: workspaceFontPrimary,
              fontWeight: FontWeight.w700,
              color: freightInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: workspaceFontSecondary,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              key: valueKey,
              style: const TextStyle(
                fontSize: workspaceFontPrimary,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: workspaceFontPrimary,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1C1C1E),
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return _FreightCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: workspaceFontSecondary,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _FreightCard extends StatelessWidget {
  const _FreightCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1E88E5),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFF3F4F6),
    );
  }
}

int _directionCount(
  FreightLedger ledger,
  String tripId,
  FreightDirection direction,
) {
  return ledger.jobs.where((job) {
    return job.tripId == tripId &&
        job.direction == direction &&
        job.status != FreightStatus.cancelled &&
        job.status != FreightStatus.draft;
  }).length;
}

List<FreightJob> _localJobs(
  FreightLedger ledger,
  DateTime today,
  bool showPending,
) {
  return ledger.jobs.where((job) {
    if (job.direction != FreightDirection.local) return false;
    if (job.status == FreightStatus.cancelled) return false;
    if (showPending) {
      return job.status == FreightStatus.scheduled ||
          job.status == FreightStatus.collected ||
          freightBalanceCents(ledger, job) > 0;
    }
    return freightInMonth(job.plannedOn, today.year, today.month);
  }).toList()..sort((a, b) => a.plannedOn.compareTo(b.plannedOn));
}

void openFreightTrip(BuildContext context, String tripId) {
  final bloc = context.read<FreightBloc>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: FreightTripPage(tripId: tripId),
      ),
    ),
  );
}
