import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

/// Wrapper around the `record` package for capturing audio.
/// Configured for speech recognition: 16kHz, 16-bit, mono WAV.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;

  /// Whether the recorder is currently recording.
  bool get isRecording => _isRecording;

  /// Checks if the app has microphone permission.
  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  /// Starts recording to the given [outputPath].
  ///
  /// Configures for 16kHz, 16-bit mono WAV suitable for
  /// pronunciation scoring APIs.
  Future<void> startRecording(String outputPath) async {
    if (_isRecording) {
      await stopRecording();
    }

    final hasPerms = await _recorder.hasPermission();
    if (!hasPerms) {
      throw const RecorderPermissionException(
        'Chưa có quyền ghi âm. Vui lòng cấp quyền trong cài đặt.',
      );
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        bitRate: 256000,
        numChannels: 1,
      ),
      path: outputPath,
    );

    _isRecording = true;
  }

  /// Stops recording and returns the path to the recorded file.
  ///
  /// Returns `null` if not currently recording.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;
    return path;
  }

  /// Cancels the current recording without saving.
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
  }

  /// Returns the current amplitude (dB) of the recording.
  /// Useful for showing a waveform or level meter.
  Future<Amplitude> getAmplitude() async {
    return _recorder.getAmplitude();
  }

  /// Disposes the recorder. Call when done.
  Future<void> dispose() async {
    if (_isRecording) {
      await _recorder.cancel();
    }
    _recorder.dispose();
  }
}

/// Exception thrown when microphone permission is not granted.
class RecorderPermissionException implements Exception {
  final String message;
  const RecorderPermissionException(this.message);

  @override
  String toString() => 'RecorderPermissionException: $message';
}

/// Riverpod provider for [AudioRecorderService].
final audioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final recorder = AudioRecorderService();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});
