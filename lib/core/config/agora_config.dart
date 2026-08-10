class AgoraConfig {
  AgoraConfig._();

  static const String appId = 'YOUR_AGORA_APP_ID';

  static const String devToken = '';

  static bool get isConfigured =>
      appId.isNotEmpty && appId != 'YOUR_AGORA_APP_ID';
}
