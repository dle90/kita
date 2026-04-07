import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/constants/api_endpoints.dart';
import 'package:kita_english/core/network/api_client.dart';
import 'package:kita_english/core/network/api_result.dart';
import 'package:kita_english/core/storage/secure_storage.dart';
import 'package:kita_english/features/session/data/models/session_model.dart';
import 'package:kita_english/features/session/domain/entities/activity_result.dart';
import 'package:kita_english/features/session/domain/entities/session.dart';
import 'package:kita_english/features/session/domain/repositories/session_repository.dart';

/// Concrete implementation of [SessionRepository] using Dio + local cache.
class SessionRepositoryImpl implements SessionRepository {
  final Dio _dio;
  final SecureStorageService _secureStorage;

  // In-memory cache of sessions
  final Map<int, Session> _sessionCache = {};

  SessionRepositoryImpl(this._dio, this._secureStorage);

  Future<String> _getKidId() async {
    final kidId = await _secureStorage.readKidProfileId();
    if (kidId == null || kidId.isEmpty) {
      throw Exception('Kid profile ID not found');
    }
    return kidId;
  }

  @override
  Future<ApiResult<List<Session>>> getSessions() async {
    try {
      final kidId = await _getKidId();
      final response = await _dio.get(ApiEndpoints.sessions(kidId));
      final sessionsJson = response.data as List<dynamic>;

      final sessions = sessionsJson.map((json) {
        final model = SessionModel.fromJson(json as Map<String, dynamic>);
        final entity = model.toEntity();
        _sessionCache[entity.dayNumber] = entity;
        return entity;
      }).toList();

      return ApiResult.success(sessions);
    } on DioException catch (e) {
      return ApiResult.failure(
        e.message ?? 'Không thể tải danh sách bài học.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Lỗi: $e');
    }
  }

  @override
  Future<ApiResult<Session>> getSession(int dayNumber) async {
    try {
      final kidId = await _getKidId();
      final response = await _dio.get(ApiEndpoints.session(kidId, dayNumber));
      final model =
          SessionModel.fromJson(response.data as Map<String, dynamic>);
      final session = model.toEntity();
      _sessionCache[session.dayNumber] = session;
      return ApiResult.success(session);
    } on DioException catch (e) {
      return ApiResult.failure(
        e.message ?? 'Không tìm thấy bài học ngày $dayNumber.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Lỗi: $e');
    }
  }

  @override
  Future<ApiResult<Session>> startSession(int dayNumber) async {
    try {
      final kidId = await _getKidId();
      await _dio.post(ApiEndpoints.sessionStart(kidId, dayNumber));
      // Return cached session (start endpoint returns session without activities)
      final cached = _sessionCache[dayNumber];
      if (cached != null) return ApiResult.success(cached);
      // Fallback: fetch full session
      return getSession(dayNumber);
    } on DioException catch (e) {
      return ApiResult.failure(
        e.message ?? 'Không thể bắt đầu bài học.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Lỗi: $e');
    }
  }

  @override
  Future<ApiResult<Session>> completeSession(
    int dayNumber, {
    required int totalStars,
    required double accuracyPct,
    required List<ActivityResult> results,
  }) async {
    try {
      final kidId = await _getKidId();
      final response = await _dio.post(
        ApiEndpoints.sessionComplete(kidId, dayNumber),
        data: {
          'total_stars': totalStars,
          'accuracy_pct': accuracyPct,
          'results': results.map((r) => r.toJson()).toList(),
        },
      );
      final model =
          SessionModel.fromJson(response.data as Map<String, dynamic>);
      final session = model.toEntity();
      _sessionCache[session.dayNumber] = session;
      return ApiResult.success(session);
    } on DioException catch (e) {
      return ApiResult.failure(
        e.message ?? 'Không thể hoàn thành bài học.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Lỗi: $e');
    }
  }

  @override
  Future<ApiResult<void>> submitActivityResult(ActivityResult result) async {
    try {
      final kidId = await _getKidId();
      await _dio.post(
        ApiEndpoints.activityResult(kidId, result.activityId),
        data: result.toJson(),
      );
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(
        e.message ?? 'Không thể gửi kết quả.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Lỗi: $e');
    }
  }

  /// Clears the local session cache.
  void clearCache() {
    _sessionCache.clear();
  }
}

/// Riverpod provider for [SessionRepository].
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final dio = ref.read(dioProvider);
  final secureStorage = ref.read(secureStorageProvider);
  return SessionRepositoryImpl(dio, secureStorage);
});
