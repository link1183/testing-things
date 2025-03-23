import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:heic_to_jpg/heic_to_jpg.dart';
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

  Future<void> loadRandomMediaOnStartup() async {
    if (_allMedia.isEmpty) {
      await refreshMedia();
    }

    if (_allMedia.isNotEmpty) {
      final random = Random();
      final randomIndex = random.nextInt(_allMedia.length);
      _currentRandomMedia = _allMedia[randomIndex];
      notifyListeners();
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
    try {
      final extension = file.path.split('.').last.toLowerCase();
      if (extension == 'heic' || extension == 'heif') {
        // Convert HEIC to JPG
        final jgpPath = await HeicToJpg.convert(file.path);
        if (jgpPath != null) {
          return File(jgpPath);
        }
      }
      return file;
    } catch (e) {
      print('Error handling HEIC file: $e');
      return file;
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
