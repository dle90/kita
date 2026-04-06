import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita_english/core/audio/audio_recorder.dart';
import 'package:kita_english/core/constants/app_colors.dart';
import 'package:kita_english/core/constants/app_typography.dart';
import 'package:kita_english/features/pronunciation/presentation/providers/pronunciation_provider.dart';
import 'package:path_provider/path_provider.dart';

/// Large animated microphone button with states:
/// idle (pulse), recording (waveform), uploading (spinner), scored (checkmark).
class RecordButton extends ConsumerStatefulWidget {
  final String referenceText;
  final void Function(String? path) onRecordingComplete;

  const RecordButton({
    super.key,
    required this.referenceText,
    required this.onRecordingComplete,
  });

  @override
  ConsumerState<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends ConsumerState<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isScored = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final recorder = ref.read(audioRecorderProvider);
    final pronNotifier = ref.read(pronunciationProvider.notifier);

    if (_isRecording) {
      // Stop recording
      final path = await recorder.stopRecording();
      setState(() => _isRecording = false);
      _pulseController.repeat(reverse: true);

      if (path != null) {
        pronNotifier.setRecordingComplete(path);
        setState(() => _isUploading = true);

        // Score pronunciation
        final score = await pronNotifier.scorePronunciation(
          audioPath: path,
          referenceText: widget.referenceText,
        );

        setState(() {
          _isUploading = false;
          _isScored = score != null;
        });

        widget.onRecordingComplete(path);
      }
    } else {
      // Start recording
      try {
        final dir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final outputPath = '${dir.path}/kita_recording_$timestamp.wav';

        await recorder.startRecording(outputPath);
        pronNotifier.setRecording();
        setState(() {
          _isRecording = true;
          _isScored = false;
        });
        _pulseController.repeat(reverse: true);

        // Auto-stop after 10 seconds
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted && _isRecording) {
            _toggleRecording();
          }
        });
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
  }

  @override
  Widget build(BuildContext context) {
    Color buttonColor;
    IconData buttonIcon;
    String labelText;

    if (_isScored) {
      buttonColor = AppColors.success;
      buttonIcon = Icons.check;
      labelText = 'Đã ghi xong!';
    } else if (_isUploading) {
      buttonColor = AppColors.primary;
      buttonIcon = Icons.hourglass_top;
      labelText = 'Đang đánh giá...';
    } else if (_isRecording) {
      buttonColor = AppColors.error;
      buttonIcon = Icons.stop;
      labelText = 'Nhấn để dừng';
    } else {
      buttonColor = AppColors.primary;
      buttonIcon = Icons.mic;
      labelText = 'Nhấn để nói';
    }

    return Column(
      children: [
        // Button
        GestureDetector(
          onTap: _isUploading ? null : _toggleRecording,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final scale = _isRecording ? _pulseAnimation.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: buttonColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withValues(alpha:0.4),
                    blurRadius: _isRecording ? 24 : 12,
                    spreadRadius: _isRecording ? 4 : 0,
                  ),
                ],
              ),
              child: _isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(
                      buttonIcon,
                      color: Colors.white,
                      size: 40,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Label
        Text(
          labelText,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
