import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/call_model.dart';
import '../../models/user_profile.dart';
import '../config/agora_config.dart';
import 'firebase_service.dart';

class CallService {
  static final CallService instance = CallService._internal();

  CallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();

  String get currentUid => _auth.currentUser?.uid ?? '';

  Stream<UserProfile?> profileStream({String? uid}) {
    return _firebaseService.profileStream(uid: uid);
  }

  Future<CallModel?> makeCall({
    required UserProfile receiver,
    required UserProfile caller,
    bool isVideoCall = false,
  }) async {
    try {
      final docRef = _firestore.collection('calls').doc();
      final call = CallModel(
        callId: docRef.id,
        callerId: caller.uid,
        callerName: caller.displayName,
        callerPhoto: caller.photoUrl,
        receiverId: receiver.uid,
        receiverName: receiver.displayName,
        receiverPhoto: receiver.photoUrl,
        channelId: 'test', // TEMPORARY: Hardcoded for token testing
        status: 'dialing',
        isVideoCall: isVideoCall,
        timestamp: DateTime.now(),
      );

      await docRef.set({
        ...call.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      return call;
    } catch (e) {
      debugPrint('[CallService] makeCall error: $e');
      return null;
    }
  }

  Future<void> acceptCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'connected',
      });
    } catch (e) {
      debugPrint('[CallService] acceptCall error: $e');
    }
  }

  Future<void> rejectCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
      });
    } catch (e) {
      debugPrint('[CallService] rejectCall error: $e');
    }
  }

  Future<void> endCall(String callId, {int duration = 0}) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'duration': duration,
      });
    } catch (e) {
      debugPrint('[CallService] endCall error: $e');
    }
  }

  Stream<CallModel?> callStream(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return CallModel.fromSnapshot(snap);
    });
  }

  Stream<List<CallModel>> incomingCallsStream(String uid) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'dialing')
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) => CallModel.fromSnapshot(d)).toList();
        });
  }

  Stream<List<CallModel>> callHistoryStream(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    final callerStream = _firestore
        .collection('calls')
        .where('callerId', isEqualTo: uid)
        .snapshots();

    return callerStream.asyncMap((callerSnap) async {
      final receiverSnap = await _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: uid)
          .get();

      final callMap = <String, CallModel>{};
      for (final d in callerSnap.docs) {
        callMap[d.id] = CallModel.fromSnapshot(d);
      }
      for (final d in receiverSnap.docs) {
        callMap[d.id] = CallModel.fromSnapshot(d);
      }

      final calls = callMap.values.toList();
      calls.sort((a, b) {
        final aTime = a.timestamp ?? DateTime(2000);
        final bTime = b.timestamp ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return calls;
    });
  }

  Future<void> deleteCallHistoryItem(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).delete();
    } catch (e) {
      debugPrint('[CallService] deleteCallHistoryItem error: $e');
    }
  }

  Future<RtcEngine?> createAgoraEngine({bool isVideoCall = false}) async {
    if (!AgoraConfig.isConfigured) {
      debugPrint('[CallService] Agora App ID is not configured.');
      return null;
    }

    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) return null;

      if (isVideoCall) {
        final camStatus = await Permission.camera.request();
        if (!camStatus.isGranted) return null;
      }

      final engine = createAgoraRtcEngine();
      await engine.initialize(
        const RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onError: (err, msg) {
            debugPrint('[Agora] Engine error ($err): $msg');
          },
          onConnectionStateChanged: (connection, state, reason) {
            debugPrint(
              '[Agora] Connection state changed: $state, reason: $reason',
            );
          },
          onTokenPrivilegeWillExpire: (connection, token) {
            debugPrint('[Agora] Token privilege will expire');
          },
          onRejoinChannelSuccess: (connection, elapsed) {
            debugPrint('[Agora] Rejoined channel successfully ($elapsed ms)');
          },
        ),
      );

      await engine.enableAudio();
      if (isVideoCall) {
        await engine.enableVideo();
        await engine.startPreview();
      }

      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );

      return engine;
    } catch (e) {
      debugPrint('[CallService] createAgoraEngine error: $e');
      return null;
    }
  }

  Future<void> joinChannel({
    required RtcEngine engine,
    required String channelId,
    bool isVideoCall = false,
    String token = '',
  }) async {
    try {
      await engine.joinChannel(
        token: token.isNotEmpty ? token : AgoraConfig.devToken,
        channelId: channelId,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          publishCameraTrack: isVideoCall,
          autoSubscribeAudio: true,
          autoSubscribeVideo: isVideoCall,
        ),
      );
    } catch (e) {
      debugPrint('[CallService] joinChannel error: $e');
    }
  }

  Future<void> leaveChannel(RtcEngine? engine) async {
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (e) {
      debugPrint('[CallService] leaveChannel error: $e');
    }
  }
}
