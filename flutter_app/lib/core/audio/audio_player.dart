import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Wrapper around `just_audio` for playing audio URLs and local files.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  /// Current playback state.
  bool get isPlaying => _player.playing;

  /// Stream of player state changes.
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Stream of playback position.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of total duration.
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Plays audio from a network URL.
  Future<void> play(String url) async {
    await _player.setUrl(url);
    await _player.play();
  }

  /// Plays audio from a local file path.
  Future<void> playFile(String path) async {
    await _player.setFilePath(path);
    await _player.play();
  }

  /// Plays audio from an asset path.
  Future<void> playAsset(String assetPath) async {
    await _player.setAsset(assetPath);
    await _player.play();
  }

  /// Pauses the current playback.
  Future<void> pause() async {
    await _player.pause();
  }

  /// Resumes the current playback.
  Future<void> resume() async {
    await _player.play();
  }

  /// Stops the current playback and resets position.
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  /// Seeks to a specific position.
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Sets the playback speed (1.0 = normal).
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// Sets the volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  /// Registers a callback for when playback completes.
  void onComplete(void Function() callback) {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        callback();
      }
    });
  }

  /// Disposes the player. Call when done.
  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// Riverpod provider for [AudioPlayerService].
///
/// Each consumer gets its own instance so multiple audio sources
/// can be managed independently (e.g., activity audio vs. feedback audio).
final audioPlayerProvider = Provider.autoDispose<AudioPlayerService>((ref) {
  final player = AudioPlayerService();
  ref.onDispose(() => player.dispose());
  return player;
});
