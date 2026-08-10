# Voxa 💬📱

Voxa is a feature-rich, high-performance, real-time messaging and voice/video calling application built with **Flutter**, **Firebase**, **Cloudinary**, and **Agora RTC Engine**. Inspired by modern messaging platforms like WhatsApp, Voxa offers an intuitive user interface with dark/light theme support, real-time status tracking, robust security, and modular architecture.

---

## 🌟 Key Features

### 🔐 Authentication & Security
- **Phone Number Authentication**: Firebase Phone Auth with real-time OTP verification.
- **Pakistani (+92) Real-Time Validation**: Real-time validation for Pakistani mobile numbers (10 digits starting with `3`, auto-cleaning leading zero).
- **Hardened Firestore Security Rules**: Granular security rules restricting unauthorized user reads/writes across users, chats, messages, and calls collections.

### 💬 Real-Time Messaging & Chat Features
- **Direct & Group Chats**: Instant 1-on-1 messaging and rich group conversations.
- **Message Types**: Supports Text, Photos 📷, Videos 🎥, Voice Messages 🎤, and Documents 📄.
- **Message States & Delivery**: Real-time status indicators (Sent `✓`, Delivered `✓✓`, Seen `✓✓` in blue).
- **Typing Indicators**: Real-time "typing..." notifications when the recipient is composing a message.
- **Unread Counters & Filtering**: Filter chats by *All*, *Unread*, and *Groups*.
- **Message Operations**:
  - Star / Favorite messages
  - Message replying (quoting previous messages)
  - Edit sent text messages
  - Forward messages to other contacts
  - Multi-select delete ("Delete for Me" / "Delete for Everyone")
  - In-chat message searching
  - Clear chat history

### 📞 Audio & Video Calls (Agora RTC)
- **High-Quality 1-on-1 Calling**: Real-time voice and video calling powered by Agora SDK.
- **Call Controls**: Mute/Unmute microphone, toggle speakerphone, flip camera, disable/enable video.
- **Call Logs & History**: Complete incoming, outgoing, and missed call log tracking with call durations and redial functionality.

### 👥 Group Conversations & Admin Controls
- **Group Creation**: Create custom groups with group name, description, and group photo upload.
- **Admin Management**: Group creator gets admin permissions; admins can promote/demote other members or remove users from the group.
- **Add / Remove Members**: Admins can seamlessly add contacts to existing groups.

### ☁️ Media Uploads & Storage
- **Cloudinary Integration**: Direct, secure unsigned media uploads for profile photos, chat images, videos, audio clips, and documents.
- **Auto-Retry & Resilience**: Automatic exponential backoff retry logic for media uploads on unstable connections.

### 🎨 Themes & Custom Settings
- **Light & Dark Mode**: Dynamic theme switching (Light, Dark, System Default) powered by `ThemeController`.
- **Privacy Controls**: Customize visibility for Last Seen, Online Status, Profile Photo, and About section (Everyone, My Contacts, Nobody).
- **Notifications**: Firebase Cloud Messaging (FCM) + `flutter_local_notifications` for foreground/background message and call alerts.

---

## 📁 Project Architecture & Structure

Voxa is built using a clean **Model-Service-ViewModel (MVVM)** pattern to keep business logic separate from the presentation layer:

```text
lib/
├── core/
│   ├── config/              # Agora & app configuration
│   ├── services/            # Firebase, AuthService, CallService, CloudinaryService, AudioService, NotificationService, SettingsService
│   ├── theme/               # App colors, themes & ThemeController
│   └── utils/               # Error mappers & custom SnackBar helpers
├── models/                  # UserProfile, Conversation, Message, CallModel, AppSettings
├── viewmodels/              # ChatViewModel, ChatListViewModel, ContactsViewModel, ProfileViewModel
├── screens/                 # Auth, Home, Chat, Group, Call, Contacts, Profile screens
├── widgets/                 # Reusable UI components (bubbles, items, headers, tiles)
└── main.dart                # App entry point & initialization
```

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.12.2`
- **Dart SDK**: `>= 3.0.0`
- **Firebase Project**: Configured for Android/iOS with Phone Auth & Firestore Enabled.
- **Cloudinary Account**: Cloud name & unsigned upload preset configured in `CloudinaryConfig`.
- **Agora Developer Account**: App ID configured in `AgoraConfig`.

### Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/bilalchannar/voxa.git
   cd voxa
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Place your `google-services.json` in `android/app/` (for Android) or `GoogleService-Info.plist` in `ios/Runner/` (for iOS).
   - Ensure `lib/firebase_options.dart` matches your project settings.

4. **Configure Secrets & Services**
   - Update `lib/core/config/agora_config.dart` with your Agora App ID:
     ```dart
     static const String appId = 'YOUR_AGORA_APP_ID';
     ```
   - Update `lib/core/services/cloudinary_service.dart` with your Cloudinary credentials:
     ```dart
     static const String cloudName = 'YOUR_CLOUDINARY_CLOUD_NAME';
     static const String uploadPreset = 'YOUR_CLOUDINARY_UPLOAD_PRESET';
     ```

5. **Run the App**
   ```bash
   flutter run
   ```

---

## 🛡️ Security & Performance Highlights

- **Firestore Rules**: Strict security policies ensuring users can only edit their own profile and read/write messages in conversations they belong to.
- **No Committed Secrets**: Key app credentials managed in isolated config classes.
- **Zero Analyzer Warnings**: Strictly written clean Dart code passing `flutter analyze` with 0 issues.

---

## 📜 License

This project is open-source and available under the [MIT License](LICENSE).
