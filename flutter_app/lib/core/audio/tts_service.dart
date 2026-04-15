import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kita_english/core/constants/api_endpoints.dart';

/// Text-to-speech service.
///
/// Streams pre-generated mp3 audio from the backend TTS endpoint
/// (`GET /api/v1/tts?text=...`) which proxies ElevenLabs and caches in R2.
/// On web, just_audio uses the HTML5 audio element so the browser caches the
/// mp3 by URL automatically (the endpoint sends Cache-Control: immutable).
class TtsService {
  final AudioPlayer _player = AudioPlayer();

  static String _urlFor(String text) {
    final encoded = Uri.encodeQueryComponent(text);
    return '${ApiEndpoints.baseUrl}/tts?text=$encoded';
  }

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await _player.stop();
      await _player.setUrl(_urlFor(trimmed));
      await _player.play();
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}

final ttsProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(() => service.dispose());
  return service;
});
