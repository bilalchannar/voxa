import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String type;
  final String content;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;
  final DateTime? createdAt;
  final String status;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final bool isEdited;
  final bool isDeleted;
  final bool isPending;
  final List<String> deletedFor;
  final List<String> starredBy;
  final Map<String, String> reactions;

  const Message({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    this.type = 'text',
    required this.content,
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.createdAt,
    this.status = 'sent',
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.isEdited = false,
    this.isDeleted = false,
    this.isPending = false,
    this.deletedFor = const [],
    this.starredBy = const [],
    this.reactions = const {},
  });

  bool isDeletedFor(String uid) => isDeleted || deletedFor.contains(uid);
  bool isStarredBy(String uid) => starredBy.contains(uid);

  factory Message.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Message(
      messageId: doc.id,
      conversationId: (data['conversationId'] as String?) ?? '',
      senderId: (data['senderId'] as String?) ?? '',
      receiverId: (data['receiverId'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'text',
      content: (data['content'] as String?) ?? '',
      mediaUrl: data['mediaUrl'] as String?,
      fileName: data['fileName'] as String?,
      fileSize: (data['fileSize'] as num?)?.toInt(),
      createdAt: _parseDate(data['createdAt']),
      status: (data['status'] as String?) ?? 'sent',
      replyToId: data['replyToId'] as String?,
      replyToText: data['replyToText'] as String?,
      replyToSender: data['replyToSender'] as String?,
      isEdited: (data['isEdited'] as bool?) ?? false,
      isDeleted: (data['isDeleted'] as bool?) ?? false,
      isPending: doc.metadata.hasPendingWrites,
      deletedFor: List<String>.from(data['deletedFor'] as List? ?? []),
      starredBy: List<String>.from(data['starredBy'] as List? ?? []),
      reactions: data['reactions'] is Map<String, dynamic>
          ? Map<String, String>.from(data['reactions'] as Map)
          : <String, String>{},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'type': type,
      'content': content,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'createdAt': createdAt,
      'status': status,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'replyToSender': replyToSender,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'deletedFor': deletedFor,
      'starredBy': starredBy,
      'reactions': reactions,
    };
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
