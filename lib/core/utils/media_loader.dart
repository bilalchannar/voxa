import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/settings_service.dart';
import '../../models/app_settings.dart';

class MediaLoader {
  static Future<bool> shouldAutoDownload(String type) async {
    final settings = await SettingsService().getNotifications(); // Wait, storage settings
    final storage = await SettingsService().getStorage(); 
    
    final AutoDownloadPolicy policy;
    switch (type) {
      case 'image':
        policy = storage.photos;
        break;
      case 'video':
        policy = storage.video;
        break;
      case 'voice':
      case 'audio':
        policy = storage.audio;
        break;
      case 'document':
        policy = storage.documents;
        break;
      default:
        policy = AutoDownloadPolicy.wifi;
    }

    if (policy == AutoDownloadPolicy.never) return false;
    if (policy == AutoDownloadPolicy.wifiAndMobile) return true;

    // policy is wifi
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity.contains(ConnectivityResult.wifi);
  }
}
