import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/user_profile.dart';
import '../../screens/chat/chat_screen.dart';
import 'settings_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SettingsService _settingsService = SettingsService();

  GlobalKey<NavigatorState>? _navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationPayload(response.payload);
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'voxa_messages',
      'Voxa Messages',
      description: 'High importance channel for Voxa messages & calls.',
      importance: Importance.high,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(androidChannel);

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      final token = await _fcm.getToken();
      await saveFcmToken(token);

      _fcm.onTokenRefresh.listen((newToken) {
        saveFcmToken(newToken);
      });
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageData(message.data);
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageData(initialMessage.data);
    }
  }

  Future<void> saveFcmToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[NotificationService] saveFcmToken error: $e');
    }
  }

  Future<void> removeFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[NotificationService] removeFcmToken error: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    try {
      final notificationPrefs = await _settingsService.getNotifications();
      final isMessageNotif = message.data['type'] != 'call';

      if (isMessageNotif && !notificationPrefs.messageNotifications) return;
      if (!isMessageNotif && !notificationPrefs.callNotifications) return;

      final title =
          message.notification?.title ?? message.data['title'] ?? 'Voxa';
      final body =
          message.notification?.body ??
          message.data['body'] ??
          'New message received.';
      final senderId = message.data['senderId'] as String?;
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      if (senderId != null && senderId == currentUid) return;

      final androidDetails = AndroidNotificationDetails(
        'voxa_messages',
        'Voxa Messages',
        channelDescription:
            'High importance channel for Voxa messages & calls.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: notificationPrefs.sound,
        enableVibration: notificationPrefs.vibration,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: notificationPrefs.sound,
        ),
      );

      final payload = message.data.values.join('|');
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] showForegroundNotification error: $e');
    }
  }

  void _handleMessageData(Map<String, dynamic> data) {
    final conversationId = data['conversationId'] as String?;
    final senderId = data['senderId'] as String?;
    final senderName = (data['senderName'] as String?) ?? 'Voxa User';
    final type = data['type'] as String?;

    if (type == 'call') {
      debugPrint(
        '[NotificationService] Call notification received for future Agora call.',
      );
      return;
    }

    if (conversationId != null && senderId != null && _navigatorKey != null) {
      final recipient = UserProfile(
        uid: senderId,
        phoneNumber: '',
        displayName: senderName,
        photoUrl: null,
        about: '',
        isOnline: true,
      );

      _navigatorKey!.currentState?.push(
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(conversationId: conversationId, recipient: recipient),
        ),
      );
    }
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint(
      '[NotificationService] Notification tapped with payload: $payload',
    );
  }
}
