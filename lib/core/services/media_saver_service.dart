import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Where a piece of media ended up after a save.
enum MediaSaveLocation { gallery, appPrivate }

/// Outcome of a save attempt, so the UI can show an accurate message.
class MediaSaveResult {
  final bool success;
  final MediaSaveLocation location;
  final String? path;
  final String? error;

  const MediaSaveResult({
    required this.success,
    required this.location,
    this.path,
    this.error,
  });
}

/// Downloads chat media and saves it, honouring the "Media visibility" chat
/// setting.
///
/// * [mediaVisible] == true  -> file is written to the device gallery, so it
///   shows up in the phone's Photos/Gallery app.
/// * [mediaVisible] == false -> file is kept inside the app's private storage
///   ("Voxa Media"), so it is available in-app but never surfaces in the
///   device gallery.
///
/// This is exactly what the WhatsApp-style "Media visibility" toggle means, and
/// it makes the setting observably testable.
class MediaSaverService {
  const MediaSaverService();

  Future<MediaSaveResult> saveFromUrl({
    required String url,
    required bool mediaVisible,
    required bool isVideo,
  }) async {
    try {
      final bytes = await _download(url);

      if (mediaVisible) {
        return await _saveToGallery(bytes, url, isVideo: isVideo);
      }
      final file = await _writeAppPrivate(bytes, url, isVideo: isVideo);
      return MediaSaveResult(
        success: true,
        location: MediaSaveLocation.appPrivate,
        path: file.path,
      );
    } on GalException catch (e) {
      return MediaSaveResult(
        success: false,
        location: MediaSaveLocation.gallery,
        error: e.type.message,
      );
    } catch (e) {
      return MediaSaveResult(
        success: false,
        location: mediaVisible
            ? MediaSaveLocation.gallery
            : MediaSaveLocation.appPrivate,
        error: e.toString(),
      );
    }
  }

  Future<MediaSaveResult> _saveToGallery(
    Uint8List bytes,
    String url, {
    required bool isVideo,
  }) async {
    // Add-only access is enough to write into the gallery.
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        return const MediaSaveResult(
          success: false,
          location: MediaSaveLocation.gallery,
          error: 'permission-denied',
        );
      }
    }

    if (isVideo) {
      // gal saves videos from a file path, so stage a temp copy first.
      final tmp = await _writeTemp(bytes, url, isVideo: true);
      try {
        await Gal.putVideo(tmp.path);
      } finally {
        unawaited(tmp.delete().catchError((_) => tmp));
      }
    } else {
      await Gal.putImageBytes(
        bytes,
        name: _fileNameFor(url, isVideo: false),
      );
    }

    return const MediaSaveResult(
      success: true,
      location: MediaSaveLocation.gallery,
    );
  }

  Future<Uint8List> _download(String url) async {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('Download failed (${resp.statusCode})');
    }
    return resp.bodyBytes;
  }

  String _fileNameFor(String url, {required bool isVideo}) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'voxa_$stamp${_extFor(url, isVideo: isVideo)}';
  }

  String _extFor(String url, {required bool isVideo}) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot > path.lastIndexOf('/')) {
      final ext = path.substring(dot);
      if (ext.length <= 5) return ext;
    }
    return isVideo ? '.mp4' : '.jpg';
  }

  Future<File> _writeTemp(
    Uint8List bytes,
    String url, {
    required bool isVideo,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_fileNameFor(url, isVideo: isVideo)}');
    return file.writeAsBytes(bytes);
  }

  Future<File> _writeAppPrivate(
    Uint8List bytes,
    String url, {
    required bool isVideo,
  }) async {
    final base = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${base.path}/Voxa Media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    final file = File('${mediaDir.path}/${_fileNameFor(url, isVideo: isVideo)}');
    return file.writeAsBytes(bytes);
  }
}
