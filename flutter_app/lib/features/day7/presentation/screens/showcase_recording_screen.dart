import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/audio/audio_player.dart';
import 'package:kita_english/core/audio/audio_recorder.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/core/router/app_router.dart';
import 'package:kita_english/shared/widgets/kita_button.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Guided showcase recording screen for Day 7.
/// Shows a personalized script, provides record/playback/re-record/share.
class ShowcaseRecordingScreen extends ConsumerStatefulWidget {
  const ShowcaseRecordingScreen({super.key});

  @override
  ConsumerState<ShowcaseRecordingScreen> createState() =>
      _ShowcaseRecordingScreenState();
}

class _ShowcaseRecordingScreenState
    extends ConsumerState<ShowcaseRecordingScreen> {
  bool _isRecording = false;
  bool _hasRecording = false;
  bool _isPlaying = false;
  String? _recordingPath;

  final _scriptLines = const [
    'Hello! My name is ...',
    'I am ... years old.',
    'I like cats and dogs.',
    'My favorite color is blue.',
    'Thank you! Goodbye!',
  ];

  int _currentLine = 0;

  Future<void> _startRecording() async {
    final recorder = ref.read(audioRecorderProvider);
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/kita_showcase_$timestamp.wav';

      await recorder.startRecording(path);
      setState(() {
        _isRecording = true;
        _hasRecording = false;
        _recordingPath = path;
        _currentLine = 0;
      });

      // Advance highlighted line every 3 seconds
      _advanceLines();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _advanceLines() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || !_isRecording) return;
      if (_currentLine < _scriptLines.length - 1) {
        setState(() => _currentLine++);
        _advanceLines();
      }
    });
  }

  Future<void> _stopRecording() async {
    final recorder = ref.read(audioRecorderProvider);
    final path = await recorder.stopRecording();
    setState(() {
      _isRecording = false;
      _hasRecording = path != null;
      _recordingPath = path;
    });
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;
    final player = ref.read(audioPlayerProvider);
    setState(() => _isPlaying = true);
    await player.playFile(_recordingPath!);
    player.onComplete(() {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _stopPlayback() async {
    final player = ref.read(audioPlayerProvider);
    await player.stop();
    setState(() => _isPlaying = false);
  }

  void _reRecord() {
    setState(() {
      _hasRecording = false;
      _recordingPath = null;
    });
  }

  Future<void> _shareRecording() async {
    if (_recordingPath == null) return;
    await Share.shareXFiles(
      [XFile(_recordingPath!)],
      text: 'Nghe con tôi nói tiếng Anh! - Kita English',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thu âm trình diễn'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Intro text
              Text(
                'Đọc to đoạn dưới đây!',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Bé hãy đọc từng câu thật rõ ràng nhé',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Script card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.surfaceVariant),
                  ),
                  child: ListView.separated(
                    itemCount: _scriptLines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final isHighlighted =
                          _isRecording && index == _currentLine;
                      final isPast = _isRecording && index < _currentLine;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? AppColors.primary.withValues(alpha:0.1)
                              : isPast
                                  ? AppColors.successLight.withValues(alpha:0.1)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isHighlighted
                              ? Border.all(
                                  color: AppColors.primary, width: 2,)
                              : null,
                        ),
                        child: Row(
                          children: [
                            if (isPast)
                              const Icon(Icons.check_circle,
                                  color: AppColors.success, size: 20,)
                            else if (isHighlighted)
                              const Icon(Icons.arrow_forward,
                                  color: AppColors.primary, size: 20,)
                            else
                              const Icon(Icons.circle_outlined,
                                  color: AppColors.textHint, size: 20,),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _scriptLines[index],
                                style: AppTypography.bodyLarge.copyWith(
                                  fontSize: 20,
                                  fontWeight: isHighlighted
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isHighlighted
                                      ? AppColors.primary
                                      : isPast
                                          ? AppColors.success
                                          : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Controls
              if (!_hasRecording) ...[
                // Record button
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color:
                          _isRecording ? AppColors.error : AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording
                                  ? AppColors.error
                                  : AppColors.primary)
                              .withValues(alpha:0.4),
                          blurRadius: 16,
                          spreadRadius: _isRecording ? 4 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRecording ? 'Nhấn để dừng' : 'Nhấn để ghi âm',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                // Playback controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Play / Stop
                    GestureDetector(
                      onTap: _isPlaying ? _stopPlayback : _playRecording,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.stop : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Re-record
                    GestureDetector(
                      onTap: _reRecord,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: AppColors.textSecondary,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Share button
                KitaButton(
                  label: 'Chia sẻ',
                  onPressed: _shareRecording,
                  icon: Icons.share,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 12),

                // Go to certificate
                KitaButton(
                  label: 'Nhận chứng chỉ',
                  onPressed: () => context.push(RoutePaths.day7Certificate),
                  icon: Icons.emoji_events,
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
