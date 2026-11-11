import '../domain/entities/home_board.dart';
import '../domain/entities/street_ledger.dart';
import '../domain/rules/month_board.dart';

List<DayReceiptCustomer> dayReceiptsFromHome(HomeBoard board) {
  return [
    for (final item in board.receiptsDueToday)
      DayReceiptCustomer(
        customerId: item.customerId,
        customerName: item.customerName,
        amountCents: item.openCents,
        done: item.settled,
      ),
  ];
}

List<UpcomingDueCustomer> tomorrowDuesFromHome(HomeBoard board) {
  return [
    for (final item in board.duesTomorrow)
      UpcomingDueCustomer(
        customerId: item.customerId,
        customerName: item.customerName,
        dueOn: item.dueOn,
        amountCents: item.openCents,
      ),
  ];
}

List<UpcomingDueCustomer> laterDuesFromHome(HomeBoard board) {
  return [
    for (final item in board.upcomingDues)
      UpcomingDueCustomer(
        customerId: item.customerId,
        customerName: item.customerName,
        dueOn: item.dueOn,
        amountCents: item.openCents,
      ),
  ];
}

/// Prefer remote rows; fill gaps from local draft notes (same customer+day).
List<UpcomingDueCustomer> mergeUpcomingDues(
  List<UpcomingDueCustomer> remote,
  List<UpcomingDueCustomer> local,
) {
  final keys = {
    for (final due in remote) '${due.customerId}|${due.dueOn}',
  };
  return [
    ...remote,
    for (final due in local)
      if (!keys.contains('${due.customerId}|${due.dueOn}')) due,
  ];
}

UpcomingDueCustomer _dueFromHomeItem(HomeDueItem item) {
  return UpcomingDueCustomer(
    customerId: item.customerId,
    customerName: item.customerName,
    dueOn: item.dueOn,
    amountCents: item.openCents,
  );
}

/// Seed / orphan rows used the placeholder name "Cliente" or demo ids.
bool _isRealHomeDue(UpcomingDueCustomer due) {
  if (due.amountCents <= 0 || due.dueOn.trim().isEmpty) return false;
  if (due.customerId.startsWith('demo-')) return false;
  final name = due.customerName.trim();
  if (name.isEmpty || name == 'Cliente') return false;
  return true;
}

/// Rebuild hoje / amanhã / depois using the **device** calendar day.
///
/// Local draft notes win for that customer — stale API due dates must not
/// keep someone in "amanhã" after the user moved vencimento to today.
({
  List<DayReceiptCustomer> receipts,
  List<UpcomingDueCustomer> tomorrow,
  List<UpcomingDueCustomer> later,
})
homeSectionsForLocalDay({
  required HomeBoard board,
  required List<UpcomingDueCustomer> localNotes,
  required DateTime now,
  Set<String> clearedCustomerIds = const {},
}) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayIso = isoDate(todayStart);
  final tomorrowIso = isoDate(todayStart.add(const Duration(days: 1)));

  final localByCustomer = <String, UpcomingDueCustomer>{};
  for (final due in localNotes) {
    if (!_isRealHomeDue(due)) continue;
    localByCustomer[due.customerId] = due;
  }

  final byCustomer = <String, UpcomingDueCustomer>{};
  void putRemote(UpcomingDueCustomer due) {
    if (!_isRealHomeDue(due)) return;
    if (localByCustomer.containsKey(due.customerId)) return;
    // Local draft was emptied / due cleared — don't keep the stale API row.
    if (clearedCustomerIds.contains(due.customerId)) return;
    byCustomer.putIfAbsent(due.customerId, () => due);
  }

  for (final item in board.receiptsDueToday) {
    putRemote(_dueFromHomeItem(item));
  }
  for (final item in board.duesTomorrow) {
    putRemote(_dueFromHomeItem(item));
  }
  for (final item in board.upcomingDues) {
    putRemote(_dueFromHomeItem(item));
  }
  byCustomer.addAll(localByCustomer);

  final receipts = <DayReceiptCustomer>[];
  final tomorrow = <UpcomingDueCustomer>[];
  final later = <UpcomingDueCustomer>[];

  for (final due in byCustomer.values) {
    if (due.dueOn == todayIso) {
      receipts.add(
        DayReceiptCustomer(
          customerId: due.customerId,
          customerName: due.customerName,
          amountCents: due.amountCents,
          done: false,
        ),
      );
    } else if (due.dueOn == tomorrowIso) {
      tomorrow.add(due);
    } else if (due.dueOn.compareTo(tomorrowIso) > 0) {
      later.add(due);
    }
  }

  receipts.sort((a, b) => a.customerName.compareTo(b.customerName));
  tomorrow.sort((a, b) => a.customerName.compareTo(b.customerName));
  later.sort((a, b) {
    final byDate = a.dueOn.compareTo(b.dueOn);
    if (byDate != 0) return byDate;
    return a.customerName.compareTo(b.customerName);
  });

  return (receipts: receipts, tomorrow: tomorrow, later: later);
}
