import 'dart:async';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../error/exceptions.dart';
import 'auth_token_store.dart';

typedef OnSessionExpired = void Function();

/// Shared Dio client with Bearer access tokens and one-shot refresh.
class ApiClient {
  ApiClient({
    required AuthTokenStore tokenStore,
    Dio? dio,
    this.onSessionExpired,
    String? baseUrl,
  }) : tokenStore = tokenStore,
       dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? ApiConfig.baseUrl,
               // Fail fast offline — neighborhoods without signal must not hang.
               connectTimeout: const Duration(seconds: 5),
               receiveTimeout: const Duration(seconds: 8),
               headers: const {
                 'content-type': 'application/json',
                 'accept': 'application/json',
               },
             ),
           ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] == true) {
            handler.next(options);
            return;
          }
          final access = await tokenStore.readAccessToken();
          if (access != null && access.isNotEmpty) {
            options.headers['authorization'] = 'Bearer $access';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final response = error.response;
          final request = error.requestOptions;
          final alreadyRetried = request.extra['retried'] == true;
          final skipAuth = request.extra['skipAuth'] == true;

          if (response?.statusCode != 401 || alreadyRetried || skipAuth) {
            handler.next(error);
            return;
          }

          try {
            final refreshed = await _refreshTokens();
            if (!refreshed) {
              onSessionExpired?.call();
              handler.next(error);
              return;
            }
            final access = await tokenStore.readAccessToken();
            final opts = request.copyWith(
              headers: Map<String, dynamic>.from(request.headers)
                ..['authorization'] = 'Bearer $access',
              extra: Map<String, dynamic>.from(request.extra)
                ..['retried'] = true,
            );
            final clone = await this.dio.fetch<dynamic>(opts);
            handler.resolve(clone);
          } catch (_) {
            onSessionExpired?.call();
            handler.next(error);
          }
        },
      ),
    );
  }

  final Dio dio;
  final AuthTokenStore tokenStore;
  final OnSessionExpired? onSessionExpired;

  Future<bool>? _refreshInFlight;

  Future<bool> _refreshTokens() {
    return _refreshInFlight ??= () async {
      try {
        final refresh = await tokenStore.readRefreshToken();
        if (refresh == null || refresh.isEmpty) return false;

        final response = await dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refresh},
          options: Options(extra: const {'skipAuth': true}),
        );
        final data = response.data;
        final accessToken = data?['accessToken'] as String?;
        final refreshToken = data?['refreshToken'] as String?;
        if (accessToken == null || refreshToken == null) return false;
        await tokenStore.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        return true;
      } on DioException {
        await tokenStore.clear();
        return false;
      } finally {
        _refreshInFlight = null;
      }
    }();
  }
}

Never mapDioException(DioException error) {
  if (_isConnectivityFailure(error)) {
    throw const NetworkException();
  }

  final status = error.response?.statusCode;
  final body = error.response?.data;
  String? message;
  if (body is Map && body['error'] is String) {
    message = body['error'] as String;
  }

  if (status == 401) {
    throw UnauthorizedException(message);
  }
  if (status == 409) {
    throw ConflictException(message);
  }
  if (status == 400) {
    throw BadRequestException(message);
  }
  if (status == 404) {
    throw NotFoundException(message);
  }
  throw ServerException(message);
}

bool _isConnectivityFailure(DioException error) {
  return error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError ||
      (error.type == DioExceptionType.unknown && error.response == null);
}

class NetworkException implements Exception {
  const NetworkException();
}

class UnauthorizedException implements Exception {
  UnauthorizedException([this.message]);
  final String? message;
}

class ConflictException implements Exception {
  ConflictException([this.message]);
  final String? message;
}

class BadRequestException implements Exception {
  BadRequestException([this.message]);
  final String? message;
}

class NotFoundException implements Exception {
  NotFoundException([this.message]);
  final String? message;
}
