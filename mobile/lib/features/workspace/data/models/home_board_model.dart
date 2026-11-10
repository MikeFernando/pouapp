import '../../domain/entities/home_board.dart';

class HomeDueItemModel extends HomeDueItem {
  const HomeDueItemModel({
    required super.customerId,
    required super.customerName,
    required super.openCents,
    required super.dueOn,
    super.openNotes,
    super.settled,
  });

  factory HomeDueItemModel.fromJson(Map<String, dynamic> json) {
    return HomeDueItemModel(
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String? ?? 'Cliente',
      openCents: (json['openCents'] as num?)?.toInt() ?? 0,
      dueOn: json['dueOn'] as String,
      openNotes: (json['openNotes'] as num?)?.toInt() ?? 0,
      settled: json['settled'] as bool? ?? false,
    );
  }
}

class HomeBoardModel extends HomeBoard {
  const HomeBoardModel({
    required super.date,
    required super.receivedTodayCents,
    required super.receiptsDueToday,
    required super.duesTomorrow,
    required super.upcomingDues,
  });

  factory HomeBoardModel.fromJson(Map<String, dynamic> json) {
    List<HomeDueItem> parseList(Object? raw) {
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            HomeDueItemModel.fromJson(Map<String, dynamic>.from(item)),
      ];
    }

    return HomeBoardModel(
      date: json['date'] as String,
      receivedTodayCents: (json['receivedTodayCents'] as num?)?.toInt() ?? 0,
      receiptsDueToday: parseList(json['receiptsDueToday']),
      duesTomorrow: parseList(json['duesTomorrow']),
      upcomingDues: parseList(json['upcomingDues']),
    );
  }
}
