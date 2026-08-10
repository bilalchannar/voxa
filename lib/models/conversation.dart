import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile.dart';

class Conversation {
  final String id;
  final String type;
  final List<String> participants;
  final String? groupName;
  final String? groupPhoto;
  final String? groupDescription;
  final List<String> admins;
  final String lastMessage;
  final String lastMessageType;
  final DateTime? lastMessageTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> pinnedBy;
  final List<String> mutedBy;
  final List<String> archivedBy;
  final Map<String, dynamic> unreadCounts;
  final UserProfile? otherUser;

  const Conversation({
    required this.id,
    this.type = 'private',
    required this.participants,
    this.groupName,
    this.groupPhoto,
    this.groupDescription,
    this.admins = const [],
    required this.lastMessage,
    this.lastMessageType = 'text',
    this.lastMessageTime,
    this.createdAt,
    this.updatedAt,
    this.pinnedBy = const [],
    this.mutedBy = const [],
    this.archivedBy = const [],
    this.unreadCounts = const {},
    this.otherUser,
  });

  bool get isGroup => type == 'group';
  bool isAdmin(String uid) => admins.contains(uid);

  factory Conversation.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    UserProfile? otherUser,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    return Conversation(
      id: doc.id,
      type: (data['type'] as String?) ?? 'private',
      participants: List<String>.from(data['participants'] as List? ?? []),
      groupName: data['groupName'] as String?,
      groupPhoto: data['groupPhoto'] as String?,
      groupDescription: data['groupDescription'] as String?,
      admins: List<String>.from(data['admins'] as List? ?? []),
      lastMessage: (data['lastMessage'] as String?) ?? '',
      lastMessageType: (data['lastMessageType'] as String?) ?? 'text',
      lastMessageTime: _parseDate(data['lastMessageTime']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      pinnedBy: List<String>.from(data['pinnedBy'] as List? ?? []),
      mutedBy: List<String>.from(data['mutedBy'] as List? ?? []),
      archivedBy: List<String>.from(data['archivedBy'] as List? ?? []),
      unreadCounts: data['unreadCounts'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['unreadCounts'] as Map)
          : <String, dynamic>{},
      otherUser: otherUser,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'participants': participants,
      'groupName': groupName,
      'groupPhoto': groupPhoto,
      'groupDescription': groupDescription,
      'admins': admins,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageTime': lastMessageTime,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'pinnedBy': pinnedBy,
      'mutedBy': mutedBy,
      'archivedBy': archivedBy,
      'unreadCounts': unreadCounts,
    };
  }

  bool isPinnedFor(String uid) => pinnedBy.contains(uid);
  bool isMutedFor(String uid) => mutedBy.contains(uid);
  bool isArchivedFor(String uid) => archivedBy.contains(uid);
  int unreadCountFor(String uid) => (unreadCounts[uid] as num?)?.toInt() ?? 0;

  Conversation copyWith({UserProfile? otherUser}) {
    return Conversation(
      id: id,
      type: type,
      participants: participants,
      groupName: groupName,
      groupPhoto: groupPhoto,
      groupDescription: groupDescription,
      admins: admins,
      lastMessage: lastMessage,
      lastMessageType: lastMessageType,
      lastMessageTime: lastMessageTime,
      createdAt: createdAt,
      updatedAt: updatedAt,
      pinnedBy: pinnedBy,
      mutedBy: mutedBy,
      archivedBy: archivedBy,
      unreadCounts: unreadCounts,
      otherUser: otherUser ?? this.otherUser,
    );
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
