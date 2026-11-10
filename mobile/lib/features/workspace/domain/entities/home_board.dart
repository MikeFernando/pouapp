import 'package:equatable/equatable.dart';

class HomeDueItem extends Equatable {
  const HomeDueItem({
    required this.customerId,
    required this.customerName,
    required this.openCents,
    required this.dueOn,
    this.openNotes = 0,
    this.settled = false,
  });

  final String customerId;
  final String customerName;
  final int openCents;
  final String dueOn;
  final int openNotes;
  final bool settled;

  @override
  List<Object?> get props => [
    customerId,
    customerName,
    openCents,
    dueOn,
    openNotes,
    settled,
  ];
}

class HomeBoard extends Equatable {
  const HomeBoard({
    required this.date,
    required this.receivedTodayCents,
    required this.receiptsDueToday,
    required this.duesTomorrow,
    required this.upcomingDues,
  });

  final String date;
  final int receivedTodayCents;
  final List<HomeDueItem> receiptsDueToday;
  final List<HomeDueItem> duesTomorrow;
  final List<HomeDueItem> upcomingDues;

  @override
  List<Object?> get props => [
    date,
    receivedTodayCents,
    receiptsDueToday,
    duesTomorrow,
    upcomingDues,
  ];
}
