import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/constants/api_endpoints.dart';
import 'package:kita_english/core/storage/secure_storage.dart';

/// Provides a configured [Dio] singleton with auth and error interceptors.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  final secureStorage = ref.read(secureStorageProvider);

  // Auth interceptor — reads JWT and adds Bearer header
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await secureStorage.readAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // If 401, try to refresh the token
        if (error.response?.statusCode == 401) {
          final refreshToken = await secureStorage.readRefreshToken();
          if (refreshToken != null && refreshToken.isNotEmpty) {
            try {
              final refreshDio = Dio(
                BaseOptions(baseUrl: ApiEndpoints.baseUrl),
              );
              final response = await refreshDio.post(
                ApiEndpoints.authRefresh,
                data: {'refresh_token': refreshToken},
              );

              final newAccessToken =
                  response.data['access_token'] as String? ?? '';
              final newRefreshToken =
                  response.data['refresh_token'] as String? ?? '';

              await secureStorage.writeAccessToken(newAccessToken);
              if (newRefreshToken.isNotEmpty) {
                await secureStorage.writeRefreshToken(newRefreshToken);
              }

              // Retry the original request with the new token
              error.requestOptions.headers['Authorization'] =
                  'Bearer $newAccessToken';
              final retryResponse = await dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            } catch (_) {
              // Refresh failed — clear tokens and propagate error
              await secureStorage.clearTokens();
              return handler.next(error);
            }
          }
        }
        return handler.next(error);
      },
    ),
  );

  // Error interceptor — transforms DioExceptions into user-friendly messages
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) {
        String message;
        switch (error.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            message = 'Kết nối quá chậm. Vui lòng thử lại.';
            break;
          case DioExceptionType.connectionError:
            message = 'Không có kết nối mạng. Kiểm tra WiFi nhé!';
            break;
          case DioExceptionType.badResponse:
            final statusCode = error.response?.statusCode ?? 0;
            final serverMessage =
                error.response?.data?['message'] as String?;
            if (statusCode >= 500) {
              message = 'Máy chủ đang bận. Thử lại sau nhé!';
            } else {
              message = serverMessage ?? 'Đã xảy ra lỗi ($statusCode).';
            }
            break;
          default:
            message = 'Đã xảy ra lỗi. Vui lòng thử lại.';
        }
        error = error.copyWith(message: message);
        return handler.next(error);
      },
    ),
  );

  return dio;
});

/// Convenience provider for API client that wraps Dio.
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return _dio.put<T>(path, data: data, options: options);
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return _dio.delete<T>(path, data: data, options: options);
  }

  Future<Response<T>> uploadFile<T>(
    String path, {
    required FormData formData,
    void Function(int, int)? onSendProgress,
  }) {
    return _dio.post<T>(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onSendProgress,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.read(dioProvider);
  return ApiClient(dio);
});
