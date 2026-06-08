import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient._();

  static FutureOr<void> Function()? onUnauthorized;

  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: {'Accept': 'application/json'},
            validateStatus: (status) {
              return status != null && status < 500;
            },
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final requiresAuth = options.extra['requiresAuth'] != false;

              if (requiresAuth) {
                final token = await TokenStorage.getAccessToken();

                if (token != null && token.trim().isNotEmpty) {
                  options.headers['Authorization'] = 'Bearer $token';
                }
              }

              handler.next(options);
            },
          ),
        );

  static Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(extra: {'requiresAuth': requiresAuth}),
      );

      return _handleResponse(response, requiresAuth: requiresAuth);
    } on DioException catch (error) {
      throw _handleDioException(error, requiresAuth: requiresAuth);
    }
  }

  static Future<dynamic> postJson(
    String path, {
    Map<String, dynamic>? data,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'requiresAuth': requiresAuth},
        ),
      );

      return _handleResponse(response, requiresAuth: requiresAuth);
    } on DioException catch (error) {
      throw _handleDioException(error, requiresAuth: requiresAuth);
    }
  }

  static Future<dynamic> postForm(
    String path, {
    required Map<String, dynamic> data,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          extra: {'requiresAuth': requiresAuth},
        ),
      );

      return _handleResponse(response, requiresAuth: requiresAuth);
    } on DioException catch (error) {
      throw _handleDioException(error, requiresAuth: requiresAuth);
    }
  }

  static Future<dynamic> postMultipart(
    String path, {
    required FormData data,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(extra: {'requiresAuth': requiresAuth}),
      );

      return _handleResponse(response, requiresAuth: requiresAuth);
    } on DioException catch (error) {
      throw _handleDioException(error, requiresAuth: requiresAuth);
    }
  }

  static Future<dynamic> patchJson(
    String path, {
    Map<String, dynamic>? data,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'requiresAuth': requiresAuth},
        ),
      );

      return _handleResponse(response, requiresAuth: requiresAuth);
    } on DioException catch (error) {
      throw _handleDioException(error, requiresAuth: requiresAuth);
    }
  }

  static Future<dynamic> delete(String path, {bool requiresAuth = true}) async {
    try {
      final response = await _dio.delete(
        path,
        options: Options(extra: {'requiresAuth': requiresAuth}),
      );

      return _handleResponse(response, requiresAuth: requiresAuth);
    } on DioException catch (error) {
      throw _handleDioException(error, requiresAuth: requiresAuth);
    }
  }

  static dynamic _handleResponse(
    Response response, {
    required bool requiresAuth,
  }) {
    final statusCode = response.statusCode ?? 0;

    if (statusCode >= 200 && statusCode < 300) {
      return response.data;
    }

    final errorMessage = _extractErrorMessage(response.data);

    if (requiresAuth && _isSessionFailure(statusCode, errorMessage)) {
      _notifyUnauthorized();
    }

    throw ApiException(message: errorMessage, statusCode: statusCode);
  }

  static ApiException _handleDioException(
    DioException error, {
    required bool requiresAuth,
  }) {
    final response = error.response;

    if (response != null) {
      final statusCode = response.statusCode ?? 0;

      final errorMessage = _extractErrorMessage(response.data);

      if (requiresAuth && _isSessionFailure(statusCode, errorMessage)) {
        _notifyUnauthorized();
      }

      return ApiException(message: errorMessage, statusCode: statusCode);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'Connection timed out. Please try again.',
        );

      case DioExceptionType.connectionError:
        return const ApiException(message: 'Could not connect to the server.');

      case DioExceptionType.cancel:
        return const ApiException(message: 'Request was cancelled.');

      default:
        return const ApiException(
          message: 'Something went wrong. Please try again.',
        );
    }
  }

  static void _notifyUnauthorized() {
    unawaited(TokenStorage.clearAccessToken());

    final callback = onUnauthorized;

    if (callback != null) {
      unawaited(Future<void>.sync(callback));
    }
  }

  static bool _isSessionFailure(int statusCode, String message) {
    if (statusCode == 401) {
      return true;
    }

    if (statusCode != 403) {
      return false;
    }

    final normalized = message.trim().toLowerCase();

    return normalized == 'account is deactivated.' ||
        normalized == 'email is not verified.';
  }

  static String _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];

      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }

      if (detail is List && detail.isNotEmpty) {
        final firstError = detail.first;

        if (firstError is Map<String, dynamic>) {
          final message = firstError['msg'];

          if (message is String && message.trim().isNotEmpty) {
            return message;
          }
        }
      }

      final message = data['message'];

      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    return 'Something went wrong. Please try again.';
  }
}
