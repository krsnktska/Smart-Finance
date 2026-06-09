import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/config/api_config.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
              sendTimeout: ApiConfig.sendTimeout,
              contentType: Headers.jsonContentType,
            ),
          ) {
    // Add interceptors
    _dio.interceptors.add(LoggingInterceptor());
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: headers != null ? Options(headers: headers) : null,
      );
      return _handleResponse(response, fromJson);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      if (data is FormData) {
        final prevContentType = _dio.options.contentType;
        _dio.options.contentType = null;
        try {
          final newHeaders = Map<String, dynamic>.from(_dio.options.headers);
          if (headers != null) {
            newHeaders.addAll(headers);
          }
          newHeaders.remove(Headers.contentTypeHeader);
          final response = await _dio.post(
            path,
            data: data,
            queryParameters: queryParameters,
            options: Options(headers: newHeaders),
          );
          return _handleResponse(response, fromJson);
        } finally {
          _dio.options.contentType = prevContentType;
        }
      }

      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: headers != null ? Options(headers: headers) : null,
      );
      return _handleResponse(response, fromJson);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, fromJson);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, fromJson);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, fromJson);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void removeAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  String? get authHeader => _dio.options.headers['Authorization'] as String?;

  T _handleResponse<T>(Response response, T Function(dynamic)? fromJson) {
    if (fromJson != null) {
      return fromJson(response.data);
    }
    return response.data as T;
  }

  Exception _handleError(DioException error) {
    final requestInfo =
        '${error.requestOptions.method} ${error.requestOptions.path}';
    if (error.response != null) {
      final statusCode = error.response?.statusCode ?? 0;
      final message = _extractMessage(error.response?.data, statusCode);
      return ApiException(
        message: '$requestInfo -> $message',
        statusCode: statusCode,
      );
    }
    return ApiException(
      message: '$requestInfo -> ${error.message ?? 'Network error'}',
    );
  }

  /// Extracts a human-readable message from various server error formats.
  /// Handles ASP.NET validation errors, plain messages, and empty bodies.
  static String _extractMessage(dynamic data, int statusCode) {
    if (data is! Map) {
      // Empty body or plain-text — use a generic status description.
      return _statusDescription(statusCode);
    }
    // Try plain message field first.
    if (data['message'] is String) return data['message'] as String;
    // ASP.NET validation error: extract first validation message.
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final firstField = errors.values.first;
      if (firstField is List && firstField.isNotEmpty) {
        return firstField.first.toString();
      }
    }
    // ASP.NET title (generic validation summary).
    if (data['title'] is String) return data['title'] as String;
    // Detail field (RFC 7807 / Problem Details).
    if (data['detail'] is String) return data['detail'] as String;
    return _statusDescription(statusCode);
  }

  static String _statusDescription(int code) {
    switch (code) {
      case 400: return 'Invalid request';
      case 401: return 'Unauthorized';
      case 403: return 'Access denied';
      case 404: return 'Not found';
      case 409: return 'Conflict';
      case 422: return 'Unprocessable content';
      case 500: return 'Server error';
      default:  return 'Request failed (HTTP $code)';
    }
  }
}

class ApiException implements Exception {
  final String message; // "POST /auth/login -> Invalid email or password."
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  /// Clean user-facing message — strips the "METHOD /path -> " prefix.
  String get userMessage {
    final idx = message.indexOf(' -> ');
    return idx >= 0 ? message.substring(idx + 4) : message;
  }

  /// Returns the user-readable message (used when exception is shown in UI).
  @override
  String toString() => userMessage;
}

class LoggingInterceptor extends QueuedInterceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('📤 REQUEST: ${options.method} ${options.path} ${options.uri}');
    }
    if (kDebugMode) {
      print('Headers: ${options.headers}');
    }
    if (options.data != null) {
      if (kDebugMode) {
        print('Data: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print(
        '📥 RESPONSE: ${response.statusCode} ${response.requestOptions.path}',
      );
    }
    if (kDebugMode) {
      print('Data: ${response.data}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print(
        '❌ ERROR: ${err.requestOptions.method} ${err.requestOptions.path} - ${err.message}',
      );
      print('Status: ${err.response?.statusCode}');
      print('Server Response Data: ${err.response?.data}');
    }
    handler.next(err);
  }
}

final apiClientProvider = Provider((ref) => ApiClient());
