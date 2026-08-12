class AgoraConfig {
  AgoraConfig._();

  static const String appId = '47594fae25564287b018d28545e788c7';

  static const String devToken =
      '007eJxTYNh0aHeTXzeLbNzxgAd3eX62r1aKzO1Myz9WzXxexEuq66QCg4m5qaVJWmKqkampmYmRhXmSgaFFipGFqYlpqrmFRbJ5S1hNVkMgI4ON2CNmRgYIBPFZGEpSi0sYGAAB9x3J';


  static bool get isConfigured =>
      appId.isNotEmpty && appId != 'YOUR_AGORA_APP_ID';
}
