import 'package:cloud_firestore/cloud_firestore.dart';

class StatusModel {
  final String statusId;
  final String uid;
  final String displayName;
  final String? profilePhoto;
  final String type; // 'image', 'video', 'text'
  final String? imageUrl;
  final String? text;
  final int? backgroundColor;
  final String? caption;
  final String privacy; // 'everyone', 'contacts', 'nobody'
  final DateTime timestamp;
  final List<String> viewers;

  const StatusModel({
    required this.statusId,
    required this.uid,
    required this.displayName,
    this.profilePhoto,
    this.type = 'image',
    this.imageUrl,
    this.text,
    this.backgroundColor,
    this.caption,
    this.privacy = 'everyone',
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
      type: data['type'] ?? 'image',
      imageUrl: data['imageUrl'],
      text: data['text'],
      backgroundColor: data['backgroundColor'],
      caption: data['caption'],
      privacy: data['privacy'] ?? 'everyone',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewers: List<String>.from(data['viewers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'profilePhoto': profilePhoto,
      'type': type,
      'imageUrl': imageUrl,
      'text': text,
      'backgroundColor': backgroundColor,
      'caption': caption,
      'privacy': privacy,
      'timestamp': FieldValue.serverTimestamp(),
      'viewers': viewers,
    };
  }
}
