import 'package:flutter/material.dart';

/// Notification preferences stored at
/// `users/{uid}/settings/notifications`.
class NotificationSettings {
  final bool messageNotifications;
  final bool callNotifications;
  final bool sound;
  final bool vibration;

  const NotificationSettings({
    this.messageNotifications = true,
    this.callNotifications = true,
    this.sound = true,
    this.vibration = true,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationSettings();
    return NotificationSettings(
      messageNotifications: (map['messageNotifications'] as bool?) ?? true,
      callNotifications: (map['callNotifications'] as bool?) ?? true,
      sound: (map['sound'] as bool?) ?? true,
      vibration: (map['vibration'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageNotifications': messageNotifications,
      'callNotifications': callNotifications,
      'sound': sound,
      'vibration': vibration,
    };
  }

  NotificationSettings copyWith({
    bool? messageNotifications,
    bool? callNotifications,
    bool? sound,
    bool? vibration,
  }) {
    return NotificationSettings(
      messageNotifications: messageNotifications ?? this.messageNotifications,
      callNotifications: callNotifications ?? this.callNotifications,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
    );
  }
}

/// A selectable font scale for chat content.
enum ChatFontSize {
  small,
  medium,
  large;

  String get label {
    switch (this) {
      case ChatFontSize.small:
        return 'Small';
      case ChatFontSize.medium:
        return 'Medium';
      case ChatFontSize.large:
        return 'Large';
    }
  }

  /// A concrete font size in logical pixels, used by preview widgets so the
  /// setting has a visible effect.
  double get fontSize {
    switch (this) {
      case ChatFontSize.small:
        return 14;
      case ChatFontSize.medium:
        return 16;
      case ChatFontSize.large:
        return 18;
    }
  }

  static ChatFontSize fromString(String? value) {
    return ChatFontSize.values.firstWhere(
      (v) => v.name == value,
      orElse: () => ChatFontSize.medium,
    );
  }
}

/// Chat preferences stored at `users/{uid}/settings/chats`.
class ChatSettings {
  final bool enterKeySends;
  final bool mediaVisibility;
  final ChatFontSize fontSize;
  final int wallpaperColor; // ARGB int; 0 means "default".

  const ChatSettings({
    this.enterKeySends = false,
    this.mediaVisibility = true,
    this.fontSize = ChatFontSize.medium,
    this.wallpaperColor = 0,
  });

  factory ChatSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ChatSettings();
    return ChatSettings(
      enterKeySends: (map['enterKeySends'] as bool?) ?? false,
      mediaVisibility: (map['mediaVisibility'] as bool?) ?? true,
      fontSize: ChatFontSize.fromString(map['fontSize'] as String?),
      wallpaperColor: (map['wallpaperColor'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enterKeySends': enterKeySends,
      'mediaVisibility': mediaVisibility,
      'fontSize': fontSize.name,
      'wallpaperColor': wallpaperColor,
    };
  }

  ChatSettings copyWith({
    bool? enterKeySends,
    bool? mediaVisibility,
    ChatFontSize? fontSize,
    int? wallpaperColor,
  }) {
    return ChatSettings(
      enterKeySends: enterKeySends ?? this.enterKeySends,
      mediaVisibility: mediaVisibility ?? this.mediaVisibility,
      fontSize: fontSize ?? this.fontSize,
      wallpaperColor: wallpaperColor ?? this.wallpaperColor,
    );
  }
}

/// Network preference for a media auto-download rule.
enum AutoDownloadPolicy {
  never,
  wifi,
  wifiAndMobile;

  String get label {
    switch (this) {
      case AutoDownloadPolicy.never:
        return 'Never';
      case AutoDownloadPolicy.wifi:
        return 'Wi-Fi only';
      case AutoDownloadPolicy.wifiAndMobile:
        return 'Wi-Fi and mobile data';
    }
  }

  static AutoDownloadPolicy fromString(String? value) {
    return AutoDownloadPolicy.values.firstWhere(
      (v) => v.name == value,
      orElse: () => AutoDownloadPolicy.wifi,
    );
  }
}

/// Storage & data preferences stored at `users/{uid}/settings/storage`.
///
/// These are real, persisted preferences. They are structured so a future
/// media-download layer can read them to decide when to fetch photos, audio,
/// video and documents — but this build does not fabricate storage statistics
/// it cannot measure.
class StorageSettings {
  final AutoDownloadPolicy photos;
  final AutoDownloadPolicy audio;
  final AutoDownloadPolicy video;
  final AutoDownloadPolicy documents;
  final bool useLessDataForCalls;

  const StorageSettings({
    this.photos = AutoDownloadPolicy.wifiAndMobile,
    this.audio = AutoDownloadPolicy.wifi,
    this.video = AutoDownloadPolicy.wifi,
    this.documents = AutoDownloadPolicy.wifi,
    this.useLessDataForCalls = false,
  });

  factory StorageSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const StorageSettings();
    return StorageSettings(
      photos: AutoDownloadPolicy.fromString(map['photos'] as String?),
      audio: AutoDownloadPolicy.fromString(map['audio'] as String?),
      video: AutoDownloadPolicy.fromString(map['video'] as String?),
      documents: AutoDownloadPolicy.fromString(map['documents'] as String?),
      useLessDataForCalls: (map['useLessDataForCalls'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photos': photos.name,
      'audio': audio.name,
      'video': video.name,
      'documents': documents.name,
      'useLessDataForCalls': useLessDataForCalls,
    };
  }

  StorageSettings copyWith({
    AutoDownloadPolicy? photos,
    AutoDownloadPolicy? audio,
    AutoDownloadPolicy? video,
    AutoDownloadPolicy? documents,
    bool? useLessDataForCalls,
  }) {
    return StorageSettings(
      photos: photos ?? this.photos,
      audio: audio ?? this.audio,
      video: video ?? this.video,
      documents: documents ?? this.documents,
      useLessDataForCalls: useLessDataForCalls ?? this.useLessDataForCalls,
    );
  }
}

/// Serialise/deserialise a [ThemeMode] for the appearance setting stored at
/// `users/{uid}/settings/appearance`.
class AppearanceSettings {
  static ThemeMode themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static String themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }
}
