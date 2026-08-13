import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/services/audio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/message.dart';

class VoiceMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioService _audioService = AudioService.instance;

  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _speed = 1.0;

  StreamSubscription? _stateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  @override
  void initState() {
    super.initState();
    _initAudioListeners();
  }

  void _initAudioListeners() {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return;

    _stateSub = _audioService.stateStreamFor(url).listen((state) {
      if (!mounted) return;
      setState(() => _playerState = state);
    });

    _positionSub = _audioService.positionStreamFor(url).listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });

    _durationSub = _audioService.durationStreamFor(url).listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur);
    });
    
    // Initial sync if this is already playing
    if (_audioService.currentlyPlayingUrl == url) {
      // Logic to fetch current duration/position from service if needed,
      // but usually the stream will emit soon.
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Audio URL is invalid.')));
      return;
    }

    final isCurrent = _audioService.currentlyPlayingUrl == url;

    if (isCurrent && _playerState == PlayerState.playing) {
      await _audioService.pause();
    } else if (isCurrent && _playerState == PlayerState.paused) {
      await _audioService.resume();
    } else {
      await _audioService.playUrl(url);
      await _audioService.setPlaybackRate(_speed);
    }
  }

  void _cycleSpeed() {
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
    if (_audioService.currentlyPlayingUrl == widget.message.mediaUrl) {
      _audioService.setPlaybackRate(_speed);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying =
        _playerState == PlayerState.playing &&
        _audioService.currentlyPlayingUrl == widget.message.mediaUrl;

    final maxMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final currentMs = _position.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _togglePlayPause,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  size: 38,
                  color: AppColors.secondary,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: currentMs,
                    max: maxMs,
                    activeColor: AppColors.secondary,
                    inactiveColor: AppColors.secondaryText.withValues(
                      alpha: 0.3,
                    ),
                    onChanged: (val) {
                      _audioService.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
              ),
              InkWell(
                onTap: _cycleSpeed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_speed}x',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(isPlaying ? _position : _duration),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
                const Icon(Icons.mic, size: 14, color: AppColors.secondaryText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
