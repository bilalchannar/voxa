import 'package:flutter/foundation.dart';

import '../core/services/firebase_service.dart';
import '../models/conversation.dart';

class ChatListViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService;

  ChatListViewModel({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  String get currentUid => _firebaseService.currentUid;

  Stream<List<Conversation>> chatsStream() {
    return _firebaseService.chatsStream();
  }

  Future<void> pinChat(String chatId, bool isPinned) async {
    try {
      await _firebaseService.togglePinChat(chatId, isPinned);
    } catch (e) {
      debugPrint('[ChatListViewModel] pinChat error: $e');
    }
  }

  Future<void> muteChat(String chatId, bool isMuted) async {
    try {
      await _firebaseService.toggleMuteChat(chatId, isMuted);
    } catch (e) {
      debugPrint('[ChatListViewModel] muteChat error: $e');
    }
  }

  Future<void> archiveChat(String chatId, bool isArchived) async {
    try {
      await _firebaseService.toggleArchiveChat(chatId, isArchived);
    } catch (e) {
      debugPrint('[ChatListViewModel] archiveChat error: $e');
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      await _firebaseService.deleteChat(chatId);
    } catch (e) {
      debugPrint('[ChatListViewModel] deleteChat error: $e');
    }
  }
}
