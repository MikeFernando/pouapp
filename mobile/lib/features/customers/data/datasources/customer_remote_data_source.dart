import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/customer.dart';
import '../exceptions/customer_exceptions.dart';
import '../models/customer_model.dart';

abstract class CustomerRemoteDataSource {
  Future<List<Customer>> listCustomers({
    String search = '',
    CustomerStatus? status,
  });

  Future<Customer> getCustomerById(String id);

  Future<Customer> createCustomer(CustomerInput input);

  Future<Customer> changeStatus({
    required String id,
    required CustomerStatus status,
  });
}

class CustomerRemoteDataSourceImpl implements CustomerRemoteDataSource {
  CustomerRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Dio get _dio => apiClient.dio;

  @override
  Future<List<Customer>> listCustomers({
    String search = '',
    CustomerStatus? status,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/customers',
        queryParameters: {
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (status != null) 'status': status.name,
        },
      );
      final items = response.data?['items'];
      if (items is! List) throw ServerException('Lista de clientes inválida.');
      return items
          .whereType<Map>()
          .map((item) => CustomerModel.fromApi(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (error) {
      mapDioException(error);
    }
  }

  @override
  Future<Customer> getCustomerById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/customers/$id');
      final customer = response.data?['customer'];
      if (customer is! Map) throw CustomerNotFoundException();
      return CustomerModel.fromApi(Map<String, dynamic>.from(customer));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw CustomerNotFoundException();
      }
      mapDioException(error);
    }
  }

  @override
  Future<Customer> createCustomer(CustomerInput input) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/customers',
        data: {
          'name': input.name.trim(),
          if ((input.phone ?? input.mobilePhone)?.trim().isNotEmpty == true)
            'phone': (input.phone ?? input.mobilePhone)!.trim(),
          'type': input.type.name,
          'status': input.status.name,
        },
      );
      final customer = response.data?['customer'];
      if (customer is! Map) {
        throw ServerException('Resposta de cliente inválida.');
      }
      return CustomerModel.fromApi(Map<String, dynamic>.from(customer));
    } on DioException catch (error) {
      mapDioException(error);
    }
  }

  @override
  Future<Customer> changeStatus({
    required String id,
    required CustomerStatus status,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/customers/$id/status',
        data: {'status': status.name},
      );
      final customer = response.data?['customer'];
      if (customer is! Map) throw CustomerNotFoundException();
      return CustomerModel.fromApi(Map<String, dynamic>.from(customer));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw CustomerNotFoundException();
      }
      mapDioException(error);
    }
  }
}
