import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String phoneNumber;
  final String displayName;
  final String? photoUrl;
  final String about;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> privacy;

  const UserProfile({
    required this.uid,
    required this.phoneNumber,
    required this.displayName,
    this.photoUrl,
    required this.about,
    required this.isOnline,
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
    this.privacy = const {},
  });

  static const String defaultDisplayName = 'Voxa User';
  static const String defaultAbout = 'Hey there! I am using Voxa.';

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      phoneNumber: (map['phoneNumber'] as String?)?.trim() ?? '',
      displayName: (map['displayName'] as String?)?.trim().isNotEmpty == true
          ? (map['displayName'] as String).trim()
          : defaultDisplayName,
      photoUrl: (map['photoUrl'] as String?)?.trim().isNotEmpty == true
          ? (map['photoUrl'] as String).trim()
          : null,
      about: (map['about'] as String?)?.trim().isNotEmpty == true
          ? (map['about'] as String).trim()
          : defaultAbout,
      isOnline: (map['isOnline'] as bool?) ?? false,
      lastSeen: _parseDate(map['lastSeen']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      privacy: map['privacy'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['privacy'] as Map)
          : <String, dynamic>{},
    );
  }

  factory UserProfile.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserProfile.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'about': about,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'privacy': privacy,
    };
  }

  String get initial {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return 'V';
    }
    return trimmed.substring(0, 1).toUpperCase();
  }

  bool get hasPhoto {
    return photoUrl != null && photoUrl!.isNotEmpty;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
