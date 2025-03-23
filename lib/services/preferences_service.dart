import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService extends ChangeNotifier {
  late SharedPreferences _prefs;

  // Defaults
  static const bool _defaultIsDarkMode = false;
  static const bool _defaultShowRandomOnStartup = true;
  static const int _defaultGalleryColumnsPortrait = 3;
  static const int _defaultGalleryColumnsLandscape = 5;
  static const String _defaultSortBy = 'date';
  static const bool _defaultSortAscending = false;
  static const String _defaultStartupScreen = 'home';
  static const bool _defaultAutoplayVideos = true;
  static const bool _defaultSaveDownloadedFiles = true;
  static const bool _defaultShowFilenames = true;

  // Cached values
  bool _isDarkMode = _defaultIsDarkMode;
  bool _showRandomOnStartup = _defaultShowRandomOnStartup;
  int _galleryColumnsPortrait = _defaultGalleryColumnsPortrait;
  int _galleryColumnsLandscape = _defaultGalleryColumnsLandscape;
  String _sortBy = _defaultSortBy;
  bool _sortAscending = _defaultSortAscending;
  String _startupScreen = _defaultStartupScreen;
  bool _autoplayVideos = _defaultAutoplayVideos;
  bool _saveDownloadedFiles = _defaultSaveDownloadedFiles;
  bool _showFilenames = _defaultShowFilenames;

  // Recent folders/paths
  List<String> _recentLocalPaths = [];

  // Getters
  bool get isDarkMode => _isDarkMode;
  bool get showRandomOnStartup => _showRandomOnStartup;
  int get galleryColumnsPortrait => _galleryColumnsPortrait;
  int get galleryColumnsLandscape => _galleryColumnsLandscape;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  String get startupScreen => _startupScreen;
  bool get autoplayVideos => _autoplayVideos;
  bool get saveDownloadedFiles => _saveDownloadedFiles;
  bool get showFilenames => _showFilenames;
  List<String> get recentLocalPaths => _recentLocalPaths;

  // Initialize preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadPreferences();
  }

  // Load all preferences from storage
  void _loadPreferences() {
    _isDarkMode = _prefs.getBool('isDarkMode') ?? _defaultIsDarkMode;
    _showRandomOnStartup =
        _prefs.getBool('showRandomOnStartup') ?? _defaultShowRandomOnStartup;
    _galleryColumnsPortrait = _prefs.getInt('galleryColumnsPortrait') ??
        _defaultGalleryColumnsPortrait;
    _galleryColumnsLandscape = _prefs.getInt('galleryColumnsLandscape') ??
        _defaultGalleryColumnsLandscape;
    _sortBy = _prefs.getString('sortBy') ?? _defaultSortBy;
    _sortAscending = _prefs.getBool('sortAscending') ?? _defaultSortAscending;
    _startupScreen = _prefs.getString('startupScreen') ?? _defaultStartupScreen;
    _autoplayVideos =
        _prefs.getBool('autoplayVideos') ?? _defaultAutoplayVideos;
    _saveDownloadedFiles =
        _prefs.getBool('saveDownloadedFiles') ?? _defaultSaveDownloadedFiles;
    _showFilenames = _prefs.getBool('showFilenames') ?? _defaultShowFilenames;
    _recentLocalPaths = _prefs.getStringList('recentLocalPaths') ?? [];

    notifyListeners();
  }

  // Theme preferences
  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool('isDarkMode', value);
    _isDarkMode = value;
    notifyListeners();
  }

  // Startup preferences
  Future<void> setShowRandomOnStartup(bool value) async {
    await _prefs.setBool('showRandomOnStartup', value);
    _showRandomOnStartup = value;
    notifyListeners();
  }

  Future<void> setStartupScreen(String screen) async {
    await _prefs.setString('startupScreen', screen);
    _startupScreen = screen;
    notifyListeners();
  }

  // Gallery view preferences
  Future<void> setGalleryColumnsPortrait(int value) async {
    await _prefs.setInt('galleryColumnsPortrait', value);
    _galleryColumnsPortrait = value;
    notifyListeners();
  }

  Future<void> setGalleryColumnsLandscape(int value) async {
    await _prefs.setInt('galleryColumnsLandscape', value);
    _galleryColumnsLandscape = value;
    notifyListeners();
  }

  // Sorting preferences
  Future<void> setSortBy(String value) async {
    await _prefs.setString('sortBy', value);
    _sortBy = value;
    notifyListeners();
  }

  Future<void> setSortAscending(bool value) async {
    await _prefs.setBool('sortAscending', value);
    _sortAscending = value;
    notifyListeners();
  }

  // Media playback preferences
  Future<void> setAutoplayVideos(bool value) async {
    await _prefs.setBool('autoplayVideos', value);
    _autoplayVideos = value;
    notifyListeners();
  }

  // Storage preferences
  Future<void> setSaveDownloadedFiles(bool value) async {
    await _prefs.setBool('saveDownloadedFiles', value);
    _saveDownloadedFiles = value;
    notifyListeners();
  }

  // UI preferences
  Future<void> setShowFilenames(bool value) async {
    await _prefs.setBool('showFilenames', value);
    _showFilenames = value;
    notifyListeners();
  }

  // Recent locations management
  Future<void> addRecentLocalPath(String path) async {
    // Don't add duplicates
    if (_recentLocalPaths.contains(path)) {
      // Move to top of list if already exists
      _recentLocalPaths.remove(path);
    }

    // Add to beginning of list
    _recentLocalPaths.insert(0, path);

    // Limit list size to 10 items
    if (_recentLocalPaths.length > 10) {
      _recentLocalPaths = _recentLocalPaths.sublist(0, 10);
    }

    await _prefs.setStringList('recentLocalPaths', _recentLocalPaths);
    notifyListeners();
  }

  Future<void> clearRecentLocalPaths() async {
    _recentLocalPaths = [];
    await _prefs.setStringList('recentLocalPaths', _recentLocalPaths);
    notifyListeners();
  }

  // Reset all preferences to defaults
  Future<void> resetAllPreferences() async {
    await _prefs.clear();
    _loadPreferences();
  }
}
