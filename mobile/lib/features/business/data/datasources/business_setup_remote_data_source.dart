import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/business_setup.dart';
import '../models/business_setup_model.dart';

abstract class BusinessSetupRemoteDataSource {
  Future<BusinessSetup> fetch(String userId);

  Future<BusinessSetup> save({
    required String userId,
    required BusinessKind kind,
  });
}

class BusinessSetupRemoteDataSourceImpl
    implements BusinessSetupRemoteDataSource {
  BusinessSetupRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Dio get _dio => apiClient.dio;

  @override
  Future<BusinessSetup> fetch(String userId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/business/profile',
      );
      return _parse(userId, response.data);
    } on DioException catch (error) {
      mapDioException(error);
    }
  }

  @override
  Future<BusinessSetup> save({
    required String userId,
    required BusinessKind kind,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/business/setup',
        data: {'businessType': kind.name},
      );
      final setup = _parse(userId, response.data);
      if (!setup.isConfigured || setup.kind != kind) {
        throw ServerException('A configuração do negócio não foi confirmada.');
      }
      return setup;
    } on DioException catch (error) {
      mapDioException(error);
    }
  }

  BusinessSetup _parse(String userId, Map<String, dynamic>? body) {
    final profile = body?['profile'];
    if (profile is! Map) {
      throw ServerException('Perfil do negócio inválido.');
    }
    return BusinessSetupModel.fromJson(
      userId,
      Map<String, dynamic>.from(profile),
    );
  }
}
