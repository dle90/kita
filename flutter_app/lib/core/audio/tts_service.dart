import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Simple text-to-speech service for reading English words aloud.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    try {
      if (kIsWeb) {
        await _tts.awaitSpeakCompletion(true);
      }
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.4);
      await _tts.setPitch(1.1);
      await _tts.setVolume(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  Future<void> speak(String text) async {
    try {
      await _init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

final ttsProvider = Provider<TtsService>((ref) => TtsService());
