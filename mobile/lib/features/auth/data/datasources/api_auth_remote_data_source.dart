import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/auth_token_store.dart';
import '../exceptions/auth_exceptions.dart';
import '../models/user_model.dart';
import 'auth_remote_data_source.dart';

class ApiAuthRemoteDataSource implements AuthRemoteDataSource {
  ApiAuthRemoteDataSource({
    required this.apiClient,
    required this.tokenStore,
  });

  final ApiClient apiClient;
  final AuthTokenStore tokenStore;

  Dio get _dio => apiClient.dio;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
        options: Options(extra: const {'skipAuth': true}),
      );
      return await _persistSession(response.data);
    } on DioException catch (error) {
      _mapAuthError(error);
    }
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
        options: Options(extra: const {'skipAuth': true}),
      );
      return await _persistSession(response.data);
    } on DioException catch (error) {
      _mapAuthError(error);
    }
  }

  @override
  Future<void> logout() async {
    final refresh = await tokenStore.readRefreshToken();
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _dio.post<Map<String, dynamic>>(
          '/auth/logout',
          data: {'refreshToken': refresh},
          options: Options(extra: const {'skipAuth': true}),
        );
      }
    } on DioException {
      // Local clear still happens in the repository.
    } finally {
      await tokenStore.clear();
    }
  }

  @override
  Future<UserModel> currentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final user = response.data?['user'];
      if (user is! Map) throw ServerException('Sessão inválida.');
      return UserModel.fromJson(Map<String, dynamic>.from(user));
    } on DioException catch (error) {
      mapDioException(error);
    }
  }

  Future<UserModel> _persistSession(Map<String, dynamic>? data) async {
    if (data == null) throw ServerException('Resposta vazia.');
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final user = data['user'];
    if (accessToken == null ||
        refreshToken == null ||
        user is! Map<String, dynamic>) {
      throw ServerException('Resposta de autenticação inválida.');
    }
    await tokenStore.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    return UserModel.fromJson(Map<String, dynamic>.from(user));
  }

  Never _mapAuthError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401) throw InvalidCredentialsException();
    if (status == 409) throw EmailAlreadyRegisteredException();
    mapDioException(error);
  }
}
