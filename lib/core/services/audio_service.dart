import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();

  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  String? _currentRecordingPath;
  String? _currentlyPlayingUrl;

  bool get isRecording => _isRecording;
  AudioPlayer get player => _player;
  String? get currentlyPlayingUrl => _currentlyPlayingUrl;

  Future<bool> hasPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return false;

      final dir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('[AudioService] startRecording error: $e');
      _isRecording = false;
      return false;
    }
  }

  Future<File?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;

      final targetPath = path ?? _currentRecordingPath;
      if (targetPath != null && targetPath.isNotEmpty) {
        final file = File(targetPath);
        if (await file.exists()) {
          return file;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[AudioService] stopRecording error: $e');
      _isRecording = false;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      _isRecording = false;

      final targetPath = path ?? _currentRecordingPath;
      if (targetPath != null) {
        final file = File(targetPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('[AudioService] cancelRecording error: $e');
      _isRecording = false;
    }
  }

  Future<void> playUrl(String url) async {
    try {
      if (_currentlyPlayingUrl != null && _currentlyPlayingUrl != url) {
        await _player.stop();
      }
      _currentlyPlayingUrl = url;
      await _player.play(UrlSource(url));
    } catch (e) {
      debugPrint('[AudioService] playUrl error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[AudioService] pause error: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (e) {
      debugPrint('[AudioService] resume error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _currentlyPlayingUrl = null;
    } catch (e) {
      debugPrint('[AudioService] stop error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[AudioService] seek error: $e');
    }
  }

  Future<void> setPlaybackRate(double speed) async {
    try {
      await _player.setPlaybackRate(speed);
    } catch (e) {
      debugPrint('[AudioService] setPlaybackRate error: $e');
    }
  }
}
