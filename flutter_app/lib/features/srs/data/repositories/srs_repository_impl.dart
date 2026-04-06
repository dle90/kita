import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/network/api_client.dart';
import 'package:kita_english/core/network/api_result.dart';
import 'package:kita_english/core/storage/secure_storage.dart';
import 'package:kita_english/features/srs/domain/entities/srs_card.dart';
import 'package:kita_english/features/srs/domain/repositories/srs_repository.dart';

/// Concrete implementation of [SrsRepository] using API calls.
/// Note: SRS endpoints are not yet available in the Go backend.
class SrsRepositoryImpl implements SrsRepository {
  final Dio _dio;
  final SecureStorageService _secureStorage;

  SrsRepositoryImpl(this._dio, this._secureStorage);

  @override
  Future<ApiResult<List<SrsCard>>> getDueCards() async {
    try {
      final kidId = await _secureStorage.readKidProfileId() ?? '';
      final response = await _dio.get('/kids/$kidId/srs/due');
      final data = response.data as List<dynamic>;
      final cards = data
          .map((json) => SrsCard.fromJson(json as Map<String, dynamic>))
          .toList();
      return ApiResult.success(cards);
    } on DioException catch (e) {
      return ApiResult.failure(
        e.message ?? 'Không thể tải thẻ ôn tập.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Lỗi: $e');
    }
  }

  @override
  Future<ApiResult<SrsCard>> reviewCard(String cardId, int quality) async {
    try {
      final kidId = await _secureStorage.readKidProfileId() ?? '';
      final response = await _dio.post(
        '/kids/$kidId/srs/review',
        data: {
          'card_id': cardId,
          'quality': quality,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return ApiResult.success(SrsCard.fromJson(data));
    } on DioException catch (e) {
      return ApiResult.failure(
        e.message ?? 'Không thể gửi kết quả ôn tập.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Lỗi: $e');
    }
  }
}

/// Riverpod provider for [SrsRepository].
final srsRepositoryProvider = Provider<SrsRepository>((ref) {
  final dio = ref.read(dioProvider);
  final secureStorage = ref.read(secureStorageProvider);
  return SrsRepositoryImpl(dio, secureStorage);
});
