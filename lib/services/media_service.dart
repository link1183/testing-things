import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:media_viewer/utils/heic_handler.dart';
import '../models/media_item.dart';
import '../models/media_source.dart';
import 'storage_service.dart';

class MediaService extends ChangeNotifier {
  final StorageService _storageService;

  List<MediaItem> _allMedia = [];
  MediaItem? _currentRandomMedia;
  bool _isLoading = false;
  String? _error;

  // Cached media by date for calendar view
  Map<DateTime, List<MediaItem>> _mediaByDate = {};

  MediaService(this._storageService);

  List<MediaItem> get allMedia => _allMedia;
  MediaItem? get currentRandomMedia => _currentRandomMedia;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<DateTime, List<MediaItem>> get mediaByDate => _mediaByDate;

  Future<void> init() async {
    await refreshMedia();
  }

  Future<void> refreshMedia() async {
    _setLoading(true);

    try {
      final localMedia = await _storageService.getLocalMediaFiles();

      final driveMedia = await _storageService.getGoogleDriveMediaFiles();

      _allMedia = [...localMedia, ...driveMedia];

      _allMedia.sort((a, b) => (b.dateModified ?? DateTime.now())
          .compareTo(a.dateModified ?? DateTime.now()));

      _buildMediaByDateMap();

      _setError(null);
    } catch (e) {
      _setError('Failed to load media: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _buildMediaByDateMap() {
    _mediaByDate = {};

    for (final media in _allMedia) {
      final date = media.dateCreated ?? media.dateModified;
      if (date != null) {
        final dateOnly = DateTime(date.year, date.month, date.day);

        if (!_mediaByDate.containsKey(dateOnly)) {
          _mediaByDate[dateOnly] = [];
        }

        _mediaByDate[dateOnly]!.add(media);
      }
    }

    notifyListeners();
  }

  Future<void> refreshRandomMedia() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    await loadRandomMediaOnStartup();
  }

  Future<void> loadRandomMediaOnStartup() async {
    if (_allMedia.isEmpty) {
      await refreshMedia();
    }

    if (_allMedia.isNotEmpty) {
      // Filter out HEIC files for immediate display to avoid conversion delay
      final nonHeicMedia = _allMedia.where((media) {
        final extension = media.name.split('.').last.toLowerCase();
        return extension != 'heic' && extension != 'heif';
      }).toList();

      // Use non-HEIC media if available, otherwise fall back to any media
      final mediaToUse = nonHeicMedia.isNotEmpty ? nonHeicMedia : _allMedia;

      final random = Random();
      final randomIndex = random.nextInt(mediaToUse.length);
      _currentRandomMedia = mediaToUse[randomIndex];

      // Start background conversion for any HEIC files in the collection
      _startBackgroundHeicConversions();

      notifyListeners();
    }
  }

  void _startBackgroundHeicConversions() {
    // Process HEIC files in background to prepare them for later viewing
    for (final media in _allMedia) {
      if (media.isLocal) {
        final extension = media.name.split('.').last.toLowerCase();
        if (extension == 'heic' || extension == 'heif') {
          final file = media.localFile;
          if (file != null) {
            HeicHandler.convertHeicFile(file, onComplete: (jpgPath) {
              // Update the media item with the converted path
              if (jpgPath != null) {
                final updatedMedia = MediaItem(
                  id: media.id,
                  name: media.name,
                  path: media.path,
                  type: media.type,
                  source: media.source,
                  dateCreated: media.dateCreated,
                  dateModified: media.dateModified,
                  thumbnailPath: jpgPath,
                  metadata: {
                    ...?media.metadata,
                    'convertedJpgPath': jpgPath,
                  },
                  downloadUrl: media.downloadUrl,
                  cloudId: media.cloudId,
                );

                // Replace the media item in the list
                final index = _allMedia.indexWhere((m) => m.id == media.id);
                if (index >= 0) {
                  _allMedia[index] = updatedMedia;
                  // Only notify listeners if this is not during initial load
                  if (!_isLoading) {
                    notifyListeners();
                  }
                }
              }
            });
          }
        }
      }
    }
  }

  Future<MediaItem?> getMediaItemById(String id) async {
    try {
      return _allMedia.firstWhere((media) => media.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<MediaItem>> getMediaByType(MediaType type) async {
    return _allMedia.where((media) => media.type == type).toList();
  }

  Future<List<MediaItem>> getMediaBySource(MediaSource source) async {
    return _allMedia.where((media) => media.source == source).toList();
  }

  Future<List<MediaItem>> getMediaForDate(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _mediaByDate[dateOnly] ?? [];
  }

  Future<File?> handleHeicFile(File file) async {
    return await HeicHandler.getDisplayableImage(file);
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
