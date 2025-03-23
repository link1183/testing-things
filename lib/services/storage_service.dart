import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_viewer/utils/heic_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import 'file_type_service.dart';

class StorageService extends ChangeNotifier {
  // For Google Drive
  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  bool _isGoogleDriveConnected = false;

  // Paths
  late String _localMediaPath;
  late String _cachePath;

  // State
  bool _isLoading = false;
  String? _error;

  // Getters
  drive.DriveApi? get driveApi => _driveApi;
  bool get isGoogleDriveConnected => _isGoogleDriveConnected;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> init() async {
    _setLoading(true);

    try {
      // Init dirs
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = await getTemporaryDirectory();

      _localMediaPath = '${appDir.path}/local_media';
      _cachePath = '${cacheDir.path}/media_cache';

      await Directory(_localMediaPath).create(recursive: true);
      await Directory(_cachePath).create(recursive: true);

      // Init Google Sign-In
      _googleSignIn = GoogleSignIn(
        scopes: [
          'https://www.googleapis.com/auth/drive.readonly',
        ],
      );

      _setError(null);
    } catch (e) {
      _setError('Error initializing storage: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<File?> getCachedOrDownloadThumbnail(MediaItem mediaItem) async {
    if (mediaItem.isLocal) {
      return mediaItem.localFile;
    }

    final cacheDir = await getTemporaryDirectory();
    final cachedThumbFile =
        File('${cacheDir.path}/thumbnails/${mediaItem.id}.jpg');

    if (await cachedThumbFile.exists()) {
      return cachedThumbFile;
    }

    await Directory('${cacheDir.path}/thumbnails').create(recursive: true);

    try {
      if (mediaItem.cloudId != null && _driveApi != null) {
        final thumbnailUrl =
            'https://drive.google.com/thumbnail?id=${mediaItem.cloudId}&sz=w320';

        final response = await http.get(Uri.parse(thumbnailUrl));
        if (response.statusCode == 200) {
          await cachedThumbFile.writeAsBytes(response.bodyBytes);
          return cachedThumbFile;
        }
      }

      final fullFile = await downloadGoogleDriveFile(mediaItem);
      return fullFile;
    } catch (e) {
      print('Error getting thumbnails: $e');
      return null;
    }
  }

  // Local storage methods
  Future<List<MediaItem>> getLocalMediaFiles() async {
    final List<MediaItem> mediaItems = [];

    try {
      // Let user select directories to scan
      final result = await FilePicker.platform.getDirectoryPath();

      if (result != null) {
        final dir = Directory(result);
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            final extension = entity.path.split('.').last.toLowerCase();

            if (FileTypeService.isMediaFile(extension)) {
              // Check if it's a HEIC file
              if (extension == 'heic' || extension == 'heif') {
                // We'll include the HEIC file as is, but add metadata to indicate it needs conversion
                final mediaItem = MediaItem.fromFile(entity);

                // Attempt conversion to get thumbnail
                final jpgPath =
                    await HeicHandler.getDisplayableImage(File(entity.path));
                if (jpgPath != null) {
                  // Store conversion info in metadata for quick access later
                  final Map<String, dynamic> updatedMetadata =
                      mediaItem.metadata ?? {};
                  updatedMetadata['convertedJpgPath'] = jpgPath;

                  final updatedItem = MediaItem(
                    id: mediaItem.id,
                    name: mediaItem.name,
                    path: mediaItem.path,
                    type: mediaItem.type,
                    source: mediaItem.source,
                    dateCreated: mediaItem.dateCreated,
                    dateModified: mediaItem.dateModified,
                    thumbnailPath:
                        jpgPath.path, // Use the converted JPG as thumbnail
                    metadata: updatedMetadata,
                    downloadUrl: mediaItem.downloadUrl,
                    cloudId: mediaItem.cloudId,
                  );

                  mediaItems.add(updatedItem);
                } else {
                  // Conversion failed, but still add the original item
                  mediaItems.add(mediaItem);
                }
              } else {
                // Regular non-HEIC media file
                final mediaItem = MediaItem.fromFile(entity);
                mediaItems.add(mediaItem);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error getting local media files: $e');
    }

    return mediaItems;
  }

  // Google Drive methods
  Future<bool> connectToGoogleDrive() async {
    _setLoading(true);

    try {
      final account = await _googleSignIn?.signIn();

      if (account != null) {
        final authHeaders = await account.authHeaders;
        final client = http.Client();

        _driveApi = drive.DriveApi(
          GoogleHttpClient(authHeaders, client),
        );

        _isGoogleDriveConnected = true;
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _setError('Error connecting to Google Drive: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> disconnectGoogleDrive() async {
    await _googleSignIn?.signOut();
    _driveApi = null;
    _isGoogleDriveConnected = false;
    notifyListeners();
  }

  Future<List<MediaItem>> getGoogleDriveMediaFiles() async {
    final List<MediaItem> mediaItems = [];

    if (!_isGoogleDriveConnected || _driveApi == null) {
      return mediaItems;
    }

    try {
      final fileList = await _driveApi!.files.list(
        q: "mimeType contains 'image/' or mimeType contains 'video/'",
        $fields:
            "files(id, name, mimeType, size, createdTime, modifiedTime, webContentLink)",
        spaces: 'drive',
      );

      final files = fileList.files;
      if (files != null) {
        for (final file in files) {
          if (file.name != null) {
            final mediaItem = MediaItem.fromGoogleDriveFile({
              'id': file.id,
              'name': file.name,
              'mimeType': file.mimeType,
              'size': file.size,
              'createdTime': file.createdTime?.toIso8601String() ??
                  DateTime.now().toIso8601String(),
              'modifiedTime': file.modifiedTime?.toIso8601String() ??
                  DateTime.now().toIso8601String(),
              'webContentLink': file.webContentLink,
            });

            mediaItems.add(mediaItem);
          }
        }
      }
    } catch (e) {
      print('Error getting Google Drive media files: $e');
    }

    return mediaItems;
  }

  Future<File?> downloadGoogleDriveFile(MediaItem mediaItem) async {
    if (!_isGoogleDriveConnected ||
        _driveApi == null ||
        mediaItem.cloudId == null) {
      return null;
    }

    try {
      final drive.Media media = await _driveApi!.files.get(
        mediaItem.cloudId!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Create a local file to strore the downladed content
      final cachedFile = File('$_cachePath/${mediaItem.name}');
      final fileStream = cachedFile.openWrite();

      // Download the file
      await media.stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      return cachedFile;
    } catch (e) {
      print('Error downloading Google Drive file: $e');
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? errorMsg) {
    _error = errorMsg;
    notifyListeners();
  }
}

// Helper class for Google Drive authentication
class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client;

  GoogleHttpClient(this._headers, this._client);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
