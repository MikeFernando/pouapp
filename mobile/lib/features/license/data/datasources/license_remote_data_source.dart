import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/license_status.dart';

abstract class LicenseRemoteDataSource {
  Future<LicenseStatus> fetch();
}

class LicenseRemoteDataSourceImpl implements LicenseRemoteDataSource {
  LicenseRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<LicenseStatus> fetch() async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        '/license',
      );
      final body = response.data;
      final license = body?['license'];
      if (license is! Map) {
        throw ServerException('Resposta de licença inválida.');
      }
      final paidRaw = license['paidUntil'];
      return LicenseStatus(
        active: license['active'] == true,
        status: (license['status'] as String?) ?? 'unpaid',
        paidUntil: paidRaw is String ? DateTime.tryParse(paidRaw) : null,
        message: license['message'] as String?,
        reason: _parseReason(license['reason']),
        paidEmail: license['paidEmail'] as String?,
        checkedAt: DateTime.now().toUtc(),
      );
    } on DioException catch (error) {
      mapDioException(error);
    }
  }
}

LicenseBlockReason? _parseReason(Object? raw) {
  return switch (raw) {
    'wrong_email' => LicenseBlockReason.wrongEmail,
    'payment_required' => LicenseBlockReason.paymentRequired,
    _ => null,
  };
}
