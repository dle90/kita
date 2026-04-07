import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/web_recorder_js.dart'
    if (dart.library.io) 'package:kita_english/core/audio/web_recorder_stub.dart';

/// Web-compatible audio recorder using browser MediaRecorder API.
/// Returns audio as bytes (webm/opus format) for upload to backend.
class WebRecorder {
  bool _recording = false;

  bool get isRecording => _recording;

  /// Start recording from the microphone.
  /// Returns true if recording started, false if mic access denied.
  Future<bool> start() async {
    if (!kIsWeb) return false;
    try {
      final result = await startWebRecording();
      _recording = result;
      return result;
    } catch (e) {
      debugPrint('WebRecorder start failed: $e');
      return false;
    }
  }

  /// Stop recording and return audio bytes (webm format).
  /// Returns null if recording wasn't active.
  Future<Uint8List?> stop() async {
    if (!kIsWeb || !_recording) return null;
    _recording = false;
    try {
      final base64Audio = await stopWebRecording();
      if (base64Audio == null || base64Audio.isEmpty) return null;
      return base64Decode(base64Audio);
    } catch (e) {
      debugPrint('WebRecorder stop failed: $e');
      return null;
    }
  }
}

final webRecorderProvider = Provider<WebRecorder>((ref) => WebRecorder());
