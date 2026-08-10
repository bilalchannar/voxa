import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/services/cloudinary_service.dart';
import '../core/services/firebase_service.dart';
import '../models/message.dart';
import '../models/user_profile.dart';

class ChatViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final CloudinaryService _cloudinaryService;
  final String conversationId;
  final String receiverId;

  bool _isSending = false;
  bool _isUploading = false;
  String? _uploadError;

  Timer? _typingDebounceTimer;
  bool _isCurrentlyTyping = false;

  ChatViewModel({
    required this.conversationId,
    required this.receiverId,
    FirebaseService? firebaseService,
    CloudinaryService? cloudinaryService,
  }) : _firebaseService = firebaseService ?? FirebaseService(),
       _cloudinaryService = cloudinaryService ?? const CloudinaryService();

  bool get isSending => _isSending;
  bool get isUploading => _isUploading;
  String? get uploadError => _uploadError;
  String get currentUid => _firebaseService.currentUid;

  Future<UserProfile?> getCurrentUserProfile() {
    return _firebaseService.getUserProfile();
  }

  int _messageLimit = 50;

  int get messageLimit => _messageLimit;

  void loadMoreMessages() {
    _messageLimit += 50;
    notifyListeners();
  }

  Stream<List<Message>> messagesStream() {
    return _firebaseService.messagesStream(
      conversationId,
      limit: _messageLimit,
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> conversationStream() {
    return _firebaseService.conversationStream(conversationId);
  }

  Future<void> markMessagesAsSeen() async {
    await _firebaseService.markMessagesAsSeen(conversationId: conversationId);
  }

  void onUserTyping() {
    if (!_isCurrentlyTyping) {
      _isCurrentlyTyping = true;
      _firebaseService.setTypingStatus(
        conversationId: conversationId,
        isTyping: true,
      );
    }

    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(seconds: 2), () {
      _isCurrentlyTyping = false;
      _firebaseService.setTypingStatus(
        conversationId: conversationId,
        isTyping: false,
      );
    });
  }

  void stopTyping() {
    _typingDebounceTimer?.cancel();
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      _firebaseService.setTypingStatus(
        conversationId: conversationId,
        isTyping: false,
      );
    }
  }

  Future<bool> sendMessage(
    String text, {
    String? messageId,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return false;

    stopTyping();
    _isSending = true;
    notifyListeners();

    try {
      await _firebaseService.sendMessage(
        conversationId: conversationId,
        receiverId: receiverId,
        content: trimmed,
        messageId: messageId,
        replyToId: replyToId,
        replyToText: replyToText,
        replyToSender: replyToSender,
      );
      return true;
    } catch (e) {
      debugPrint('[ChatViewModel] sendMessage error: $e');
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> sendMedia({
    required File file,
    required String type,
    String caption = '',
    String? messageId,
    String? fileName,
    int? fileSize,
  }) async {
    if (_isUploading) return false;

    stopTyping();
    _isUploading = true;
    _uploadError = null;
    notifyListeners();

    try {
      final mediaUrl = await _cloudinaryService.uploadMediaFile(
        file: file,
        resourceType: type,
      );

      await _firebaseService.sendMediaMessage(
        conversationId: conversationId,
        receiverId: receiverId,
        type: type,
        content: caption.trim(),
        mediaUrl: mediaUrl,
        messageId: messageId,
        fileName: fileName ?? file.path.split(Platform.pathSeparator).last,
        fileSize: fileSize ?? await file.length(),
      );

      return true;
    } on CloudinaryNotConfiguredException catch (e) {
      _uploadError = e.toString();
      debugPrint('[ChatViewModel] sendMedia error: $e');
      return false;
    } on CloudinaryUploadException catch (e) {
      _uploadError = e.message;
      debugPrint('[ChatViewModel] sendMedia upload error: $e');
      return false;
    } catch (e) {
      _uploadError = 'Failed to upload media. Please try again.';
      debugPrint('[ChatViewModel] sendMedia error: $e');
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopTyping();
    super.dispose();
  }
}
