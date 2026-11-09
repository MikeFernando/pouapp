import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../workspace/presentation/theme/workspace_colors.dart';
import '../../domain/entities/freight_ledger.dart';
import '../bloc/freight_bloc.dart';
import '../freight_labels.dart';
import '../freight_style.dart';
import 'freight_form_page.dart';
import 'freight_page.dart';

class FreightTripPage extends StatelessWidget {
  const FreightTripPage({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FreightBloc, FreightState>(
      builder: (context, state) {
        final ledger = state.ledger;
        final trip = ledger?.trips
            .where((item) => item.id == tripId)
            .firstOrNull;
        if (ledger == null || trip == null) {
          return const Scaffold(
            body: Center(child: Text('Viagem não encontrada.')),
          );
        }
        final summary = freightTripSummary(ledger, trip.id);
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: freightCanvas,
            appBar: AppBar(backgroundColor: pouAppBlue, foregroundColor: pouCanvas, title: Text(
                trip.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              bottom: const TabBar(
                isScrollable: true,
                indicatorColor: pouCanvas,
                labelColor: pouCanvas,
                unselectedLabelColor: pouSurface,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(fontSize: 14),
                tabs: [
                  Tab(text: 'Ida para Curitiba'),
                  Tab(text: 'Volta para Apiaí'),
                ],
              ),),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _TripSummary(trip: trip, summary: summary),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _DirectionList(
                        ledger: ledger,
                        trip: trip,
                        direction: FreightDirection.outbound,
                      ),
                      _DirectionList(
                        ledger: ledger,
                        trip: trip,
                        direction: FreightDirection.inbound,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.trip, required this.summary});

  final FreightTrip trip;
  final FreightTripSummary summary;

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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${freightTripStatusLabel(trip.status)} · ${freightDayLabel(trip.departOn)} a ${freightDayLabel(trip.returnOn)}',
                style: const TextStyle(
                  fontSize: workspaceFontSecondary,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Combinado ${freightMoney(summary.revenueCents)} · Recebido ${freightMoney(summary.receivedCents)}',
                style: const TextStyle(
                  fontSize: workspaceFontPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'A receber ${freightMoney(summary.receivableCents)} · Resultado ${freightMoney(summary.extraResultCents)}',
                key: const Key('freight_trip_result'),
                style: const TextStyle(fontSize: workspaceFontSecondary),
              ),
              if ((trip.spaceNote ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  trip.spaceNote!,
                  style: const TextStyle(
                    fontSize: workspaceFontSecondary,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (trip.status == FreightTripStatus.planned)
                    OutlinedButton(
                      style: freightOutlined,
                      onPressed: () =>
                          submitFreight(context, StartFreightTrip(trip.id)),
                      child: const Text('Iniciar viagem'),
                    ),
                  if (trip.status != FreightTripStatus.completed &&
                      trip.status != FreightTripStatus.cancelled)
                    FilledButton(
                      style: freightFilled,
                      key: const Key('freight_complete_trip'),
                      onPressed: () =>
                          submitFreight(context, CompleteFreightTrip(trip.id)),
                      child: const Text('Concluir viagem'),
                    ),
                  OutlinedButton(
                    style: freightOutlined,
                    onPressed: () => _addExpense(context, trip.id),
                    child: const Text('Gasto adicional'),
                  ),
                  OutlinedButton(
                    style: freightOutlined,
                    onPressed: () {
                      final bloc = context.read<FreightBloc>();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BlocProvider.value(
                            value: bloc,
                            child: FreightJobFormPage(tripId: trip.id),
                          ),
                        ),
                      );
                    },
                    child: const Text('Novo frete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addExpense(BuildContext context, String tripId) async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Gasto adicional'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('freight_expense_description'),
                controller: description,
                decoration: freightField('Descrição'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('freight_expense_amount'),
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: freightField('Valor'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
                      style: freightFilled,
              key: const Key('freight_expense_save'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    if (saved != true || !context.mounted) return;
    final cents = parseFreightCents(amount.text);
    if (cents == null) return;
    await submitFreight(
      context,
      SaveFreightExpense(
        tripId: tripId,
        description: description.text,
        amountCents: cents,
        paidOn: freightIsoDate(DateTime.now()),
      ),
    );
  }
}

class _DirectionList extends StatelessWidget {
  const _DirectionList({
    required this.ledger,
    required this.trip,
    required this.direction,
  });

  final FreightLedger ledger;
  final FreightTrip trip;
  final FreightDirection direction;

  @override
  Widget build(BuildContext context) {
    final jobs = ledger.jobs.where((job) {
      return job.tripId == trip.id && job.direction == direction;
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (jobs.isEmpty) {
      return const Center(child: Text('Nenhum frete neste sentido.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _TripJobCard(job: jobs[index], ledger: ledger);
      },
    );
  }
}

class _TripJobCard extends StatelessWidget {
  const _TripJobCard({required this.job, required this.ledger});

  final FreightJob job;
  final FreightLedger ledger;

  @override
  Widget build(BuildContext context) {
    final standing = freightPaymentStanding(ledger, job);
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.customerName,
                style: const TextStyle(
                  fontSize: workspaceFontPrimary,
                  fontWeight: FontWeight.w700,
                  color: freightInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                job.description,
                style: const TextStyle(
                  fontSize: workspaceFontSecondary,
                  color: freightInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${job.pickup} → ${job.dropoff}',
                style: const TextStyle(
                  fontSize: workspaceFontSecondary,
                  color: freightMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FreightPill(
                    label: freightStatusLabel(job.status),
                    late: false,
                  ),
                  FreightPill(
                    label: freightPaymentLabel(standing),
                    late: false,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${freightMoney(job.priceCents)} · Saldo ${freightMoney(freightBalanceCents(ledger, job))}',
                key: Key('freight_job_${job.id}'),
                style: const TextStyle(
                  fontSize: workspaceFontSecondary,
                  fontWeight: FontWeight.w600,
                  color: freightInk,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (job.status == FreightStatus.scheduled)
                    FilledButton(
                      style: freightFilled,
                      key: Key('freight_collect_${job.id}'),
                      onPressed: () =>
                          submitFreight(context, CollectFreight(job.id)),
                      child: const Text('Coletar'),
                    ),
                  if (job.status == FreightStatus.collected)
                    FilledButton(
                      style: freightFilled,
                      key: Key('freight_deliver_${job.id}'),
                      onPressed: () =>
                          submitFreight(context, DeliverFreight(job.id)),
                      child: const Text('Entregar'),
                    ),
                  if (freightConfirmed(job) &&
                      freightBalanceCents(ledger, job) > 0)
                    OutlinedButton(
                      key: Key('freight_receive_${job.id}'),
                      style: freightOutlined,
                      onPressed: () => _receive(context, job, ledger),
                      child: const Text('Receber'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _receive(
    BuildContext context,
    FreightJob job,
    FreightLedger ledger,
  ) async {
    final amount = TextEditingController(
      text: (freightBalanceCents(ledger, job) / 100)
          .toStringAsFixed(2)
          .replaceAll('.', ','),
    );
    var method = FreightPayMethod.pix;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Receber frete'),
          content: TextField(
            key: const Key('freight_receipt_amount'),
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: freightField('Valor'),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: freightAccent),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
                      style: freightFilled,
              key: const Key('freight_receipt_save'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Receber'),
            ),
          ],
        );
      },
    );
    if (saved != true || !context.mounted) return;
    final cents = parseFreightCents(amount.text);
    if (cents == null) return;
    await submitFreight(
      context,
      SaveFreightReceipt(
        id: 'receipt-${job.id}-${DateTime.now().microsecondsSinceEpoch}',
        jobId: job.id,
        amountCents: cents,
        paidOn: freightIsoDate(DateTime.now()),
        method: method,
      ),
    );
  }
}
