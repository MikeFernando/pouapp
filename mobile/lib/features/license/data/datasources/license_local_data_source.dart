import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/license_status.dart';

abstract class LicenseLocalDataSource {
  Future<LicenseStatus?> read();

  Future<void> save(LicenseStatus status);

  Future<void> clear();
}

class LicenseLocalDataSourceImpl implements LicenseLocalDataSource {
  LicenseLocalDataSourceImpl({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  static const _activeKey = 'license.active';
  static const _statusKey = 'license.status';
  static const _paidUntilKey = 'license.paidUntil';
  static const _messageKey = 'license.message';
  static const _reasonKey = 'license.reason';
  static const _paidEmailKey = 'license.paidEmail';
  static const _checkedAtKey = 'license.checkedAt';

  @override
  Future<LicenseStatus?> read() async {
    final checkedRaw = sharedPreferences.getString(_checkedAtKey);
    if (checkedRaw == null) return null;
    final checkedAt = DateTime.tryParse(checkedRaw);
    if (checkedAt == null) return null;

    final paidRaw = sharedPreferences.getString(_paidUntilKey);
    final reasonRaw = sharedPreferences.getString(_reasonKey);
    return LicenseStatus(
      active: sharedPreferences.getBool(_activeKey) ?? false,
      status: sharedPreferences.getString(_statusKey) ?? 'unpaid',
      paidUntil: paidRaw == null ? null : DateTime.tryParse(paidRaw),
      message: sharedPreferences.getString(_messageKey),
      reason: switch (reasonRaw) {
        'wrong_email' => LicenseBlockReason.wrongEmail,
        'payment_required' => LicenseBlockReason.paymentRequired,
        _ => null,
      },
      paidEmail: sharedPreferences.getString(_paidEmailKey),
      checkedAt: checkedAt,
      fromCache: true,
    );
  }

  @override
  Future<void> save(LicenseStatus status) async {
    await sharedPreferences.setBool(_activeKey, status.active);
    await sharedPreferences.setString(_statusKey, status.status);
    if (status.paidUntil == null) {
      await sharedPreferences.remove(_paidUntilKey);
    } else {
      await sharedPreferences.setString(
        _paidUntilKey,
        status.paidUntil!.toIso8601String(),
      );
    }
    if (status.message == null) {
      await sharedPreferences.remove(_messageKey);
    } else {
      await sharedPreferences.setString(_messageKey, status.message!);
    }
    if (status.reason == null) {
      await sharedPreferences.remove(_reasonKey);
    } else {
      await sharedPreferences.setString(
        _reasonKey,
        switch (status.reason!) {
          LicenseBlockReason.wrongEmail => 'wrong_email',
          LicenseBlockReason.paymentRequired => 'payment_required',
        },
      );
    }
    if (status.paidEmail == null || status.paidEmail!.isEmpty) {
      await sharedPreferences.remove(_paidEmailKey);
    } else {
      await sharedPreferences.setString(_paidEmailKey, status.paidEmail!);
    }
    await sharedPreferences.setString(
      _checkedAtKey,
      status.checkedAt.toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await sharedPreferences.remove(_activeKey);
    await sharedPreferences.remove(_statusKey);
    await sharedPreferences.remove(_paidUntilKey);
    await sharedPreferences.remove(_messageKey);
    await sharedPreferences.remove(_reasonKey);
    await sharedPreferences.remove(_paidEmailKey);
    await sharedPreferences.remove(_checkedAtKey);
  }
}
