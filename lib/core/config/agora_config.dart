class AgoraConfig {
  AgoraConfig._();

  static const String appId = '47594fae25564287b018d28545e788c7';

  static const String devToken =
      '007eJxTYLD7LPTXkPtNAu/vR32Ne6dmrgpkbt4U+0ZdXCfav9U9tkWBwcTc1NIkLTHVyNTUzMTIwjzJwNAixcjC1MQ01dzCItk87EdVVkMgI4N10woGRigE8VkYwvIrEhkYAO6JHcg=';


  static bool get isConfigured =>
      appId.isNotEmpty && appId != 'YOUR_AGORA_APP_ID';
}
