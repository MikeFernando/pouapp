import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/freight/domain/entities/freight_ledger.dart';

void main() {
  test('should match the extra-income example', () {
    final ledger = exampleFreightLedger();
    final month = freightPeriodSummary(ledger, year: 2026, month: 10);
    final trip = freightTripSummary(ledger, 'trip-curitiba');

    expect(month.combinedCents, 40000);
    expect(month.receivedCents, 20000);
    expect(month.receivableCents, 20000);
    expect(month.pendingCount, 3);
    expect(trip.revenueCents, 40000);
    expect(trip.receivedCents, 20000);
    expect(trip.receivableCents, 20000);
    expect(trip.extraResultCents, 35000);
    expect(trip.cashAfterExpensesCents, 15000);
  });

  test('should keep a partial balance after delivering', () {
    final ledger = exampleFreightLedger();
    final delivered = updateFreightLedger(
      ledger,
      const CollectFreight('job-volta-ricardo'),
      now: DateTime(2026, 10, 29),
    ).ledger!;
    final done = updateFreightLedger(
      delivered,
      const DeliverFreight('job-volta-ricardo'),
      now: DateTime(2026, 10, 29),
    ).ledger!;
    final job = done.jobs.firstWhere((item) => item.id == 'job-volta-ricardo');

    expect(job.status, FreightStatus.delivered);
    expect(netReceivedCents(done, job.id), 8000);
    expect(freightBalanceCents(done, job), 10000);
    expect(freightPaymentStanding(done, job), FreightPaymentStanding.partial);
  });

  test('should count a later receipt in its own month', () {
    var ledger = exampleFreightLedger();
    ledger =
        updateFreightLedger(
          ledger,
          const CompleteFreightTrip('trip-curitiba'),
        ).ledger ??
        ledger;
    expect(
      updateFreightLedger(
        ledger,
        const CompleteFreightTrip('trip-curitiba'),
      ).error,
      isNotNull,
    );

    for (final job in ledger.jobs) {
      if (job.status == FreightStatus.scheduled) {
        ledger = updateFreightLedger(ledger, CollectFreight(job.id)).ledger!;
        ledger = updateFreightLedger(ledger, DeliverFreight(job.id)).ledger!;
      }
    }
    final closed = updateFreightLedger(
      ledger,
      const CompleteFreightTrip('trip-curitiba'),
    );
    expect(closed.error, isNull);
    ledger = closed.ledger!;

    final paid = updateFreightLedger(
      ledger,
      const SaveFreightReceipt(
        id: 'receipt-beatriz',
        jobId: 'job-volta-beatriz',
        amountCents: 10000,
        paidOn: '2026-11-03',
        method: FreightPayMethod.pix,
      ),
    ).ledger!;
    final october = freightPeriodSummary(paid, year: 2026, month: 10);
    final november = freightPeriodSummary(paid, year: 2026, month: 11);
    final beatriz = paid.jobs.firstWhere(
      (job) => job.id == 'job-volta-beatriz',
    );

    expect(freightBalanceCents(paid, beatriz), 0);
    expect(october.receivedCents, 20000);
    expect(november.receivedCents, 10000);
    expect(october.receivableCents, 10000);
    expect(
      paid.trips.singleWhere((trip) => trip.id == 'trip-curitiba').status,
      FreightTripStatus.completed,
    );
  });

  test('should ignore drafts and keep a voided receipt in history', () {
    final ledger = exampleFreightLedger();
    final draft = updateFreightLedger(
      ledger,
      const SaveFreightJob(
        customerId: 'demo-customer-joao',
        customerName: 'João Oliveira',
        direction: FreightDirection.local,
        description: 'Rascunho',
        pickup: '',
        dropoff: '',
        plannedOn: '2026-10-22',
        priceCents: 9000,
        draft: true,
      ),
    ).ledger!;
    expect(
      freightPeriodSummary(draft, year: 2026, month: 10).combinedCents,
      40000,
    );

    final voided = updateFreightLedger(
      draft,
      const VoidFreightReceipt('receipt-marina'),
    ).ledger!;
    expect(
      voided.receipts.singleWhere((item) => item.id == 'receipt-marina').voided,
      isTrue,
    );
    expect(netReceivedCents(voided, 'job-ida-marina'), 0);

    final cancelled = updateFreightLedger(
      voided,
      const CancelFreight(jobId: 'job-ida-marina', reason: 'Cliente desistiu'),
    ).ledger!;
    expect(
      freightPeriodSummary(cancelled, year: 2026, month: 10).combinedCents,
      28000,
    );
    expect(
      cancelled.receipts.any((item) => item.id == 'receipt-marina'),
      isTrue,
    );
  });

  test('should not duplicate the same receipt or the same expense', () {
    final ledger = exampleFreightLedger();
    final again = updateFreightLedger(
      ledger,
      const SaveFreightReceipt(
        id: 'receipt-ricardo',
        jobId: 'job-volta-ricardo',
        amountCents: 8000,
        paidOn: '2026-10-18',
        method: FreightPayMethod.cash,
      ),
    ).ledger!;
    expect(again.receipts.where((item) => item.id == 'receipt-ricardo'), [
      ledger.receipts.singleWhere((item) => item.id == 'receipt-ricardo'),
    ]);
    expect(netReceivedCents(again, 'job-volta-ricardo'), 8000);

    final blocked = updateFreightLedger(
      ledger,
      const SaveFreightReceipt(
        id: 'receipt-extra',
        jobId: 'job-volta-ricardo',
        amountCents: 10001,
        paidOn: '2026-10-20',
        method: FreightPayMethod.pix,
      ),
    );
    expect(blocked.error, isNotNull);

    final withJobExpense = updateFreightLedger(
      ledger,
      const SaveFreightExpense(
        jobId: 'job-volta-beatriz',
        description: 'Ajudante',
        amountCents: 2000,
        paidOn: '2026-10-29',
      ),
    ).ledger!;
    expect(
      freightTripSummary(withJobExpense, 'trip-curitiba').expenseCents,
      7000,
    );
  });

  test('should allow a local freight without a Curitiba trip', () {
    final saved = updateFreightLedger(
      exampleFreightLedger(),
      const SaveFreightJob(
        customerId: 'demo-customer-joao',
        customerName: 'João Oliveira',
        direction: FreightDirection.local,
        description: 'Entrega no centro',
        pickup: 'Apiaí, rodoviária',
        dropoff: 'Apiaí, centro',
        plannedOn: '2026-10-22',
        priceCents: 3000,
      ),
    );
    expect(saved.error, isNull);
    expect(saved.ledger!.jobs.last.tripId, isNull);

    final missingTrip = updateFreightLedger(
      exampleFreightLedger(),
      const SaveFreightJob(
        customerId: 'demo-customer-joao',
        customerName: 'João Oliveira',
        direction: FreightDirection.outbound,
        description: 'Caixa',
        pickup: 'Apiaí',
        dropoff: 'Curitiba',
        plannedOn: '2026-10-28',
        priceCents: 1000,
      ),
    );
    expect(missingTrip.error, isNotNull);
  });
}
