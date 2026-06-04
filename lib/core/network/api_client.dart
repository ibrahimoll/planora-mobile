import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient._();

  static const Duration _defaultTimeout = Duration(seconds: 75);

  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: _defaultTimeout,
            receiveTimeout: _defaultTimeout,
            sendTimeout: _defaultTimeout,
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

      return _handleResponse(response);
    } on DioException catch (error) {
      throw _handleDioException(error);
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

      return _handleResponse(response);
    } on DioException catch (error) {
      throw _handleDioException(error);
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

      return _handleResponse(response);
    } on DioException catch (error) {
      throw _handleDioException(error);
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

      return _handleResponse(response);
    } on DioException catch (error) {
      throw _handleDioException(error);
    }
  }

  static Future<dynamic> delete(String path, {bool requiresAuth = true}) async {
    try {
      final response = await _dio.delete(
        path,
        options: Options(extra: {'requiresAuth': requiresAuth}),
      );

      return _handleResponse(response);
    } on DioException catch (error) {
      throw _handleDioException(error);
    }
  }

  static dynamic _handleResponse(Response response) {
    final statusCode = response.statusCode ?? 0;

    if (statusCode >= 200 && statusCode < 300) {
      return response.data;
    }

    throw ApiException(
      message: _extractErrorMessage(response.data),
      statusCode: statusCode,
    );
  }

  static ApiException _handleDioException(DioException error) {
    final response = error.response;

    if (response != null) {
      return ApiException(
        message: _extractErrorMessage(response.data),
        statusCode: response.statusCode,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message:
              'The Planora server is still starting. Please try again in a moment.',
        );

      case DioExceptionType.connectionError:
        return const ApiException(
          message:
              'Could not reach the Planora server. Check your connection and try again.',
        );

      case DioExceptionType.cancel:
        return const ApiException(message: 'Request was cancelled.');

      default:
        return const ApiException(
          message: 'Something went wrong. Please try again.',
        );
    }
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
