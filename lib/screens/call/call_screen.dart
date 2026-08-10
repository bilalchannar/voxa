import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../core/config/agora_config.dart';
import '../../core/services/call_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/call_model.dart';
import '../../widgets/profile/profile_avatar.dart';

class CallScreen extends StatefulWidget {
  final CallModel call;
  final bool isIncoming;

  const CallScreen({super.key, required this.call, required this.isIncoming});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService.instance;

  RtcEngine? _engine;
  StreamSubscription<CallModel?>? _callSub;
  Timer? _durationTimer;

  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = true;
  bool _isConnected = false;
  int? _remoteUid;
  int _seconds = 0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    final callType = widget.call.isVideoCall ? 'video' : 'voice';
    _statusText = widget.isIncoming
        ? 'Incoming $callType call...'
        : 'Ringing...';
    _initCallSession();
    _listenToCallState();
  }

  Future<void> _initCallSession() async {
    if (!AgoraConfig.isConfigured) {
      setState(() => _statusText = 'Agora App ID not configured');
      return;
    }

    _engine = await _callService.createAgoraEngine(
      isVideoCall: widget.call.isVideoCall,
    );

    if (_engine == null) {
      if (mounted) {
        setState(() => _statusText = 'Permissions denied or init failed');
      }
      return;
    }

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!mounted) return;
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!mounted) return;
          setState(() => _remoteUid = remoteUid);
          _onCallConnected();
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (!mounted) return;
          setState(() => _remoteUid = null);
          _handleEndCall();
        },
        onConnectionStateChanged: (connection, state, reason) {
          if (!mounted) return;
          if (state == ConnectionStateType.connectionStateReconnecting) {
            setState(() => _statusText = 'Reconnecting...');
          } else if (state == ConnectionStateType.connectionStateFailed) {
            setState(() => _statusText = 'Call failed');
          }
        },
        onError: (err, msg) {
          debugPrint('[CallScreen] Agora error: $err - $msg');
        },
      ),
    );

    if (!widget.isIncoming) {
      await _callService.joinChannel(
        engine: _engine!,
        channelId: widget.call.channelId,
        isVideoCall: widget.call.isVideoCall,
      );
    }
  }

  void _listenToCallState() {
    _callSub = _callService.callStream(widget.call.callId).listen((call) {
      if (!mounted || call == null) return;

      if (call.status == 'connected' && !_isConnected) {
        _onCallConnected();
      } else if (call.status == 'rejected') {
        setState(() => _statusText = 'Call rejected');
        _closeScreenWithDelay();
      } else if (call.status == 'ended') {
        setState(() => _statusText = 'Call ended');
        _closeScreenWithDelay();
      }
    });
  }

  void _onCallConnected() {
    if (_isConnected) return;
    setState(() {
      _isConnected = true;
      _statusText = 'Connected';
    });

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _handleAccept() async {
    await _callService.acceptCall(widget.call.callId);
    if (_engine != null) {
      await _callService.joinChannel(
        engine: _engine!,
        channelId: widget.call.channelId,
        isVideoCall: widget.call.isVideoCall,
      );
    }
    _onCallConnected();
  }

  Future<void> _handleReject() async {
    await _callService.rejectCall(widget.call.callId);
    _handleEndCall();
  }

  Future<void> _handleEndCall() async {
    _durationTimer?.cancel();
    _callSub?.cancel();
    await _callService.endCall(widget.call.callId, duration: _seconds);
    await _callService.leaveChannel(_engine);
    if (mounted) Navigator.pop(context);
  }

  void _closeScreenWithDelay() {
    _durationTimer?.cancel();
    _callSub?.cancel();
    Future.delayed(const Duration(seconds: 1), () async {
      await _callService.leaveChannel(_engine);
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _toggleMute() async {
    if (_engine == null) return;
    final next = !_isMuted;
    await _engine!.muteLocalAudioStream(next);
    setState(() => _isMuted = next);
  }

  Future<void> _toggleSpeaker() async {
    if (_engine == null) return;
    final next = !_isSpeakerOn;
    await _engine!.setEnableSpeakerphone(next);
    setState(() => _isSpeakerOn = next);
  }

  Future<void> _toggleCamera() async {
    if (_engine == null || !widget.call.isVideoCall) return;
    final next = !_isVideoEnabled;
    await _engine!.enableLocalVideo(next);
    setState(() => _isVideoEnabled = next);
  }

  Future<void> _switchCamera() async {
    if (_engine == null || !widget.call.isVideoCall) return;
    await _engine!.switchCamera();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callSub?.cancel();
    _callService.leaveChannel(_engine);
    super.dispose();
  }

  String get _formattedTimer {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildRemoteVideo() {
    if (_engine != null && _remoteUid != null && widget.call.isVideoCall) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.call.channelId),
        ),
      );
    }

    final isMeCaller = !widget.isIncoming;
    final displayName = isMeCaller
        ? widget.call.receiverName
        : widget.call.callerName;
    final photoUrl = isMeCaller
        ? widget.call.receiverPhoto
        : widget.call.callerPhoto;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'V';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProfileAvatar(photoUrl: photoUrl, initial: initial, radius: 64),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildLocalVideoPreview() {
    if (_engine == null || !_isVideoEnabled || !widget.call.isVideoCall) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 48,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 100,
          height: 140,
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine!,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMeCaller = !widget.isIncoming;
    final displayName = isMeCaller
        ? widget.call.receiverName
        : widget.call.callerName;

    return Scaffold(
      backgroundColor: const Color(0xFF111D25),
      body: SafeArea(
        child: Stack(
          children: [
            Center(child: _buildRemoteVideo()),
            _buildLocalVideoPreview(),
            Positioned(
              top: 32,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isConnected ? _formattedTimer : _statusText,
                    style: TextStyle(
                      fontSize: 14,
                      color: _isConnected ? AppColors.accent : Colors.white70,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Colors.black45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filled(
                      onPressed: _toggleMute,
                      icon: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        size: 24,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isMuted
                            ? Colors.white
                            : Colors.white24,
                        foregroundColor: _isMuted ? Colors.black : Colors.white,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _toggleSpeaker,
                      icon: Icon(
                        _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        size: 24,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isSpeakerOn
                            ? Colors.white
                            : Colors.white24,
                        foregroundColor: _isSpeakerOn
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                    if (widget.call.isVideoCall) ...[
                      IconButton.filled(
                        onPressed: _toggleCamera,
                        icon: Icon(
                          _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                          size: 24,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: !_isVideoEnabled
                              ? Colors.white
                              : Colors.white24,
                          foregroundColor: !_isVideoEnabled
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _switchCamera,
                        icon: const Icon(Icons.switch_camera, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                    if (widget.isIncoming && !_isConnected)
                      IconButton.filled(
                        onPressed: _handleAccept,
                        icon: const Icon(Icons.call, size: 26),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    IconButton.filled(
                      onPressed: widget.isIncoming && !_isConnected
                          ? _handleReject
                          : _handleEndCall,
                      icon: const Icon(Icons.call_end, size: 26),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
