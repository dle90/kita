import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Simple text-to-speech service for reading English words aloud.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4); // Slow for kids
    await _tts.setPitch(1.1); // Slightly higher pitch
    await _tts.setVolume(1.0);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    await _init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}

final ttsProvider = Provider<TtsService>((ref) => TtsService());
