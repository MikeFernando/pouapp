import 'package:equatable/equatable.dart';

import 'street_ledger.dart';

enum PixKeyType { cpfCnpj, phone, email, random }

enum ChargeStatus { prepared, whatsappOpened }

class Receivable extends Equatable {
  const Receivable({
    required this.id,
    required this.customerId,
    required this.description,
    required this.amountCents,
    required this.openCents,
    required this.occurredOn,
    this.dueOn,
  });

  final String id;
  final String customerId;
  final String description;
  final int amountCents;
  final int openCents;
  final String occurredOn;
  final String? dueOn;

  @override
  List<Object?> get props => [
    id,
    customerId,
    description,
    amountCents,
    openCents,
    occurredOn,
    dueOn,
  ];
}

class AccountReceipt extends Equatable {
  const AccountReceipt({
    required this.id,
    required this.customerId,
    required this.amountCents,
    required this.creditCents,
    required this.paidOn,
    required this.method,
    required this.reversed,
    this.tenderedCents,
    this.changeCents,
    this.note,
    this.appliedCreditCents = 0,
    this.alreadyRecorded = false,
  });

  final String id;
  final String customerId;
  final int amountCents;
  final int creditCents;
  final String paidOn;
  final PaymentMethod method;
  final bool reversed;
  final int? tenderedCents;
  final int? changeCents;
  final String? note;

  /// Part of [creditCents] already used on a debt, by an explicit choice.
  final int appliedCreditCents;
  final bool alreadyRecorded;

  @override
  List<Object?> get props => [
    id,
    customerId,
    amountCents,
    creditCents,
    paidOn,
    method,
    reversed,
    tenderedCents,
    changeCents,
    note,
    appliedCreditCents,
    alreadyRecorded,
  ];
}

class AccountReversal extends Equatable {
  const AccountReversal({
    required this.id,
    required this.receiptId,
    required this.method,
    required this.amountCents,
    this.reason,
    this.alreadyRecorded = false,
  });

  final String id;
  final String receiptId;
  final PaymentMethod method;
  final int amountCents;
  final String? reason;
  final bool alreadyRecorded;

  @override
  List<Object?> get props => [
    id,
    receiptId,
    method,
    amountCents,
    reason,
    alreadyRecorded,
  ];
}

class ChargePreparation extends Equatable {
  const ChargePreparation({
    required this.id,
    required this.customerId,
    required this.amountCents,
    required this.description,
    required this.message,
    required this.status,
    this.phone,
  });

  final String id;
  final String customerId;
  final int amountCents;
  final String description;
  final String message;
  final ChargeStatus status;
  final String? phone;

  @override
  List<Object?> get props => [
    id,
    customerId,
    amountCents,
    description,
    message,
    status,
    phone,
  ];
}

class BusinessProfile extends Equatable {
  const BusinessProfile({this.pixKeyType, this.pixKey, this.receiverName});

  final PixKeyType? pixKeyType;
  final String? pixKey;
  final String? receiverName;

  bool get hasPixKey =>
      pixKeyType != null &&
      (pixKey ?? '').trim().isNotEmpty &&
      (receiverName ?? '').trim().isNotEmpty;

  @override
  List<Object?> get props => [pixKeyType, pixKey, receiverName];
}

class CustomerAccount extends Equatable {
  const CustomerAccount({
    required this.customerId,
    required this.receivables,
    required this.receipts,
    required this.charges,
  });

  final String customerId;
  final List<Receivable> receivables;
  final List<AccountReceipt> receipts;
  final List<ChargePreparation> charges;

  int get openCents =>
      receivables.fold<int>(0, (sum, item) => sum + item.openCents);

  int get creditCents => receipts
      .where((receipt) => !receipt.reversed)
      .fold<int>(
        0,
        (sum, receipt) =>
            sum + receipt.creditCents - receipt.appliedCreditCents,
      );

  /// Open debt stays open while credit has not been applied. Credit alone
  /// is a negative balance.
  int get balanceCents => openCents == 0 ? -creditCents : openCents;

  List<Receivable> get openReceivables => [
    for (final item in receivables)
      if (item.openCents > 0) item,
  ];

  @override
  List<Object?> get props => [customerId, receivables, receipts, charges];
}

class ReceiptPlan extends Equatable {
  const ReceiptPlan({
    required this.allocations,
    required this.allocatedCents,
    required this.creditCents,
    this.changeCents,
    this.error,
  });

  final List<PaymentShare> allocations;
  final int allocatedCents;
  final int creditCents;
  final int? changeCents;
  final String? error;

  @override
  List<Object?> get props => [
    allocations,
    allocatedCents,
    creditCents,
    changeCents,
    error,
  ];
}
