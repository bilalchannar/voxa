import 'package:cloud_firestore/cloud_firestore.dart';

class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String receiverId;
  final String receiverName;
  final String? receiverPhoto;
  final String channelId;
  final String status;
  final bool isVideoCall;
  final int duration;
  final DateTime? timestamp;

  const CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhoto,
    required this.channelId,
    required this.status,
    this.isVideoCall = false,
    this.duration = 0,
    this.timestamp,
  });

  String get type => isVideoCall ? 'video' : 'audio';

  bool isMeCaller(String currentUid) => callerId == currentUid;

  String otherName(String currentUid) =>
      isMeCaller(currentUid) ? receiverName : callerName;

  String? otherPhoto(String currentUid) =>
      isMeCaller(currentUid) ? receiverPhoto : callerPhoto;

  String otherUid(String currentUid) =>
      isMeCaller(currentUid) ? receiverId : callerId;

  bool isMissed(String currentUid) =>
      !isMeCaller(currentUid) &&
      (status == 'dialing' || status == 'rejected' || status == 'failed');

  factory CallModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CallModel(
      callId: doc.id,
      callerId: (data['callerId'] as String?) ?? '',
      callerName: (data['callerName'] as String?) ?? 'Voxa User',
      callerPhoto: data['callerPhoto'] as String?,
      receiverId: (data['receiverId'] as String?) ?? '',
      receiverName: (data['receiverName'] as String?) ?? 'Voxa User',
      receiverPhoto: data['receiverPhoto'] as String?,
      channelId: (data['channelId'] as String?) ?? doc.id,
      status: (data['status'] as String?) ?? 'dialing',
      isVideoCall: (data['isVideoCall'] as bool?) ?? false,
      duration: (data['duration'] as num?)?.toInt() ?? 0,
      timestamp: _parseDate(data['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'channelId': channelId,
      'status': status,
      'isVideoCall': isVideoCall,
      'duration': duration,
      'timestamp': timestamp,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
