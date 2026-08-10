import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/user_profile.dart';

class NotAuthenticatedException implements Exception {
  const NotAuthenticatedException();
  @override
  String toString() => 'No authenticated user.';
}

class FirebaseService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  User get _requireUser {
    final user = _auth.currentUser;
    if (user == null) {
      throw const NotAuthenticatedException();
    }
    return user;
  }

  String get currentUid => _requireUser.uid;

  String? get authPhoneNumber => _auth.currentUser?.phoneNumber;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<UserProfile?> profileStream() {
    final uid = currentUid;
    return _userDoc(uid).snapshots().map((snap) {
      if (!snap.exists) {
        return null;
      }
      return UserProfile.fromSnapshot(snap);
    });
  }

  Future<UserProfile?> getUserProfile() async {
    final snap = await _userDoc(currentUid).get();
    if (!snap.exists) {
      return null;
    }
    return UserProfile.fromSnapshot(snap);
  }

  Future<UserProfile> createUserProfile() async {
    final user = _requireUser;
    final ref = _userDoc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'phoneNumber': user.phoneNumber ?? '',
        'displayName': UserProfile.defaultDisplayName,
        'photoUrl': null,
        'about': UserProfile.defaultAbout,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'privacy': {
          'lastSeen': 'everyone',
          'profilePhoto': 'everyone',
          'about': 'everyone',
          'onlineStatus': 'everyone',
        },
      });
    } else {
      final updates = <String, dynamic>{
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      };
      final data = snap.data();
      if ((data?['phoneNumber'] as String?)?.isNotEmpty != true &&
          (user.phoneNumber ?? '').isNotEmpty) {
        updates['phoneNumber'] = user.phoneNumber;
      }
      await ref.update(updates);
    }

    final fresh = await ref.get();
    return UserProfile.fromSnapshot(fresh);
  }

  Future<UserProfile> ensureProfileExists() async {
    return createUserProfile();
  }

  Future<void> updateUserProfile({
    required String displayName,
    required String about,
  }) async {
    await _userDoc(currentUid).update({
      'displayName': displayName.trim(),
      'about': about.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfilePhoto(String? photoUrl) async {
    await _userDoc(
      currentUid,
    ).update({'photoUrl': photoUrl, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> removeProfilePhoto() async {
    await updateProfilePhoto(null);
  }

  Future<void> updatePrivacy(String field, String value) async {
    await _userDoc(currentUid).update({
      'privacy.$field': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePhoneNumber(String phoneNumber) async {
    await _userDoc(currentUid).update({
      'phoneNumber': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setOnline(bool isOnline) async {
    try {
      await _userDoc(currentUid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Voxa] setOnline error: $e');
    }
  }

  Future<List<UserProfile>> getAllUsers() async {
    final uid = currentUid;
    final snapshot = await _firestore.collection('users').get();

    final users = <UserProfile>[];
    for (final doc in snapshot.docs) {
      if (doc.id != uid) {
        users.add(UserProfile.fromSnapshot(doc));
      }
    }
    return users;
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    final allUsers = await getAllUsers();
    final cleanQuery = query.trim().toLowerCase();

    if (cleanQuery.isEmpty) {
      return allUsers;
    }

    final results = <UserProfile>[];
    for (final u in allUsers) {
      final name = u.displayName.toLowerCase();
      final phone = u.phoneNumber.toLowerCase();
      if (name.contains(cleanQuery) || phone.contains(cleanQuery)) {
        results.add(u);
      }
    }
    return results;
  }

  final Map<String, UserProfile> _userProfileCache = {};

  Future<String> createOrGetChat(String targetUid) async {
    final uid = currentUid;

    final existing = await _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    for (final doc in existing.docs) {
      final data = doc.data();
      final isGroup = data['type'] == 'group';
      final List participants = data['participants'] as List? ?? [];
      if (!isGroup && participants.contains(targetUid)) {
        return doc.id;
      }
    }

    final sorted = [uid, targetUid]..sort();
    final customChatId = 'direct_${sorted.join('_')}';
    final chatDocRef = _firestore.collection('chats').doc(customChatId);
    final snap = await chatDocRef.get();

    if (!snap.exists) {
      await chatDocRef.set({
        'participants': [uid, targetUid],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageType': 'text',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'pinnedBy': [],
        'mutedBy': [],
        'archivedBy': [],
        'unreadCounts': {},
        'typingUsers': {},
      }, SetOptions(merge: true));
    }

    return customChatId;
  }

  Stream<List<Conversation>> chatsStream() {
    final uid = currentUid;

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .asyncMap((snapshot) async {
          final conversations = <Conversation>[];

          for (final doc in snapshot.docs) {
            final conversation = Conversation.fromSnapshot(doc);
            final otherUid = conversation.participants.firstWhere(
              (id) => id != uid,
              orElse: () => uid,
            );

            UserProfile? otherUser;
            if (otherUid != uid) {
              if (_userProfileCache.containsKey(otherUid)) {
                otherUser = _userProfileCache[otherUid];
              } else {
                final userSnap = await _userDoc(otherUid).get();
                if (userSnap.exists) {
                  otherUser = UserProfile.fromSnapshot(userSnap);
                  _userProfileCache[otherUid] = otherUser;
                }
              }
            }

            conversations.add(conversation.copyWith(otherUser: otherUser));
          }

          conversations.sort((a, b) {
            final aPinned = a.isPinnedFor(uid);
            final bPinned = b.isPinnedFor(uid);
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;

            final aTime = a.lastMessageTime ?? a.updatedAt ?? DateTime(2000);
            final bTime = b.lastMessageTime ?? b.updatedAt ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });

          return conversations;
        });
  }

  Future<void> togglePinChat(String chatId, bool isPinned) async {
    final uid = currentUid;
    final ref = _firestore.collection('chats').doc(chatId);
    if (isPinned) {
      await ref.update({
        'pinnedBy': FieldValue.arrayUnion([uid]),
      });
    } else {
      await ref.update({
        'pinnedBy': FieldValue.arrayRemove([uid]),
      });
    }
  }

  Future<void> toggleMuteChat(String chatId, bool isMuted) async {
    final uid = currentUid;
    final ref = _firestore.collection('chats').doc(chatId);
    if (isMuted) {
      await ref.update({
        'mutedBy': FieldValue.arrayUnion([uid]),
      });
    } else {
      await ref.update({
        'mutedBy': FieldValue.arrayRemove([uid]),
      });
    }
  }

  Future<void> toggleArchiveChat(String chatId, bool isArchived) async {
    final uid = currentUid;
    final ref = _firestore.collection('chats').doc(chatId);
    if (isArchived) {
      await ref.update({
        'archivedBy': FieldValue.arrayUnion([uid]),
      });
    } else {
      await ref.update({
        'archivedBy': FieldValue.arrayRemove([uid]),
      });
    }
  }

  Future<void> deleteChat(String chatId) async {
    await _firestore.collection('chats').doc(chatId).delete();
  }

  Stream<List<Message>> messagesStream(
    String conversationId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Message.fromSnapshot(doc)).toList();
        });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> conversationStream(
    String conversationId,
  ) {
    return _firestore.collection('chats').doc(conversationId).snapshots();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String receiverId,
    required String content,
    String? messageId,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    final uid = currentUid;
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final batch = _firestore.batch();
    final messagesCol = _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages');
    final messageRef = (messageId != null && messageId.isNotEmpty)
        ? messagesCol.doc(messageId)
        : messagesCol.doc();

    batch.set(messageRef, {
      'conversationId': conversationId,
      'senderId': uid,
      'receiverId': receiverId,
      'type': 'text',
      'content': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent',
      'replyToId': replyToId,
      'replyToText': replyToText,
      'replyToSender': replyToSender,
    });

    final chatRef = _firestore.collection('chats').doc(conversationId);
    batch.update(chatRef, {
      'lastMessage': trimmed,
      'lastMessageType': 'text',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> sendMediaMessage({
    required String conversationId,
    required String receiverId,
    required String type,
    required String content,
    required String mediaUrl,
    String? messageId,
    String? fileName,
    int? fileSize,
  }) async {
    final uid = currentUid;
    final batch = _firestore.batch();
    final messagesCol = _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages');
    final messageRef = (messageId != null && messageId.isNotEmpty)
        ? messagesCol.doc(messageId)
        : messagesCol.doc();

    final previewText = type == 'image'
        ? '📷 Photo'
        : (type == 'video'
              ? '🎥 Video'
              : (type == 'voice' ? '🎤 Voice message' : '📄 Document'));

    batch.set(messageRef, {
      'conversationId': conversationId,
      'senderId': uid,
      'receiverId': receiverId,
      'type': type,
      'content': content.isNotEmpty ? content : previewText,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent',
    });

    final chatRef = _firestore.collection('chats').doc(conversationId);
    batch.update(chatRef, {
      'lastMessage': content.isNotEmpty ? content : previewText,
      'lastMessageType': type,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> markMessagesAsSeen({required String conversationId}) async {
    try {
      final uid = currentUid;
      final unreadSnap = await _firestore
          .collection('chats')
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: uid)
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      if (unreadSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in unreadSnap.docs) {
          batch.update(doc.reference, {'status': 'seen'});
        }
        await batch.commit();
      }

      await _firestore.collection('chats').doc(conversationId).update({
        'unreadCounts.$uid': 0,
      });
    } catch (e) {
      debugPrint('[FirebaseService] markMessagesAsSeen error: $e');
    }
  }

  Future<void> setTypingStatus({
    required String conversationId,
    required bool isTyping,
  }) async {
    try {
      final uid = currentUid;
      await _firestore.collection('chats').doc(conversationId).update({
        'typingUsers.$uid': isTyping,
      });
    } catch (e) {
      debugPrint('[FirebaseService] setTypingStatus error: $e');
    }
  }

  Future<void> markInboundMessagesDelivered() async {
    try {
      final uid = currentUid;
      final chatsSnap = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      for (final chatDoc in chatsSnap.docs) {
        final undeliveredMsgs = await chatDoc.reference
            .collection('messages')
            .where('receiverId', isEqualTo: uid)
            .where('status', isEqualTo: 'sent')
            .get();

        if (undeliveredMsgs.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (final msgDoc in undeliveredMsgs.docs) {
            batch.update(msgDoc.reference, {'status': 'delivered'});
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('[FirebaseService] markInboundMessagesDelivered error: $e');
    }
  }

  Future<String> createGroup({
    required String groupName,
    String? groupPhoto,
    String? groupDescription,
    required List<String> memberUids,
  }) async {
    final uid = currentUid;
    final allParticipants = <String>{uid, ...memberUids}.toList();

    final newChatDoc = await _firestore.collection('chats').add({
      'type': 'group',
      'groupName': groupName.trim(),
      'groupPhoto': groupPhoto,
      'groupDescription': groupDescription?.trim() ?? '',
      'participants': allParticipants,
      'admins': [uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Group created',
      'lastMessageType': 'text',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'pinnedBy': [],
      'mutedBy': [],
      'archivedBy': [],
      'unreadCounts': {},
      'typingUsers': {},
    });

    return newChatDoc.id;
  }

  Future<void> addGroupMembers(
    String conversationId,
    List<String> memberUids,
  ) async {
    await _firestore.collection('chats').doc(conversationId).update({
      'participants': FieldValue.arrayUnion(memberUids),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeGroupMember(
    String conversationId,
    String memberUid,
  ) async {
    await _firestore.collection('chats').doc(conversationId).update({
      'participants': FieldValue.arrayRemove([memberUid]),
      'admins': FieldValue.arrayRemove([memberUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> promoteGroupAdmin(
    String conversationId,
    String memberUid,
  ) async {
    await _firestore.collection('chats').doc(conversationId).update({
      'admins': FieldValue.arrayUnion([memberUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> demoteGroupAdmin(String conversationId, String memberUid) async {
    await _firestore.collection('chats').doc(conversationId).update({
      'admins': FieldValue.arrayRemove([memberUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveGroup(String conversationId) async {
    final uid = currentUid;
    await removeGroupMember(conversationId, uid);
  }

  Future<List<UserProfile>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    final profiles = <UserProfile>[];
    for (final uid in uids) {
      final snap = await _userDoc(uid).get();
      if (snap.exists) {
        profiles.add(UserProfile.fromSnapshot(snap));
      }
    }
    return profiles;
  }

  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  }) async {
    await _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'content': newContent.trim(), 'isEdited': true});
  }

  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
  }) async {
    final uid = currentUid;
    await _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
          'deletedFor': FieldValue.arrayUnion([uid]),
        });
  }

  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    await _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'isDeleted': true, 'content': 'This message was deleted'});
  }

  Future<void> toggleStarMessage({
    required String conversationId,
    required String messageId,
    required bool isStarred,
  }) async {
    final uid = currentUid;
    final ref = _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    if (isStarred) {
      await ref.update({
        'starredBy': FieldValue.arrayUnion([uid]),
      });
    } else {
      await ref.update({
        'starredBy': FieldValue.arrayRemove([uid]),
      });
    }
  }

  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final uid = currentUid;
    await _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$uid': emoji});
  }

  Future<void> clearChat(String conversationId) async {
    final messagesSnap = await _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in messagesSnap.docs) {
      batch.delete(doc.reference);
    }

    batch.update(_firestore.collection('chats').doc(conversationId), {
      'lastMessage': '',
      'lastMessageType': 'text',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> markChatUnread(String conversationId) async {
    final uid = currentUid;
    await _firestore.collection('chats').doc(conversationId).update({
      'unreadCounts.$uid': 1,
    });
  }
}
