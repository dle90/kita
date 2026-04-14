import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/tts_js.dart'
    if (dart.library.io) 'package:kita_english/core/audio/tts_stub.dart';
import 'package:kita_english/core/constants/api_endpoints.dart';

/// TTS service: on web uses backend ElevenLabs /api/v1/tts endpoint (Matilda voice).
/// Falls back to no-op if backend unavailable.
class TtsService {
  /// Backend root derived once from the known API base URL.
  static final String? _backendRoot = kIsWeb
      ? ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '')
      : null;

  Future<void> speak(String text) async {
    if (!kIsWeb || _backendRoot == null) return;
    try {
      final url = '$_backendRoot/api/v1/tts?text=${Uri.encodeComponent(text)}';
      await playAudioUrl(url);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> stop() async {}
}

final ttsProvider = Provider<TtsService>((ref) => TtsService());
