import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/sound_effects_web.dart'
    if (dart.library.io) 'package:kita_english/core/audio/sound_effects_stub.dart';

/// Lightweight sound effects using Web Audio API (web) or haptics (native).
class SoundEffects {
  /// Play a short "correct" chime (two ascending tones)
  Future<void> playCorrect() async {
    if (kIsWeb) {
      playWebTone(880, 0.15, 'sine');
      await Future.delayed(const Duration(milliseconds: 120));
      playWebTone(1175, 0.2, 'sine');
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  /// Play a gentle "wrong" sound (soft descending tone, not harsh)
  Future<void> playWrong() async {
    if (kIsWeb) {
      playWebTone(440, 0.15, 'sine');
      await Future.delayed(const Duration(milliseconds: 100));
      playWebTone(330, 0.2, 'sine');
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Play a short UI "tap" click
  Future<void> playTap() async {
    if (kIsWeb) {
      playWebTone(600, 0.05, 'sine');
    } else {
      await HapticFeedback.selectionClick();
    }
  }

  /// Play a celebration jingle (C-E-G-C ascending)
  Future<void> playCelebration() async {
    if (kIsWeb) {
      playWebTone(523, 0.12, 'sine');
      await Future.delayed(const Duration(milliseconds: 120));
      playWebTone(659, 0.12, 'sine');
      await Future.delayed(const Duration(milliseconds: 120));
      playWebTone(784, 0.12, 'sine');
      await Future.delayed(const Duration(milliseconds: 120));
      playWebTone(1047, 0.3, 'sine');
    } else {
      await HapticFeedback.heavyImpact();
    }
  }
}

final soundEffectsProvider = Provider<SoundEffects>((ref) => SoundEffects());
