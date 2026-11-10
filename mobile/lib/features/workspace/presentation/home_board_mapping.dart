import '../domain/entities/home_board.dart';
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
