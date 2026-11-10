import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/home_board.dart';
import '../models/home_board_model.dart';

abstract class HomeRemoteDataSource {
  Future<HomeBoard> getHome({String? date});

  Future<void> createNote({
    required String customerId,
    required String dueOn,
    required int totalCents,
  });

  Future<void> createSale({
    required String customerId,
    required String occurredOn,
    required String dueOn,
    required int totalCents,
  });
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  HomeRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Dio get _dio => apiClient.dio;

  @override
  Future<HomeBoard> getHome({String? date}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/workspace/home',
        queryParameters: {if (date != null && date.isNotEmpty) 'date': date},
      );
      final home = response.data?['home'];
      if (home is! Map) throw ServerException('Home inválida.');
      return HomeBoardModel.fromJson(Map<String, dynamic>.from(home));
    } on DioException catch (error) {
      mapDioException(error);
    }
  }

  @override
  Future<void> createNote({
    required String customerId,
    required String dueOn,
    required int totalCents,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/notes',
        data: {
          'customerId': customerId,
          'dueOn': dueOn,
          'totalCents': totalCents,
          'status': 'draft',
        },
      );
    } on DioException catch (error) {
      mapDioException(error);
    }
  }

  @override
  Future<void> createSale({
    required String customerId,
    required String occurredOn,
    required String dueOn,
    required int totalCents,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/sales',
        data: {
          'customerId': customerId,
          'occurredOn': occurredOn,
          'dueOn': dueOn,
          'totalCents': totalCents,
        },
      );
    } on DioException catch (error) {
      mapDioException(error);
    }
  }
}
