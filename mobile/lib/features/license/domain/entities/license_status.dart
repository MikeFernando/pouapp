import 'package:equatable/equatable.dart';

enum LicenseBlockReason { paymentRequired, wrongEmail }

class LicenseStatus extends Equatable {
  const LicenseStatus({
    required this.active,
    required this.status,
    required this.paidUntil,
    required this.message,
    required this.checkedAt,
    this.reason,
    this.paidEmail,
    this.fromCache = false,
  });

  final bool active;
  final String status;
  final DateTime? paidUntil;
  final String? message;
  final DateTime checkedAt;
  final LicenseBlockReason? reason;
  final String? paidEmail;
  final bool fromCache;

  LicenseStatus copyWith({
    bool? active,
    String? status,
    DateTime? paidUntil,
    String? message,
    DateTime? checkedAt,
    LicenseBlockReason? reason,
    String? paidEmail,
    bool? fromCache,
  }) {
    return LicenseStatus(
      active: active ?? this.active,
      status: status ?? this.status,
      paidUntil: paidUntil ?? this.paidUntil,
      message: message ?? this.message,
      checkedAt: checkedAt ?? this.checkedAt,
      reason: reason ?? this.reason,
      paidEmail: paidEmail ?? this.paidEmail,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  @override
  List<Object?> get props => [
    active,
    status,
    paidUntil,
    message,
    checkedAt,
    reason,
    paidEmail,
    fromCache,
  ];
}
