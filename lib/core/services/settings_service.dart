import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_settings.dart';
import 'firebase_service.dart';

class SettingsService {
  SettingsService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedException();
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _settingsDoc(String docName) =>
      _firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc(docName);

  Stream<NotificationSettings> notificationsStream() {
    return _settingsDoc('notifications')
        .snapshots()
        .map((snap) => NotificationSettings.fromMap(snap.data()))
        .handleError((_) => const NotificationSettings());
  }

  Future<NotificationSettings> getNotifications() async {
    try {
      final snap = await _settingsDoc('notifications').get();
      return NotificationSettings.fromMap(snap.data());
    } catch (_) {
      return const NotificationSettings();
    }
  }

  Future<void> saveNotifications(NotificationSettings settings) async {
    await _settingsDoc('notifications').set(settings.toMap());
  }

  Stream<ChatSettings> chatsStream() {
    return _settingsDoc('chats')
        .snapshots()
        .map((snap) => ChatSettings.fromMap(snap.data()))
        .handleError((_) => const ChatSettings());
  }

  Future<void> saveChats(ChatSettings settings) async {
    await _settingsDoc('chats').set(settings.toMap());
  }

  Future<ChatSettings> getChats() async {
    try {
      final snap = await _settingsDoc('chats').get();
      return ChatSettings.fromMap(snap.data());
    } catch (_) {
      return const ChatSettings();
    }
  }

  Stream<StorageSettings> storageStream() {
    return _settingsDoc('storage')
        .snapshots()
        .map((snap) => StorageSettings.fromMap(snap.data()))
        .handleError((_) => const StorageSettings());
  }

  Future<void> saveStorage(StorageSettings settings) async {
    await _settingsDoc('storage').set(settings.toMap());
  }

  Future<StorageSettings> getStorage() async {
    try {
      final snap = await _settingsDoc('storage').get();
      return StorageSettings.fromMap(snap.data());
    } catch (_) {
      return const StorageSettings();
    }
  }

  Future<String?> loadThemeMode() async {
    final snap = await _settingsDoc('appearance').get();
    return snap.data()?['themeMode'] as String?;
  }

  Future<void> saveThemeMode(String themeMode) async {
    await _settingsDoc('appearance').set({'themeMode': themeMode});
  }
}
