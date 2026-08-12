import 'package:cloud_firestore/cloud_firestore.dart';

class StatusModel {
  final String statusId;
  final String uid;
  final String displayName;
  final String? profilePhoto;
  final String imageUrl;
  final String? caption;
  final DateTime timestamp;
  final List<String> viewers;

  const StatusModel({
    required this.statusId,
    required this.uid,
    required this.displayName,
    this.profilePhoto,
    required this.imageUrl,
    this.caption,
    required this.timestamp,
    this.viewers = const [],
  });

  factory StatusModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StatusModel(
      statusId: doc.id,
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? '',
      profilePhoto: data['profilePhoto'],
      imageUrl: data['imageUrl'] ?? '',
      caption: data['caption'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewers: List<String>.from(data['viewers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'profilePhoto': profilePhoto,
      'imageUrl': imageUrl,
      'caption': caption,
      'timestamp': FieldValue.serverTimestamp(),
      'viewers': viewers,
    };
  }
}
