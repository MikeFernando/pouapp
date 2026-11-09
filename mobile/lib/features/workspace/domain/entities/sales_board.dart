import 'package:equatable/equatable.dart';

enum DeliveryStatus { pending, onTheWay, atCustomer }

enum PaymentStatus { pending, received }

class SalesSummary extends Equatable {
  const SalesSummary({
    required this.soldCents,
    required this.receivedCents,
    required this.pendingDeliveries,
    this.receivableCents,
    this.payableCents,
  });

  /// Recorded street sales, excluding demonstration orders.
  final int soldCents;

  /// Recorded street payments, excluding demonstration payments.
  /// A payment is not itself a sale.
  final int receivedCents;

  /// Open receivables. Null when that query is not available.
  final int? receivableCents;

  /// Supplier bills. Null until payables exist as their own records.
  final int? payableCents;

  final int pendingDeliveries;

  SalesSummary copyWith({
    int? soldCents,
    int? receivedCents,
    int? receivableCents,
    int? payableCents,
    int? pendingDeliveries,
    bool clearReceivable = false,
    bool clearPayable = false,
  }) {
    return SalesSummary(
      soldCents: soldCents ?? this.soldCents,
      receivedCents: receivedCents ?? this.receivedCents,
      receivableCents: clearReceivable
          ? null
          : receivableCents ?? this.receivableCents,
      payableCents: clearPayable ? null : payableCents ?? this.payableCents,
      pendingDeliveries: pendingDeliveries ?? this.pendingDeliveries,
    );
  }

  @override
  List<Object?> get props => [
    soldCents,
    receivedCents,
    receivableCents,
    payableCents,
    pendingDeliveries,
  ];
}

class DeliveryStop extends Equatable {
  const DeliveryStop({
    required this.id,
    required this.customerName,
    required this.address,
    required this.amountCents,
    required this.status,
  });

  final String id;
  final String customerName;
  final String address;
  final int amountCents;
  final DeliveryStatus status;

  @override
  List<Object?> get props => [id, customerName, address, amountCents, status];
}

class RecentSale extends Equatable {
  const RecentSale({
    required this.id,
    required this.code,
    required this.customerName,
    required this.amountCents,
    required this.paymentStatus,
    this.occurredOn,
  });

  final String id;
  final String code;
  final String customerName;
  final int amountCents;
  final PaymentStatus paymentStatus;

  /// Null when the sale has no recorded day. Do not substitute another date.
  final String? occurredOn;

  @override
  List<Object?> get props => [
    id,
    code,
    customerName,
    amountCents,
    paymentStatus,
    occurredOn,
  ];
}

class TeamPending extends Equatable {
  const TeamPending({
    required this.id,
    required this.personName,
    required this.task,
  });

  final String id;
  final String personName;
  final String task;

  @override
  List<Object?> get props => [id, personName, task];
}
