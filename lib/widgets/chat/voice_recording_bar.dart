import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/audio_service.dart';
import '../../core/theme/app_colors.dart';

class VoiceRecordingBar extends StatefulWidget {
  final ValueChanged<File> onSend;
  final VoidCallback onCancel;

  const VoiceRecordingBar({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceRecordingBar> createState() => _VoiceRecordingBarState();
}

class _VoiceRecordingBarState extends State<VoiceRecordingBar> {
  final AudioService _audioService = AudioService.instance;
  Timer? _timer;
  int _seconds = 0;
  bool _isStarting = true;

  @override
  void initState() {
    super.initState();
    _startRecordingSession();
  }

  Future<void> _startRecordingSession() async {
    final started = await _audioService.startRecording();
    if (!mounted) return;

    if (started) {
      setState(() => _isStarting = false);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _seconds++);
      });
    } else {
      widget.onCancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission denied or recording failed.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _handleStopAndSend() async {
    _timer?.cancel();
    final audioFile = await _audioService.stopRecording();
    if (audioFile != null && mounted) {
      widget.onSend(audioFile);
    } else if (mounted) {
      widget.onCancel();
    }
  }

  Future<void> _handleCancel() async {
    _timer?.cancel();
    await _audioService.cancelRecording();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    if (_isStarting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Theme.of(context).cardColor,
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.danger,
              ),
            ),
            SizedBox(width: 12),
            Text('Starting recorder...'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Cancel recording',
            onPressed: _handleCancel,
          ),
          const Icon(
            Icons.fiber_manual_record,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            _formattedTime,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.danger,
            ),
          ),
          const Spacer(),
          const Text(
            'Recording...',
            style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: _handleStopAndSend,
            icon: const Icon(Icons.send, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
