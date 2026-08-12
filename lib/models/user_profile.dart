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

  /// Core privacy resolver.
  ///
  /// Each privacy field is one of `everyone` | `contacts` | `nobody`:
  /// - `nobody`   → never visible to anyone but the owner.
  /// - `contacts` → visible only when the viewer is a contact of the owner.
  ///   Voxa has no address-book graph, so "contact" means *someone you share a
  ///   1:1 chat with*. That relationship is symmetric, so the viewer can decide
  ///   visibility from their own contact set: the owner is visible iff the
  ///   owner's uid is in the viewer's contacts (`viewerContacts.contains(uid)`).
  /// - `everyone` → always visible (also the default when unset/unknown).
  ///
  /// The owner can always see their own information.
  bool _visibleTo(
    String settingKey,
    String? viewerUid,
    Set<String> viewerContacts,
  ) {
    if (viewerUid != null && viewerUid == uid) return true;
    final setting = privacy[settingKey] as String? ?? 'everyone';
    switch (setting) {
      case 'nobody':
        return false;
      case 'contacts':
        return viewerContacts.contains(uid);
      case 'everyone':
      default:
        return true;
    }
  }

  bool canSeeLastSeen(
    String? viewerUid, {
    Set<String> viewerContacts = const <String>{},
  }) => _visibleTo('lastSeen', viewerUid, viewerContacts);

  bool canSeePhoto(
    String? viewerUid, {
    Set<String> viewerContacts = const <String>{},
  }) => _visibleTo('profilePhoto', viewerUid, viewerContacts);

  bool canSeeAbout(
    String? viewerUid, {
    Set<String> viewerContacts = const <String>{},
  }) => _visibleTo('about', viewerUid, viewerContacts);

  bool canSeeOnlineStatus(
    String? viewerUid, {
    Set<String> viewerContacts = const <String>{},
  }) => _visibleTo('onlineStatus', viewerUid, viewerContacts);

  bool canSeeStatus(
    String? viewerUid, {
    Set<String> viewerContacts = const <String>{},
  }) => _visibleTo('status', viewerUid, viewerContacts);

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
