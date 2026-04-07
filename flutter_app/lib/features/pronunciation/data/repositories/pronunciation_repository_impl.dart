import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/constants/api_endpoints.dart';
import 'package:kita_english/core/network/api_client.dart';
import 'package:kita_english/core/network/api_result.dart';
import 'package:kita_english/core/storage/secure_storage.dart';
import 'package:kita_english/features/pronunciation/data/models/pronunciation_score_model.dart';
import 'package:kita_english/features/pronunciation/domain/entities/pronunciation_score.dart';
import 'package:kita_english/features/pronunciation/domain/repositories/pronunciation_repository.dart';

/// Concrete implementation of [PronunciationRepository].
/// Uploads the WAV audio as multipart form data with the reference text.
class PronunciationRepositoryImpl implements PronunciationRepository {
  final Dio _dio;
  final SecureStorageService _secureStorage;

  PronunciationRepositoryImpl(this._dio, this._secureStorage);

  @override
  Future<ApiResult<PronunciationScore>> scorePronunciation({
    required String audioPath,
    required String referenceText,
  }) async {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        return const ApiResult.failure('File ghi âm không tìm thấy.');
      }

      final kidId = await _secureStorage.readKidProfileId() ?? '';

      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: 'recording.wav',
          contentType: DioMediaType('audio', 'wav'),
        ),
        'reference_text': referenceText,
        'kid_id': kidId,
      });

      final response = await _dio.post(
        ApiEndpoints.pronunciationScore,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final model = PronunciationScoreModel.fromJson(data);
      return ApiResult.success(model.toEntity());
    } on DioException catch (e) {
      final message =
          e.message ?? 'Không thể đánh giá phát âm. Thử lại nhé!';
      return ApiResult.failure(message, statusCode: e.response?.statusCode);
    } catch (e) {
      return ApiResult.failure('Lỗi đánh giá phát âm: $e');
    }
  }

  @override
  Future<ApiResult<PronunciationScore>> scorePronunciationBytes({
    required Uint8List audioBytes,
    required String referenceText,
    String contentType = 'audio/webm',
  }) async {
    try {
      final kidId = await _secureStorage.readKidProfileId() ?? '';

      final mimeMain = contentType.split('/').first;
      final mimeSub = contentType.split('/').last.split(';').first;
      final ext = mimeSub == 'webm' ? 'webm' : 'wav';

      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(
          audioBytes,
          filename: 'recording.$ext',
          contentType: DioMediaType(mimeMain, mimeSub),
        ),
        'reference_text': referenceText,
        'kid_id': kidId,
      });

      final response = await _dio.post(
        ApiEndpoints.pronunciationScore,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final model = PronunciationScoreModel.fromJson(data);
      return ApiResult.success(model.toEntity());
    } on DioException catch (e) {
      final message =
          e.message ?? 'Không thể đánh giá phát âm. Thử lại nhé!';
      return ApiResult.failure(message, statusCode: e.response?.statusCode);
    } catch (e) {
      return ApiResult.failure('Lỗi đánh giá phát âm: $e');
    }
  }
}

/// Riverpod provider for [PronunciationRepository].
final pronunciationRepositoryProvider =
    Provider<PronunciationRepository>((ref) {
  final dio = ref.read(dioProvider);
  final secureStorage = ref.read(secureStorageProvider);
  return PronunciationRepositoryImpl(dio, secureStorage);
});
