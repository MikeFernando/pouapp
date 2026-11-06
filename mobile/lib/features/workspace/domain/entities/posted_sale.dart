import 'package:equatable/equatable.dart';

/// A confirmed amount the company can place on a calendar day.
///
/// [allocatedCents] is only money explicitly applied to this sale. Credit
/// that was not applied stays out of this number.
class PostedSale extends Equatable {
  const PostedSale({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.totalCents,
    required this.allocatedCents,
    required this.occurredOn,
    this.dueOn,
    this.sale = true,
  });

  final String id;
  final String customerId;
  final String customerName;
  final int totalCents;
  final int allocatedCents;

  /// Calendar day the sale happened, `yyyy-MM-dd`.
  final String occurredOn;

  /// Calendar day the open balance is due, when the sale has one.
  final String? dueOn;

  /// A confirmed sale. An opening balance is not a sale.
  final bool sale;

  int get openCents {
    final applied = allocatedCents < 0 ? 0 : allocatedCents;
    final open = totalCents - applied;
    return open < 0 ? 0 : open;
  }

  @override
  List<Object?> get props => [
    id,
    customerId,
    customerName,
    totalCents,
    allocatedCents,
    occurredOn,
    dueOn,
    sale,
  ];
}
