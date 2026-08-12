import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryNotConfiguredException implements Exception {
  const CloudinaryNotConfiguredException();
  @override
  String toString() =>
      'Cloudinary is not configured. Set cloudName and uploadPreset in CloudinaryConfig.';
}

class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);
  @override
  String toString() => message;
}

class CloudinaryConfig {
  CloudinaryConfig._();

  static const String cloudName = 'fuzwgehp';
  static const String uploadPreset = 'voxa_upload';
  static const String profileFolder = 'voxa/profile_photos';
  static const String chatMediaFolder = 'voxa/chat_media';

  static const String _placeholderCloudName = 'YOUR_CLOUDINARY_CLOUD_NAME';
  static const String _placeholderPreset = 'YOUR_CLOUDINARY_UPLOAD_PRESET';

  static bool get isConfigured {
    return cloudName.isNotEmpty &&
        uploadPreset.isNotEmpty &&
        cloudName != _placeholderCloudName &&
        uploadPreset != _placeholderPreset;
  }
}

class CloudinaryService {
  const CloudinaryService();

  bool get isConfigured => CloudinaryConfig.isConfigured;

  Future<String> uploadImage(File imageFile) async {
    return uploadMediaFile(
      file: imageFile,
      resourceType: 'image',
      folder: CloudinaryConfig.profileFolder,
    );
  }

  Future<String> uploadMediaFile({
    required File file,
    required String resourceType,
    String folder = CloudinaryConfig.chatMediaFolder,
    int maxAttempts = 3,
  }) async {
    if (!CloudinaryConfig.isConfigured) {
      throw const CloudinaryNotConfiguredException();
    }

    final typeEndpoint = (resourceType == 'video' || resourceType == 'voice' || resourceType == 'audio')
        ? 'video'
        : (resourceType == 'document' ? 'raw' : 'image');

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/$typeEndpoint/upload',
    );

    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
          ..fields['folder'] = folder
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode >= 500 && attempt < maxAttempts) {
            await Future.delayed(Duration(seconds: attempt));
            continue;
          }
          debugPrint(
            '[Voxa] Cloudinary media upload failed: ${response.statusCode} ${response.body}',
          );
          throw CloudinaryUploadException(
            'Media upload failed (${response.statusCode}). Please try again.',
          );
        }

        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        final url = body['secure_url'] as String?;
        if (url == null || url.isEmpty) {
          throw const CloudinaryUploadException(
            'Upload succeeded but no URL was returned.',
          );
        }
        return url;
      } on CloudinaryNotConfiguredException {
        rethrow;
      } on CloudinaryUploadException {
        rethrow;
      } on SocketException catch (e) {
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }
        debugPrint(
          '[Voxa] Cloudinary media upload socket error (attempt $attempt): $e',
        );
        throw const CloudinaryUploadException(
          'Network error. Check your connection and try again.',
        );
      } catch (e) {
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }
        debugPrint(
          '[Voxa] Cloudinary media upload error (attempt $attempt): $e',
        );
        throw const CloudinaryUploadException(
          'Could not upload the file. Please try again.',
        );
      }
    }
  }
}
